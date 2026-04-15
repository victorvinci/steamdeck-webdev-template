# 🔐 SteamDeck Boot Sequence — Proton Bridge + KeePassXC

A small autostart helper that fixes the recurring **"No keychain available"** error from Proton Mail Bridge on Steam Deck. It waits for KeePassXC's Secret Service to appear on D-Bus **and for the database to actually be unlocked**, then launches Bridge — so Bridge never starts before its keychain is ready.

> ⚠️ **Why both checks matter:** KeePassXC registers `org.freedesktop.secrets` on the bus _immediately on startup_, before you've typed the master password. Waiting only for the bus name lets Bridge race ahead and query a still-locked collection — which silently rewrites `vault.enc` as **insecure (unencrypted)** and is **unrecoverable without reconfiguring all Proton accounts**. The script's two-stage gate exists specifically to prevent this.

---

## Table of Contents

- [The Problem](#the-problem)
- [How It Works](#how-it-works)
- [Setup (already done — for reference)](#setup-already-done--for-reference)
- [Usage](#usage)
- [Boot Sequence Flow](#boot-sequence-flow)
- [Safety Features](#safety-features)
- [Troubleshooting](#troubleshooting)
- [Files Touched](#files-touched)

---

## The Problem

Proton Mail Bridge needs a Secret Service provider (a "keychain") to store account credentials. On Linux it talks to whatever owns `org.freedesktop.secrets` on the user D-Bus.

On SteamOS / KDE Plasma there is **no native Secret Service provider**:

- KWallet does **not** speak the freedesktop Secret Service API
- gnome-keyring is not installed and can't be added cleanly (read-only root)
- The only viable option in flatpak land is **KeePassXC** with its FdoSecrets integration

This creates a race condition at boot:

- If Bridge launches **before** KeePassXC is running and the database is unlocked → it sees no keychain → shows the error dialog → won't start mail sync
- If you happen to open KeePassXC first → it works fine

`boot_sequence.sh` removes the race entirely.

---

## How It Works

When the Plasma session starts, autostart fires both KeePassXC and `boot_sequence.sh --boot` in parallel. The script then runs a **two-stage gate** before launching Bridge:

**Stage A — bus name present**

1. Polls the user D-Bus every 2s for the name `org.freedesktop.secrets`
2. KeePassXC registers this name as soon as its process starts (still locked)
3. Stage A passes almost immediately on a normal boot

**Stage B — collection unlocked** _(this is what actually blocks until you type the master password)_

1. Polls `org.freedesktop.Secret.Collection.Locked` on `/org/freedesktop/secrets/aliases/default` every 2s
2. Returns `b false` once the kdbx is unlocked
3. Stage B passes the moment you finish typing the master password into KeePassXC

Once both stages pass, the script launches Proton Mail Bridge with `flatpak run`. Bridge connects to KeePassXC, retrieves credentials, and starts the mail sync.

The combined Stage A + Stage B timeout is **300 seconds (5 minutes)**. If Stage B never passes (you walked away without unlocking), the script **refuses to launch Bridge** — launching into a locked collection would silently corrupt `vault.enc`. The script does not keep running in the background after that.

In `--boot` mode, the script also prints a heartbeat line every 10s to the autostart log so you can see it's actively waiting and not hung.

---

## Setup (already done — for reference)

These steps were performed once during the initial setup. They're documented here in case you ever need to restore them on a fresh SteamOS install.

### 1. KeePassXC configuration

- Install: `flatpak install flathub org.keepassxc.KeePassXC`
- Open KeePassXC, create a database (current one is `~/Passwords.kdbx`)
- **Application Settings → Secret Service Integration** → check **"Enable KeePassXC Freedesktop.org Secret Service integration"**
- In the same panel, **uncheck** these two — they cause phantom `org.freedesktop.Secret.Error.IsLocked` errors even when the database is unlocked:
    - ❌ **Confirm when passwords are retrieved by clients** (pops a per-request modal; if it's missed/buried, the secret-service request returns `IsLocked` and Bridge falls back to an unencrypted vault)
    - ❌ **Prompt to unlock database before searching** (same failure mode for search-style queries)
- "Show notification when passwords are retrieved by clients" is fine to leave on — it's the source of the harmless `Entry "bridge/check" ... was used by unknown executable` toast and doesn't block.
- **Database → Database Settings → Secret Service** → select **"Expose entries under this group"** and pick a group (e.g. `Root`). The exposed collection becomes the default `org.freedesktop.secrets` collection on the user bus.
- **Application Settings → General**:
    - ✅ Remember last databases
    - ✅ Automatically open the previous database on startup
    - ✅ Minimize window at application startup
    - ✅ Show tray icon
    - ✅ Hide window to system tray when minimized
    - ✅ Hide window to system tray instead of app exit ← **important**, otherwise closing the window kills the keychain

### 2. Autostart entries

Both files live in `~/.config/autostart/`:

| File                                      | Purpose                                                                                       |
| ----------------------------------------- | --------------------------------------------------------------------------------------------- |
| `org.keepassxc.KeePassXC.desktop`         | Launches KeePassXC at session start                                                           |
| `ch.protonmail.protonmail-bridge.desktop` | **Modified** — its `Exec=` line now runs `boot_sequence.sh --boot` instead of Bridge directly |

The Bridge `.desktop` file's `Exec=` line is:

```
Exec=/bin/bash /home/deck/Desktop/boot_sequence.sh --boot
```

### 3. The script

`boot_sequence.sh` lives on the Desktop alongside `backup.sh` and is included in backups automatically (see `BACKUP_README.md`).

---

## Usage

### Interactive run (testing / manual)

```bash
bash boot_sequence.sh
```

This:

1. Runs a dry-run automatically and prints a plan
2. Asks **"Proceed? [y/N]"**
3. If you confirm, waits for Secret Service and launches Bridge

### Dry-run only (no prompts, no actions)

```bash
bash boot_sequence.sh --dry-run
```

Validates the environment, shows what _would_ happen, then exits. Useful for sanity-checking after a SteamOS update or after touching the autostart files.

### Boot mode (used by autostart)

```bash
bash boot_sequence.sh --boot
```

No colors, no prompts, no auto dry-run. Designed to be called by the `.desktop` autostart entry. Exits silently on success.

### Help

```bash
bash boot_sequence.sh --help
```

---

## Boot Sequence Flow

```
Plasma session starts
        │
        ├──► KeePassXC autostarts
        │           │
        │           ├──► Opens last database (locked)
        │           ├──► You type master password
        │           └──► Registers org.freedesktop.secrets on user D-Bus
        │
        └──► boot_sequence.sh --boot autostarts
                    │
                    ├──► [Stage A] Polls user D-Bus every 2s for org.freedesktop.secrets
                    │           └──► Passes ~immediately (KeePassXC registers it on startup)
                    │
                    ├──► [Stage B] Polls Locked property on default collection every 2s
                    │           ├──► Heartbeat line printed every 10s
                    │           └──► Passes the moment you finish unlocking the kdbx
                    │
                    ├──► (Stage A timeout: 60s, Stage B timeout: 300s, independent budgets)
                    └──► Launches Proton Mail Bridge
                                │
                                └──► Bridge reads credentials from KeePassXC
                                            │
                                            └──► Mail sync starts in Thunderbird
```

---

## Safety Features

- **`set -euo pipefail`** — strict mode, catches unset vars and pipe failures
- **Auto dry-run + confirm** — interactive mode previews the plan before doing anything
- **Pre-flight checks** — verifies `flatpak`, `busctl`, KeePassXC and Bridge are installed before doing anything
- **Hard fail on missing flatpaks** — if KeePassXC or Bridge ever gets uninstalled, the script exits non-zero with a logged error in _both_ interactive and `--boot` modes. Both apps are mandatory for this script to make sense, and a silent skip would just hide the breakage. The failure shows up in the run-history log under `~/.local/state/desktop-scripts/boot_sequence/`.
- **FdoSecrets sanity check** — warns if KeePassXC's Secret Service integration looks disabled in the config file
- **Already-running guard** — won't double-launch Bridge if it's already running
- **Two-stage gate (Stage A + Stage B)** — refuses to launch Bridge until the kdbx is _actually unlocked_, not just until the bus name appears
- **Refuse-on-timeout** — if either timeout is hit (Stage A: 60s for Secret Service to register on D-Bus, Stage B: 300s for the user to unlock the kdbx), the script exits with an error rather than launching Bridge into a locked collection (which would corrupt `vault.enc`). The two budgets are **independent** so a slow-booting Stage A can't eat into the user's typing time for Stage B.
- **Heartbeat in `--boot` mode** — prints one line every 10s while waiting so the autostart log shows it's alive
- **`setsid nohup` launch** — Bridge survives the script exiting (important for autostart)
- **Cleanup trap on error** — exits cleanly on unexpected failures
- **NUL-delimited log pruning** — old run logs are pruned with `find -print0 | xargs -0` so a pathological filename can't ever feed `rm` an unintended path
- **Self re-exec via `realpath`** — the auto dry-run child re-execs the script using `realpath "$0"` so the same file runs regardless of cwd or how you invoked it (relative path, symlink, autostart .desktop file, etc.)
- **Bridge launch verification** — after `flatpak run`, the script polls `flatpak ps` for up to 10s and exits non-zero if Bridge never appears. A broken Bridge install (e.g. after a SteamOS update breaks the runtime) used to be reported as success because we just fired and forgot; now it surfaces in the boot log with a clear error and reproduction command.
- **Consistent error counting** — the ERR trap bumps `$ERRORS` so the final summary block can never say "Errors: 0" while exiting non-zero. Makes the run-history log internally consistent.
- **Deterministic log flush** — the EXIT trap closes our stdout/stderr and `wait`s on the tee subprocess instead of `sleep 0.1`-ing and hoping. The final summary block is guaranteed to land in the log file even on slow filesystems.

---

## Run History Logs

Every invocation (boot, dry-run, **and** interactive) writes a timestamped log to `~/.local/state/desktop-scripts/boot_sequence/`. After a reboot this is the **first place to look** to see what the autostart actually did.

- Filenames: `YYYYMMDD_HHMMSS_<mode>.log` where `<mode>` is `boot`, `dryrun`, or `interactive`
- `latest.log` symlink always points at the most recent run
- Colors stripped from the file copy (stays grep-friendly)
- Last 20 runs kept, older are auto-pruned
- Every log ends with a ✅/❌ final summary block: mode, start/end times, duration, warnings, errors, and on failure a numbered diagnostics checklist with copy-pasteable commands

Quick check after a reboot:

```bash
cat ~/.local/state/desktop-scripts/boot_sequence/latest.log
```

If something went wrong, the diagnostics block at the bottom of that file will tell you exactly what to investigate next — including the busctl commands to verify Secret Service state and where to find Bridge's own log.

---

## Troubleshooting

### Bridge still shows "No keychain available"

1. Open KeePassXC manually — is the database actually unlocked?
2. Check Secret Service is on the bus:
    ```bash
    busctl --user list | grep secrets
    ```
    Should show `org.freedesktop.secrets`. If not, KeePassXC's FdoSecrets integration isn't running — re-check **Tools → Settings → Secret Service Integration**.
3. Check the default collection is actually unlocked:
    ```bash
    busctl --user get-property org.freedesktop.secrets \
      /org/freedesktop/secrets/aliases/default \
      org.freedesktop.Secret.Collection Locked
    ```
    Should print `b false`. If it prints `b true`, the kdbx is locked even though KeePassXC is running.
4. Make sure the database has a group exposed: **Database → Database Settings → Secret Service**.
5. Run `bash boot_sequence.sh --dry-run` to validate the environment — the dry-run output now shows Stage A and Stage B status separately.
6. **Check the bridge log for an insecure vault.** Open the newest `*_bri_*.log` under `~/.var/app/ch.protonmail.protonmail-bridge/data/protonmail/bridge-v3/logs/` and grep for `vault will not be encrypted` or `Could not load/create vault key`. **If you find either, no amount of fixing the keychain will recover this — see the next section.**

### "Insecure vault" — `vault.enc` got corrupted by an earlier race

If a Bridge run _before_ this script existed (or before Stage B was added) launched into a locked collection, Bridge will have written `vault.enc` in **insecure (unencrypted) mode**. Once that happens, the on-disk vault no longer matches any key in KeePassXC and **cannot be recovered**, even after the keychain is fixed. The only fix is to reconfigure all Proton accounts:

1. `flatpak kill ch.protonmail.protonmail-bridge`
2. Make sure KeePassXC is unlocked
3. Optional but tidy: in KeePassXC, delete the stale entry at `Root/protonmail/bridge-v3/users/bridge-vault-key` (Bridge will recreate it)
4. Launch Bridge, sign in to your Proton account(s), update Thunderbird with the new IMAP/SMTP password if it changed
5. Reboot once to confirm the boot sequence holds across a real cold start — the new vault key written this time should stay valid forever, because Stage B prevents the race that caused this in the first place

### Script times out

There are two independent timeouts and the error message tells you which one tripped:

- **Stage A timed out after 60s** — KeePassXC's Secret Service never appeared on D-Bus. Almost always means KeePassXC isn't running at all (autostart entry broken? flatpak uninstalled?). Check `pgrep -af keepassxc` and `flatpak info org.keepassxc.KeePassXC`.
- **Stage B timed out after 300s** — KeePassXC is running but the default collection is still locked. You skipped or delayed typing your master password for more than 5 minutes. Unlock the database and run `bash boot_sequence.sh` manually, or relaunch Bridge from the app menu. The script refuses to launch Bridge into a locked collection on purpose — doing so would corrupt `vault.enc` (see the warning at the top of this README).

### After a SteamOS update Bridge fails again

SteamOS updates do **not** wipe `~/.config/autostart/` or `~/Desktop/`, so the script and autostart entries should survive. If they don't, restore them from a backup (see `BACKUP_README.md` — `backup.sh` now captures `~/.config/autostart/` into `autostart/` so a fresh-install restore re-wires both KeePassXC and Bridge without any manual `.desktop` editing).

### I want to disable the boot sequence temporarily

```bash
mv ~/.config/autostart/ch.protonmail.protonmail-bridge.desktop ~/.config/autostart/ch.protonmail.protonmail-bridge.desktop.disabled
```

Re-enable by removing the `.disabled` suffix.

---

## Files Touched

| Path                                                                | What it is                               |
| ------------------------------------------------------------------- | ---------------------------------------- |
| `~/Desktop/boot_sequence.sh`                                        | The script itself                        |
| `~/Desktop/BOOT_SEQUENCE_README.md`                                 | This file                                |
| `~/.config/autostart/ch.protonmail.protonmail-bridge.desktop`       | Modified `Exec=` line to call the script |
| `~/.config/autostart/org.keepassxc.KeePassXC.desktop`               | Added so KeePassXC autostarts            |
| `~/.var/app/org.keepassxc.KeePassXC/config/keepassxc/keepassxc.ini` | Holds `[FdoSecrets] Enabled=true`        |
| `~/Passwords.kdbx`                                                  | Your KeePassXC database                  |

---

## Why Not Use a Native Bridge Install + `pass`?

We considered installing Bridge natively from AUR with the `pass` keychain backend (no D-Bus needed). It's possible but **much** more invasive on SteamOS:

- Requires `steamos-readonly disable` to unlock the root filesystem
- Needs an AUR helper, GPG key generation, and `pass` initialization
- **Every SteamOS update wipes everything under `/usr`** — you'd have to redo the install
- You still need to type a passphrase at boot (GPG instead of KeePassXC) — no real security gain

The KeePassXC + boot*sequence approach is fragile in \_exactly one* way (you have to type the master password each boot), and bulletproof in every other way. It survives SteamOS updates without intervention.
