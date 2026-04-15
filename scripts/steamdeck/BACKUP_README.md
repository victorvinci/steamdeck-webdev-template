# 💾 SteamDeck Dev Backup

A backup script for your SteamOS development environment. Backs up all your dotfiles, configs, SSH keys, fonts, plugins, and project references so you can restore everything quickly on a fresh SteamOS install.

---

## Table of Contents

- [What Gets Backed Up](#what-gets-backed-up)
- [Related Scripts](#related-scripts)
- [Security Features](#security-features)
- [Usage](#usage)
- [Backup Structure](#backup-structure)
- [Restoring on a Fresh SteamOS](#restoring-on-a-fresh-steamos)
- [Tips](#tips)
- [What's NOT Backed Up](#whats-not-backed-up)

---

## What Gets Backed Up

### 📄 Dotfiles

Your shell configuration files — the heart of your terminal setup.

| File                  | What it contains                                                       |
| --------------------- | ---------------------------------------------------------------------- |
| `~/.zshrc`            | All zsh config, aliases (`dev`, `codes`), plugins, Starship init, PATH |
| `~/.zprofile`         | zsh login shell config                                                 |
| `~/.bashrc`           | bash config (fallback)                                                 |
| `~/.profile`          | Generic shell profile                                                  |
| `~/.gitconfig`        | Git username, email, aliases                                           |
| `~/.gitignore_global` | Global gitignore rules                                                 |

### 🚀 Autostart Entries

Everything in `~/.config/autostart/` — the `.desktop` files that wire scripts (like `boot_sequence.sh`) into KDE's session start. Without backing this up, a fresh restore would put `boot_sequence.sh` on the Desktop but leave it disconnected from autostart, and you'd have to recreate the entry by hand from `BOOT_SEQUENCE_README.md` every time. The directory is plain text and contains no secrets, so it's backed up unconditionally.

### ⚙️ App Configs

| File                      | What it contains                                        |
| ------------------------- | ------------------------------------------------------- |
| `~/.config/starship.toml` | Your Starship prompt theme and layout                   |
| `~/.local/share/konsole/` | All Konsole profiles (Mint Dev, steamdeck tabs, colors) |
| `~/.config/konsolerc`     | Konsole default profile and window settings             |

### 🔑 SSH Keys

All files inside `~/.ssh/` including private keys, public keys, `known_hosts`, and `config`. Permissions are locked to `600` on backup to keep them secure.

> ⚠️ **Keep your backup safe.** SSH keys give access to your servers and GitHub. Don't store backups on shared drives.

> 🛡️ **Non-POSIX destinations are blocked by default.** If the backup destination is FAT/exFAT/NTFS (typical for SD cards and USB sticks), `chmod 600` is a no-op there — anyone who mounts the card would be able to read your private keys. The script detects this, **skips the SSH section** automatically, and prints a warning. To force-include SSH keys on a non-POSIX destination anyway (e.g. for an offline cold-storage card you control), pass `--allow-insecure-dest`.

### 🗝️ KeePassXC Vault

The `~/Passwords.kdbx` database — your KeePassXC vault, used as the Secret Service backend for Proton Mail Bridge (see `BOOT_SEQUENCE_README.md`). The `.kdbx` file is already encrypted at rest with your master password, so it's safe to copy directly — no "export" needed (and KeePassXC's built-in Export feature would actually produce **plaintext** CSV/HTML/XML, the opposite of what you want).

If you also use a key file (`~/Passwords.key` or `~/Passwords.keyx`) it gets backed up alongside the database. Without the key file the `.kdbx` is unrecoverable even with the correct master password — they're a pair.

Permissions are locked to `600` on backup, same as SSH keys. The whole `keepassxc/` subfolder is `700`.

> ⚠️ **The backup is only as safe as where you put it.** A backed-up `.kdbx` is still encrypted, but it's also a portable copy of every secret you own. Don't park it on shared cloud drives without thinking about it. USB or external SSD is the cleanest path.

> 🛡️ **Non-POSIX destinations are blocked by default.** Same rule as SSH keys: on FAT/exFAT/NTFS the `chmod 600` is a no-op, so the script skips the KeePassXC vault automatically and prints a warning. The `.kdbx` is still encrypted at rest, but the **key file** (if you use one) is what makes it unrecoverable to anyone who lifts the card — and that file is plaintext. Use `--allow-insecure-dest` only if you know what you're doing.

> ✅ **Safe to copy while KeePassXC is open.** KeePassXC writes the database atomically on save, so the running app doesn't hold an exclusive lock. No need to quit it before running the backup.

### 🔌 Oh My Zsh Custom Plugins

Saves a `reinstall-plugins.sh` script that re-clones each plugin from its original GitHub source. The following plugins are captured:

- `zsh-autosuggestions` — grey command suggestions as you type
- `fast-syntax-highlighting` — real-time green/red command colouring
- `you-should-use` — reminds you when an alias exists

### 🔤 Fonts

Everything in `~/.local/share/fonts/` — including JetBrains Mono Nerd Font and any other custom fonts you've installed.

### 🐳 Distrobox Containers

Saves a `reinstall-containers.sh` script that recreates your containers using the original image. Currently captures:

- `mint-dev` — Linux Mint container used for all web development

> Note: The container's **contents** are not backed up (too large). The script just recreates the container from the same image. Your code lives in `~/codes` on the host so it's safe.

### 🗂️ Projects (`~/codes`)

For each project in `~/codes`:

- If it has a **git remote** → saves a `reclone-projects.sh` command to re-clone it on the correct branch
- If it has **no remote** → copies the folder directly (excluding `node_modules`, `dist`, `.nx`, `.cache`)

> ✅ Since `open-communities` is on GitLab, it will be saved as a clone command — fast and small.

### 📜 Shell Scripts (Desktop, strict whitelist)

Only two `.sh` files from `~/Desktop` are copied into `scripts/` — they're hard-coded by name:

- `backup.sh` — this script (now backs **itself** up too, so a fresh restore has the tool right there)
- `boot_sequence.sh` — Proton Bridge + KeePassXC autostart helper (see `BOOT_SEQUENCE_README.md`)

> 🛡️ **Why a whitelist?** Earlier versions globbed `~/Desktop/*.sh`, which would sweep up _any_ shell script you happened to drop on the Desktop — including throwaway experiments, scripts with embedded secrets, or stuff you'd rather not duplicate to a removable drive. The whitelist makes the contents of `scripts/` predictable and reviewable. To add a new script to the backup, edit the `SCRIPT_WHITELIST` array near the top of the "Shell Scripts" section in `backup.sh`.

### 📚 Documentation (`~/Desktop/*.md`)

Every `.md` file on your Desktop is copied into `docs/`. This means your READMEs are saved alongside the scripts they document, so future-you can always find the instructions. Currently captures:

- `BACKUP_README.md` — this file
- `BOOT_SEQUENCE_README.md` — boot sequence documentation

### 🔐 Checksums (and read-back verification)

Generates a `checksums.sha256` file of every backed up file, then **immediately reads it back with `sha256sum -c`** before declaring the backup successful. This catches silent corruption _during the write itself_ — exactly the failure mode of a weak SD card block — instead of waiting until you actually try to restore. If verification fails, the backup is marked with errors and a per-file mismatch list is dropped at `/tmp/sha256-verify-<pid>.log` so you can investigate. You can re-verify any older backup at any time with `sha256sum -c`.

### 🔁 Retention / rotation

Successful real backups automatically prune old `backup-*` siblings under the destination root, keeping the most recent **10** (configurable via `BACKUP_KEEP` near the top of the script). Pruning only runs when the current backup completed with **zero errors**, so a partial or corrupt backup can never displace a known-good older one. The prune step uses the same path-shape sanity guard as the failure cleanup trap, so even a future bug couldn't escalate it into deleting an unrelated directory.

### 📝 Run history logs

Every invocation (dry-run **and** real) writes a timestamped log to `~/.local/state/desktop-scripts/backup/`. This is **separate** from the per-backup `backup.log` that lives inside each backup folder — the history log captures the _whole run_ including the auto-dry-run preview, the confirmation prompt, and the final summary block.

|          | Per-backup log                                | Run history log                                     |
| -------- | --------------------------------------------- | --------------------------------------------------- |
| Where    | `<backup-dir>/backup.log`                     | `~/.local/state/desktop-scripts/backup/`            |
| What     | Just the file copy events for that one backup | The whole script run (preview + decisions + result) |
| When     | Created only on real runs                     | Created on **every** invocation, including dry-runs |
| Lifetime | Lives forever inside the backup               | Last 20 runs kept, older auto-pruned                |

Filenames follow `YYYYMMDD_HHMMSS_<mode>.log` where `<mode>` is `dryrun` or `real`. A `latest.log` symlink in the same directory always points at the most recent run. Colors are stripped from the file copy so it stays grep-friendly. Every log ends with a 🟩/🟨/🟥 final summary block (mode, start/end times, duration, warnings, errors, backup size, and on failure a numbered diagnostics checklist with copy-pasteable commands).

---

## Related Scripts

This backup is part of a small collection of helper scripts on the Desktop. They're documented separately but back each other up:

| Script             | Purpose                                                    | Docs                      |
| ------------------ | ---------------------------------------------------------- | ------------------------- |
| `backup.sh`        | This backup tool                                           | `BACKUP_README.md`        |
| `boot_sequence.sh` | Wait for KeePassXC at boot, then launch Proton Mail Bridge | `BOOT_SEQUENCE_README.md` |

If you're restoring from a backup, copy both `scripts/` and `docs/` back to `~/Desktop/` first — then everything else can be restored using the instructions in those READMEs.

---

## Security Features

- **Dry run mode** — check everything before committing to a real backup
- **Blocks running as root** — prevents accidental permission issues
- **Atomic per-user lock file** — created with `noclobber` in `$XDG_RUNTIME_DIR` (not `/tmp`), so other local users can't pre-create a symlink and trick the script into clobbering an arbitrary file. No TOCTOU window between the existence check and the write.
- **Strict whitelist for Desktop scripts** — only `backup.sh` and `boot_sequence.sh` are copied, never any other random `.sh` you may have dropped on the Desktop.
- **Non-POSIX destination guard** — SSH keys and KeePassXC vault are **skipped** if the destination is FAT/exFAT/NTFS (where `chmod 600` is a no-op). Override with `--allow-insecure-dest`.
- **Shell-quoted reinstall scripts** — generated `reinstall-containers.sh`, `reinstall-plugins.sh`, and `reclone-projects.sh` use `printf %q` for every interpolated value, so a hostile or weird remote URL / container name can't inject commands when you run them on a fresh machine.
- **NUL-delimited file pipelines** — checksum generation and log pruning use `find -print0 | xargs -0`, so filenames with spaces or newlines (e.g. inside `~/codes`) can't break the pipeline or feed `rm` an unintended path.
- **Glob loops over `ls`** — listing custom oh-my-zsh plugins uses a real glob, not `ls | grep`.
- **Self re-exec via `realpath`** — the auto dry-run child re-execs the script using `realpath "$0"`, so the same file runs regardless of cwd or how you invoked it.
- **Counter-preserving loops** — SSH and distrobox loops use `while … done < <(cmd)` instead of `cmd | while`, so warning/error counts inside the loop survive instead of being lost in a subshell. The final summary's `Errors:` line is trustworthy.
- **Real error messages from `cp` and `rsync`** — `safe_copy`, the SSH copy loop, the KeePassXC copies and the project rsync calls all capture stderr and surface the actual reason on failure (permission denied, no space, broken symlink, etc.) instead of swallowing it with `2>/dev/null`.
- **Cleanup-on-crash sanity guard** — the `rm -rf` in the failure trap refuses to delete anything that doesn't match the expected backup-directory shape (`<BACKUP_ROOT>/backup-*`). A future bug that empties or repoints `$BACKUP_DIR` cannot escalate into deleting an unrelated path.
- **Retention/rotation with the same sanity guard** — old `backup-*` siblings are auto-pruned after a successful run (keep newest `BACKUP_KEEP=10`), reusing the same path-shape check so a bug couldn't escalate it into deleting an unrelated directory. Pruning _only_ runs after a zero-error backup, so a partial/corrupt run can never displace a known-good older one.
- **Post-write checksum verification** — after generating `checksums.sha256` the script immediately re-reads every backed-up file with `sha256sum -c` and fails the run if any file doesn't match what was just written. Catches silent corruption from a flaky SD card _during_ the backup, not weeks later when you try to restore.
- **Autostart entries captured** — `~/.config/autostart/*.desktop` is backed up so the Proton Bridge + KeePassXC wiring survives a fresh-install restore without having to recreate `.desktop` files by hand from `BOOT_SEQUENCE_README.md`.
- **Linter-clean (shellcheck)** — both scripts are validated under shellcheck v0.10. The only suppressed warnings are documented file-wide directives (`SC2015` for an intentional `A && B || C` shorthand, `SC2317` for unreachable-code false positives inside trap handlers).
- **Strict argument parsing** — unknown `--flags` are rejected, and passing more than one destination is a hard error instead of silently winning the last one (no more typos on long command lines silently writing to the wrong card).
- **Tolerant final `du`** — the success block's size readout is wrapped in a `?` fallback so a transient I/O error on a flaky destination at the very end can't abort the script before the EXIT trap fires its summary.
- **Deterministic log flush** — the EXIT trap closes our stdout/stderr and `wait`s on the tee subprocess instead of `sleep 0.1`-ing and hoping. The final summary block is guaranteed to land in the run-history log.
- **SSH permissions** — private keys are saved as `600` and the `ssh/` subfolder is `700` (only meaningful on POSIX destinations, see above).
- **SSH permission warning** — alerts you if source keys have wrong permissions.
- **Disk space check** — requires at least 1GB free before starting.
- **Checksums** — SHA256 hash of every file so you can verify integrity later.
- **Strict mode** — `set -euo pipefail` catches unset variables and pipe failures.

---

## Usage

### Running the backup

The script **automatically runs a dry run first** every time you do a real backup — you don't need to run it manually. Here's what happens when you run it:

1. A dry run executes showing everything that will be backed up
2. You review the output
3. You are asked to confirm before any files are copied
4. Type to proceed or to cancel

**To home folder (default):**

```bash
bash backup.sh
```

**To a USB drive (recommended):**

```bash
bash backup.sh /run/media/deck/MY_USB
```

**To a FAT/exFAT card, including SSH keys + KeePassXC anyway:**

```bash
bash backup.sh --allow-insecure-dest /run/media/deck/lildeck
```

> Use this only when the card is something you physically control and won't lose. Without the flag, the script silently skips the SSH and KeePassXC sections on non-POSIX filesystems and prints a warning explaining why.

> **One destination only.** Passing more than one positional argument is now a hard error — the script used to silently pick the last one, which made `bash backup.sh /run/media/deck/typo /run/media/deck/MY_USB` write to the wrong place without warning. If you want to back up to two destinations, run the script twice.

### Manual dry run (optional)

If you just want to check without being prompted to confirm, you can still run the dry run on its own:

```bash
bash backup.sh --dry-run
```

This will show you:

- ✔ which files exist and are ready to be backed up
- ⚠ which files are missing or have wrong permissions
- 📋 exactly which projects, plugins and containers it found
- 💀 any fatal issues that would stop the backup (no disk space, not writable, etc.)

### Verify backup integrity

```bash
sha256sum -c ~/steamdeck-backup/backup-YYYY-MM-DD_HH-MM/checksums.sha256
```

### Get help

```bash
bash backup.sh --help
```

---

## Backup Structure

```
steamdeck-backup/
└── backup-2026-04-11_21-00/        # most recent (older siblings auto-pruned, BACKUP_KEEP=10)
    ├── dotfiles/                   # .zshrc, .gitconfig, etc.
    ├── autostart/                  # ~/.config/autostart/*.desktop entries
    ├── configs/
    │   ├── starship.toml
    │   ├── konsolerc
    │   └── konsole-profiles/       # All Konsole tab profiles
    ├── ssh/                        # SSH keys (chmod 600, POSIX destinations only)
    ├── keepassxc/                  # Passwords.kdbx (+ key file if any), chmod 600
    ├── omz-plugins/
    │   ├── plugins-list.txt
    │   └── reinstall-plugins.sh    # Re-clones all plugins
    ├── fonts/                      # JetBrains Mono etc.
    ├── distrobox/
    │   ├── containers-list.txt
    │   └── reinstall-containers.sh # Recreates containers
    ├── projects/
    │   └── reclone-projects.sh     # Re-clones all git projects
    ├── scripts/                    # backup.sh + boot_sequence.sh (strict whitelist)
    ├── docs/                       # Desktop *.md files (READMEs)
    ├── checksums.sha256            # Integrity verification (read back at write time)
    └── backup.log                  # Full log of what happened
```

---

## Restoring on a Fresh SteamOS

After a fresh install, run these in order:

**1. Restore dotfiles and configs manually**

```bash
cp dotfiles/.zshrc ~/
cp dotfiles/.gitconfig ~/
cp configs/starship.toml ~/.config/
cp -r configs/konsole-profiles ~/.local/share/konsole
cp configs/konsolerc ~/.config/
```

**2. Restore SSH keys**

```bash
cp -r ssh/ ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*
```

**2b. Restore KeePassXC vault** (only if you use Proton Mail Bridge or otherwise rely on KeePassXC)

```bash
cp keepassxc/Passwords.kdbx ~/
chmod 600 ~/Passwords.kdbx
# If a key file was backed up, restore it too:
[ -f keepassxc/Passwords.key ]  && cp keepassxc/Passwords.key  ~/ && chmod 600 ~/Passwords.key
[ -f keepassxc/Passwords.keyx ] && cp keepassxc/Passwords.keyx ~/ && chmod 600 ~/Passwords.keyx
```

Then install KeePassXC from Discover (`org.keepassxc.KeePassXC`) and open `~/Passwords.kdbx`. Re-enable Application Settings → Secret Service Integration and re-tick "Expose entries under group" in Database Settings — see `BOOT_SEQUENCE_README.md` for the full Bridge wiring.

**3. Install Oh My Zsh**

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

**4. Reinstall plugins**

```bash
bash omz-plugins/reinstall-plugins.sh
```

**5. Reinstall Starship**

```bash
curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir ~/.local/bin
```

**6. Recreate distrobox containers**

```bash
bash distrobox/reinstall-containers.sh
```

**7. Reclone projects**

```bash
bash projects/reclone-projects.sh
```

**8. Restore fonts**

```bash
cp -r fonts/ ~/.local/share/fonts
fc-cache -fv
```

**9. Restore Desktop scripts and docs**

```bash
cp scripts/*.sh ~/Desktop/
cp docs/*.md ~/Desktop/
chmod +x ~/Desktop/*.sh
```

**9b. Restore autostart entries** (only if you use Proton Mail Bridge or otherwise rely on session-start scripts)

```bash
mkdir -p ~/.config/autostart
cp autostart/*.desktop ~/.config/autostart/
```

This restores both the KeePassXC autostart entry and the modified Bridge entry that calls `boot_sequence.sh`. With this step you do **not** need to re-create the `.desktop` files by hand from `BOOT_SEQUENCE_README.md` — the wiring just works on the next login.

**10. Verify everything restored correctly**

```bash
sha256sum -c checksums.sha256
```

---

## Tips

- **The dry run is automatic** — every real backup shows you a preview and asks for confirmation before copying anything
- Run the backup **before every SteamOS update**, just in case
- Store your backup on a **USB drive or external SSD**, not just on the Steam Deck itself
- Your actual code is safe as long as it's pushed to GitLab/GitHub — the script only saves clone commands for those
- Check `backup.log` inside the backup folder if anything looks off, **or** the run history log at `~/.local/state/desktop-scripts/backup/latest.log` for the full picture (including the dry-run preview that ran before the real backup)
- Each backup is timestamped so you can keep multiple versions and roll back if needed

---

## What's NOT Backed Up

| What                                           | Why                                                                                                                                                                                            |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Games                                          | Too large, Steam handles this                                                                                                                                                                  |
| `node_modules`                                 | Reinstalled via `npm install`                                                                                                                                                                  |
| `dist` / `.nx` / `.cache`                      | Rebuilt automatically                                                                                                                                                                          |
| Distrobox container internals                  | Container is recreated from the original image                                                                                                                                                 |
| SteamOS system files                           | Read-only, can't be changed anyway                                                                                                                                                             |
| Other `.sh` files on the Desktop               | Strict whitelist — only `backup.sh` and `boot_sequence.sh` are copied. Anything else you drop on the Desktop is ignored on purpose.                                                            |
| SSH keys on FAT/exFAT/NTFS destinations        | `chmod 600` is a no-op there, so the script skips them by default. Override with `--allow-insecure-dest`.                                                                                      |
| KeePassXC vault on FAT/exFAT/NTFS destinations | Same reason. The `.kdbx` is encrypted at rest, but the key file (if any) is plaintext, and the whole point of the lockdown is to prevent casual access. Override with `--allow-insecure-dest`. |

---

## Verifying the Hardening

The security guarantees are only useful if you can confirm they actually fire. Each one is observable from a dry run — no real backup needed.

### 1. Non-POSIX destination guard (FAT/exFAT/NTFS)

Run a dry run against the SD card and look for the skip warnings:

```bash
bash ~/Desktop/backup.sh --dry-run /run/media/deck/lildeck
```

You should see, in the pre-flight section:

```
⚠ Destination filesystem is exfat — chmod 600 is a no-op here.
  → SSH keys and KeePassXC vault will be SKIPPED to avoid leaking secrets.
  → Re-run with --allow-insecure-dest to force-include them.
```

And in the SSH Keys + KeePassXC Vault sections:

```
⚠ Skipping SSH keys: destination is exfat (use --allow-insecure-dest to override)
⚠ Skipping KeePassXC vault: destination is exfat (use --allow-insecure-dest to override)
```

If you don't see these on a FAT/exFAT card, **stop and investigate** — the guard isn't firing and your secrets would be world-readable on that card.

To confirm the override flag works, re-run with `--allow-insecure-dest` and you should see the skip warnings replaced with normal "Backed up SSH file: …" lines.

### 2. Atomic lock file

Start a real backup, then while it's running open a second terminal and try to start another:

```bash
bash ~/Desktop/backup.sh
```

The second invocation should refuse to start with:

```
💀 FATAL: Another backup is already running (pid <N>, lock: /run/user/1000/steamdeck-backup.lock).
```

After the first one finishes, the lock file should be gone:

```bash
ls -l "${XDG_RUNTIME_DIR:-/run/user/$UID}/steamdeck-backup.lock"
# → No such file or directory
```

If the lock file is left behind after a clean exit, the cleanup trap is broken — file an issue against future-you.

### 3. Desktop script whitelist

Drop a sentinel script on the Desktop and confirm it's NOT picked up:

```bash
echo '#!/bin/bash' > ~/Desktop/should_not_be_backed_up.sh
bash ~/Desktop/backup.sh --dry-run | grep -i should_not_be_backed_up
# → (no output expected)
rm ~/Desktop/should_not_be_backed_up.sh
```

Only `backup.sh` and `boot_sequence.sh` should appear in the "Shell Scripts" section.

### 4. Generated reinstall scripts are shell-quoted

After a real backup, eyeball the generated scripts:

```bash
cat ~/steamdeck-backup/backup-*/projects/reclone-projects.sh
cat ~/steamdeck-backup/backup-*/distrobox/reinstall-containers.sh
cat ~/steamdeck-backup/backup-*/omz-plugins/reinstall-plugins.sh
```

Every interpolated value (remote URL, container name, branch, plugin name) should be either bare alphanumerics or quoted/escaped by `printf %q`. Anything containing a literal `;`, backtick, or `$(…)` would be a regression.
