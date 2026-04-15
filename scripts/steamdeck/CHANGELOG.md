# Changelog

All notable changes to `backup.sh` and `boot_sequence.sh` (and their READMEs).
Dates use `YYYY-MM-DD`. Most recent on top.

---

## 2026-04-12 — Hardening pass + retention + verification

### `backup.sh`

**Added**

- **Autostart entries backup** — `~/.config/autostart/*.desktop` is now copied
  into `autostart/` in every backup, so a fresh-install restore re-wires
  KeePassXC + Proton Bridge without any manual `.desktop` editing.
- **Post-write checksum verification** — after generating `checksums.sha256`,
  the script immediately re-reads every file with `sha256sum -c` and fails the
  run if any file doesn't match. Catches silent SD-card corruption _during_ the
  backup, not weeks later at restore time. On failure, a per-file mismatch list
  is dropped at `/tmp/sha256-verify-<pid>.log`.
- **Retention / rotation** — successful real backups auto-prune old `backup-*`
  siblings under the destination root, keeping the most recent `BACKUP_KEEP=10`
  (configurable near the top of the script). Pruning **only** runs when the
  current backup completed with zero errors, and reuses the same path-shape
  sanity guard as the failure-cleanup trap, so a future bug couldn't escalate
  it into deleting an unrelated directory.

**Changed**

- **Linter pass** — both scripts validated under shellcheck v0.10. Fixed:
  unused-variable warnings in distrobox loop (`id` → `_`), single-quoted
  literal `~/codes` (now `$HOME/codes`), and an inline disable for an
  intentionally-literal `$ZSH_CUSTOM` reference inside a generated reinstall
  script. Suppressions documented file-wide: `SC2015` (intentional
  `A && B || C` shorthand) and `SC2317` (unreachable-code false positives
  inside trap handlers).

### `boot_sequence.sh`

**Changed**

- Linter-clean under shellcheck v0.10 with documented `SC2317` suppression
  on `write_final_summary()` (called from EXIT trap).

### Docs

- `BACKUP_README.md` — added "🚀 Autostart Entries", "🔁 Retention / rotation",
  and "🔐 Checksums (and read-back verification)" sections; new bullets in
  Security Features for retention, post-write verification, autostart capture,
  and shellcheck-clean; new step **9b** in "Restoring on a Fresh SteamOS" for
  restoring autostart entries; updated Backup Structure tree to show
  `autostart/` and `BACKUP_KEEP=10` annotation.
- `BOOT_SEQUENCE_README.md` — note in the SteamOS-update troubleshooting that
  `backup.sh` now captures `~/.config/autostart/`.

---

## 2026-04-11 — Final hardening round

### `backup.sh`

**Added**

- **Bridge launch verification** (in `boot_sequence.sh`, this round): after
  `flatpak run`, poll `flatpak ps` for up to 10s and exit non-zero if Bridge
  never appears. A broken Bridge install used to be reported as success.
- **Strict argument parsing** — unknown `--flags` are rejected, and passing
  more than one positional destination is a hard error (used to silently win
  the last one).
- **Tolerant final `du`** — the success block's size readout is wrapped in a
  `?` fallback so a transient I/O error at the very end can't abort the script
  before the EXIT trap fires its summary.
- **Deterministic log flush** — the EXIT trap closes our stdout/stderr and
  `wait`s on the tee subprocess, so the final summary block is guaranteed to
  land in the run-history log on slow filesystems.
- **Consistent error counting** — the ERR trap bumps `$ERRORS` so the final
  summary block can never say "Errors: 0" while exiting non-zero.
- **NUL-delimited log pruning** — `find -print0 | xargs -0` so a pathological
  filename can't ever feed `rm` an unintended path.
- **Self re-exec via `realpath`** — the auto dry-run child re-execs using
  `realpath "$0"`, so the same file runs regardless of cwd or invocation path.

### `boot_sequence.sh`

**Added**

- **Two-stage gate (Stage A + Stage B)** with **independent timeout budgets**
  (60s for Stage A — bus name registration, 300s for Stage B — collection
  unlock). A slow-booting Stage A can't eat into the user's typing time. The
  script refuses to launch Bridge into a locked collection on purpose, since
  doing so would silently rewrite `vault.enc` as insecure (unencrypted) and is
  unrecoverable without reconfiguring all Proton accounts.
- **Heartbeat in `--boot` mode** — prints one line every 10s while waiting so
  the autostart log shows it's alive.

---

## 2026-04 — Earlier rounds (security pass)

### `backup.sh`

**Added**

- **Self-backup** — `backup.sh` now captures itself (used to skip itself).
- **Strict whitelist for Desktop scripts** — only `backup.sh` and
  `boot_sequence.sh` are copied, never other random `.sh` files. (Earlier
  versions globbed `~/Desktop/*.sh`.)
- **Atomic per-user lock file** — created with `noclobber` in
  `$XDG_RUNTIME_DIR` (not `/tmp`), eliminating the symlink-attack TOCTOU.
- **Non-POSIX destination guard** — SSH keys and KeePassXC vault are skipped
  on FAT/exFAT/NTFS where `chmod 600` is a no-op. Override with
  `--allow-insecure-dest`.
- **Shell-quoted reinstall scripts** — generated `reinstall-containers.sh`,
  `reinstall-plugins.sh`, and `reclone-projects.sh` use `printf %q` for every
  interpolated value, blocking command injection from hostile remote URLs or
  weird container names.
- **Counter-preserving loops** — SSH/distrobox/plugin loops use
  `while … done < <(cmd)` instead of `cmd | while`, so warning/error counts
  inside the loop survive instead of being lost in a subshell.
- **Real error messages from `cp`/`rsync`** — `safe_copy` and friends capture
  stderr instead of swallowing it with `2>/dev/null`.
- **Cleanup-on-crash sanity guard** — the `rm -rf` in the failure trap refuses
  to delete anything that doesn't match `<BACKUP_ROOT>/backup-*`.
- **Glob loops over `ls`** — listing custom oh-my-zsh plugins uses a real
  glob, not `ls | grep`.

**Fixed**

- Plugin printf double-quote bug — `printf 'git clone %q "…/plugins/%q"\n'`
  had `%q` inside double-quotes, producing broken output for plugin names with
  whitespace. Fixed to concatenate the second `%q` as a separate token.
- Stale npm restore reference removed.

---

This changelog is hand-maintained alongside the scripts. If you make further
changes, add an entry at the top.
