#!/bin/bash
# ============================================================
# 💾 STEAMDECK DEV BACKUP SCRIPT
# Backs up dotfiles, projects, and dev environment config
# Usage: bash backup.sh [--dry-run] [destination]
# Example: bash backup.sh /run/media/deck/MY_USB
# ============================================================

# SC2015 (`A && B || C` is not if/then/else) is silenced file-wide below.
# That idiom is used throughout as intentional shorthand for "in dry-run
# mode call drywarn, otherwise call warn". The B branch is always a single
# echo/log/warn call that cannot fail, so the false-positive edge case the
# linter warns about does not apply here. Refactoring to full if/then/else
# would just add noise.
# shellcheck disable=SC2015

set -euo pipefail
IFS=$'\n\t'

# ─── USAGE ──────────────────────────────────────────────────
usage() {
  echo "Usage: bash backup.sh [--dry-run] [--allow-insecure-dest] [destination]"
  echo ""
  echo "  --dry-run               Check what would be backed up without copying anything"
  echo "  --allow-insecure-dest   Permit SSH keys + KeePassXC vault on non-POSIX filesystems"
  echo "                          (FAT/exFAT/NTFS — chmod is a no-op there, so secrets"
  echo "                          would be world-readable to anyone mounting the drive)"
  echo "  destination             Where to save the backup (default: ~/steamdeck-backup)"
  echo ""
  echo "Examples:"
  echo "  bash backup.sh                          # backup to ~/steamdeck-backup"
  echo "  bash backup.sh --dry-run                # check only, nothing is written"
  echo "  bash backup.sh /run/media/deck/MY_USB   # backup to USB drive"
  exit 0
}

# ─── FLAGS ──────────────────────────────────────────────────
DRY_RUN=false
ALLOW_INSECURE_DEST=false
POSITIONAL=""
POSITIONAL_COUNT=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --allow-insecure-dest) ALLOW_INSECURE_DEST=true ;;
    --help|-h) usage ;;
    --*) echo "Unknown option: $arg" >&2; usage ;;
    *)
      POSITIONAL="$arg"
      POSITIONAL_COUNT=$((POSITIONAL_COUNT + 1))
      ;;
  esac
done

# Reject more than one destination — silently picking the last one is a
# footgun on long command lines (typo'd path next to the real one, etc.).
if [ "$POSITIONAL_COUNT" -gt 1 ]; then
  echo "ERROR: too many destination arguments ($POSITIONAL_COUNT). Pass exactly one." >&2
  echo "       Got: $* " >&2
  usage
fi

# ─── CONFIG ─────────────────────────────────────────────────
BACKUP_ROOT="${POSITIONAL:-$HOME/steamdeck-backup}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
BACKUP_DIR="$BACKUP_ROOT/backup-$TIMESTAMP"
LOG="$BACKUP_DIR/backup.log"
LOG_KEEP=20                  # how many past run history logs to keep
BACKUP_KEEP=10               # how many past backup-* sibling directories to keep at $BACKUP_ROOT
ERRORS=0
WARNINGS=0
LOCK_FILE=""                 # set later in real-run mode; tracked for cleanup

# ─── RUN HISTORY LOGGING ────────────────────────────────────
# Per-invocation history log under XDG state, separate from the backup's own
# internal $LOG file. Output is tee'd live (terminal + file), with ANSI colors
# stripped from the file copy. A `latest.log` symlink always points at the
# most recent run. Old runs beyond $LOG_KEEP are pruned automatically. The
# nested auto-dry-run child inherits the parent's tee'd FDs, so it should NOT
# set up its own logging — we detect that via $_BACKUP_LOG_NESTED.
if [ -z "${_BACKUP_LOG_NESTED:-}" ]; then
  RUNLOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop-scripts/backup"
  mkdir -p "$RUNLOG_DIR"
  if $DRY_RUN; then MODE_TAG=dryrun; else MODE_TAG=real; fi
  RUN_START_EPOCH=$(date +%s)
  RUN_START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')
  RUNLOG_FILE="$RUNLOG_DIR/$(date +%Y%m%d_%H%M%S)_${MODE_TAG}.log"
  ln -sfn "$(basename "$RUNLOG_FILE")" "$RUNLOG_DIR/latest.log"

  # Capture the tee process PID so the EXIT trap can close our FDs and
  # `wait` on it deterministically — no `sleep`-based flush race.
  exec > >(tee >(sed -u 's/\x1B\[[0-9;]*[mGKHF]//g' > "$RUNLOG_FILE")) 2>&1
  TEE_PID=$!

  # Prune older logs. Use NUL-delimited sort/cut so log filenames containing
  # spaces or newlines (unlikely here, but cheap to be correct) can't break
  # the pipeline or feed an unintended path to rm.
  find "$RUNLOG_DIR" -maxdepth 1 -type f -name '*.log' -printf '%T@\t%p\0' 2>/dev/null \
    | sort -z -rn | tail -z -n +$((LOG_KEEP + 1)) | cut -z -f2- | xargs -0 -r rm -f

  echo "📝 Run history log: $RUNLOG_FILE"
  RUNLOG_ACTIVE=true
else
  RUNLOG_ACTIVE=false
fi

# ─── COLORS ─────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}✔ $1${NC}"; [ -f "$LOG" ] && echo "✔ $1" >> "$LOG" || true; }
warn()    { echo -e "${YELLOW}⚠ $1${NC}"; [ -f "$LOG" ] && echo "⚠ $1" >> "$LOG" || true; ((WARNINGS++)) || true; }
error()   { echo -e "${RED}✖ $1${NC}"; [ -f "$LOG" ] && echo "✖ $1" >> "$LOG" || true; ((ERRORS++)) || true; }
section() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}"; [ -f "$LOG" ] && { echo ""; echo "━━━ $1 ━━━"; } >> "$LOG" || true; }
fatal()   { echo -e "${RED}${BOLD}💀 FATAL: $1${NC}"; exit 1; }
drylog()  { echo -e "${BLUE}  📋 [DRY RUN] Would back up: $1${NC}"; }
drywarn() { echo -e "${YELLOW}  ⚠  [DRY RUN] Missing: $1${NC}"; ((WARNINGS++)) || true; }

# ─── CLEANUP ON FAILURE ─────────────────────────────────────
cleanup_on_error() {
  echo -e "\n${RED}${BOLD}💀 Backup failed unexpectedly! Cleaning up...${NC}"
  # Sanity-guard the rm: refuse to delete anything that doesn't look like a
  # backup directory we created. A future bug that empties $BACKUP_DIR or
  # points it somewhere unexpected must NOT be allowed to rm -rf the wrong
  # path. The shape we expect is "<BACKUP_ROOT>/backup-YYYY-MM-DD_HH-MM".
  if ! $DRY_RUN \
     && [ -n "${BACKUP_DIR:-}" ] \
     && [ -n "${BACKUP_ROOT:-}" ] \
     && [[ "$BACKUP_DIR" == "$BACKUP_ROOT"/backup-* ]] \
     && [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    echo -e "${YELLOW}⚠ Incomplete backup removed: $BACKUP_DIR${NC}"
  elif ! $DRY_RUN && [ -n "${BACKUP_DIR:-}" ]; then
    echo -e "${YELLOW}⚠ Refusing to remove $BACKUP_DIR — does not match expected backup shape${NC}"
  fi
  exit 1
}
trap cleanup_on_error ERR

# ─── FINAL SUMMARY (runs on every exit, success OR failure) ─
# Writes a human-readable result block at the end of the run history log,
# also handles lock file cleanup. Skipped entirely in nested dry-run children
# (the parent's trap handles it once for the whole run).
write_final_summary() {
  local exit_code=$?

  # Always release the lock file if we created one
  if [ -n "$LOCK_FILE" ] && [ -f "$LOCK_FILE" ]; then
    rm -f "$LOCK_FILE"
  fi

  $RUNLOG_ACTIVE || exit "$exit_code"

  local end_human end_epoch duration size
  end_human=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)
  duration=$((end_epoch - RUN_START_EPOCH))

  echo ""
  echo "════════════════════════════════════════════════════════════"
  if [ "$exit_code" -eq 0 ] && [ "$ERRORS" -eq 0 ]; then
    echo "✅ FINAL RESULT: SUCCESS"
  elif [ "$exit_code" -eq 0 ] && [ "$ERRORS" -gt 0 ]; then
    echo "⚠️  FINAL RESULT: COMPLETED WITH ERRORS"
  else
    echo "❌ FINAL RESULT: FAILED (exit code $exit_code)"
  fi
  echo "   📋 Mode:        $MODE_TAG"
  echo "   🕐 Started:     $RUN_START_HUMAN"
  echo "   🕑 Ended:       $end_human"
  echo "   ⏱  Duration:    ${duration}s"
  echo "   ⚠  Warnings:    $WARNINGS"
  echo "   ✖  Errors:      $ERRORS"
  echo "   📂 History log: $RUNLOG_FILE"
  if ! $DRY_RUN && [ -d "$BACKUP_DIR" ]; then
    size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo "   📦 Backup dir:  $BACKUP_DIR (${size:-?})"
    echo "   📄 Backup log:  $LOG"
  fi

  if [ "$exit_code" -ne 0 ] || [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "   🔍 Diagnostics — copy/paste these to investigate:"
    echo ""
    echo "   1️⃣  Re-read the full log for this run:"
    echo "       less $RUNLOG_FILE"
    echo ""
    echo "   2️⃣  Free space at the destination:"
    echo "       df -h $BACKUP_ROOT"
    echo ""
    echo "   3️⃣  Permissions on the destination:"
    echo "       ls -ld $BACKUP_ROOT"
    echo ""
    echo "   4️⃣  Stale lock file? (only matters if 'another backup is running' was the error)"
    echo "       ls -l \"\${XDG_RUNTIME_DIR:-/run/user/\$UID}/steamdeck-backup.lock\""
    echo ""
    echo "   5️⃣  Re-run as a dry-run to see the plan without writing:"
    echo "       bash ~/Desktop/backup.sh --dry-run"
  fi
  echo "════════════════════════════════════════════════════════════"

  # Close our stdout/stderr so the tee subprocess sees EOF on its input,
  # then wait for it to drain and exit. Deterministic — no race, no sleep.
  exec >&- 2>&-
  wait "${TEE_PID:-}" 2>/dev/null || true
  exit "$exit_code"
}
trap write_final_summary EXIT

# ─── HEADER ─────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}"
if $DRY_RUN; then
  echo "  🔍 STEAMDECK BACKUP — DRY RUN MODE"
  echo "  Nothing will be copied. Just checking what's available."
else
  echo "  💾 STEAMDECK DEV BACKUP"
fi
echo "  Destination: $BACKUP_DIR"
echo "  Timestamp:   $TIMESTAMP"
echo -e "${NC}"

# ─── SANITY CHECKS ──────────────────────────────────────────
section "Pre-flight Checks"

# Must not run as root
if [ "$EUID" -eq 0 ]; then
  fatal "Do not run this script as root. Run as your normal user (deck)."
fi

# Destination must be writable (skip in dry-run)
if ! $DRY_RUN; then
  mkdir -p "$BACKUP_ROOT" 2>/dev/null || fatal "Cannot create backup directory: $BACKUP_ROOT"
  if [ ! -w "$BACKUP_ROOT" ]; then
    fatal "Backup destination is not writable: $BACKUP_ROOT"
  fi

  # Check available disk space (require at least 1GB free)
  AVAILABLE_KB=$(df -k "$BACKUP_ROOT" | tail -1 | awk '{print $4}')
  REQUIRED_KB=1048576  # 1GB in KB
  if [ "$AVAILABLE_KB" -lt "$REQUIRED_KB" ]; then
    fatal "Not enough disk space. Available: $((AVAILABLE_KB / 1024))MB, Required: 1024MB"
  fi
  log "Disk space OK: $(df -h "$BACKUP_ROOT" | tail -1 | awk '{print $4}') free"
else
  # In dry-run, check if destination would be writable
  if mkdir -p "$BACKUP_ROOT" 2>/dev/null && [ -w "$BACKUP_ROOT" ]; then
    log "Destination is writable: $BACKUP_ROOT"
    AVAILABLE_KB=$(df -k "$BACKUP_ROOT" | tail -1 | awk '{print $4}')
    log "Disk space available: $(df -h "$BACKUP_ROOT" | tail -1 | awk '{print $4}')"
  else
    warn "Destination may not be writable: $BACKUP_ROOT"
  fi
fi

log "Running as user: $(whoami)"

# Detect destination filesystem. POSIX FSes (ext4/btrfs/xfs/zfs/f2fs) honor
# chmod 600 — FAT/exFAT/NTFS do not, so any "locked down" SSH key or kdbx
# copy is actually world-readable to anyone who mounts the card. Block the
# secrets sections by default on non-POSIX destinations; require an explicit
# --allow-insecure-dest opt-in to override.
DEST_FSTYPE=$(stat -f -c %T "$BACKUP_ROOT" 2>/dev/null || echo "unknown")
DEST_IS_POSIX=true
case "$DEST_FSTYPE" in
  ext2/ext3|ext4|btrfs|xfs|zfs|f2fs|tmpfs|reiserfs|jfs)
    DEST_IS_POSIX=true ;;
  msdos|vfat|exfat|fuseblk|ntfs|fat)
    DEST_IS_POSIX=false ;;
  *)
    # Unknown — assume non-POSIX to fail safe.
    DEST_IS_POSIX=false ;;
esac
if $DEST_IS_POSIX; then
  log "Destination filesystem: $DEST_FSTYPE (POSIX permissions honored)"
else
  if $ALLOW_INSECURE_DEST; then
    warn "Destination filesystem is $DEST_FSTYPE — chmod 600 is a no-op here."
    warn "  → SSH keys and KeePassXC vault will be readable to anyone mounting the drive."
    warn "  → Proceeding anyway because --allow-insecure-dest was passed."
  else
    warn "Destination filesystem is $DEST_FSTYPE — chmod 600 is a no-op here."
    warn "  → SSH keys and KeePassXC vault will be SKIPPED to avoid leaking secrets."
    warn "  → Re-run with --allow-insecure-dest to force-include them."
  fi
fi

log "Pre-flight checks passed ✔"

# ─── AUTO DRY RUN + CONFIRM (real run only) ─────────────────
if ! $DRY_RUN; then
  echo -e "${CYAN}${BOLD}"
  echo "  🔍 Running dry run first so you can review what will be backed up..."
  echo -e "${NC}"
  # Re-run self in dry-run mode, passing the destination.
  # _BACKUP_LOG_NESTED tells the child not to create its own run-history log;
  # the parent's tee already captures everything the child prints.
  # Resolve $0 to an absolute path so the dry-run child re-execs the same
  # file regardless of cwd or how we were invoked.
  _BACKUP_LOG_NESTED=1 bash "$(realpath "$0")" --dry-run "${POSITIONAL:-}"
  echo ""
  echo -e "${YELLOW}${BOLD}━━━ Ready to run the real backup? ━━━${NC}"
  echo -e "${YELLOW}This will copy files to: $BACKUP_DIR${NC}"
  echo ""
  read -r -p "$(echo -e "${BOLD}Proceed? [y/N]: ${NC}")" confirm
  case "$confirm" in
    [yY][eE][sS]|[yY]) echo -e "${GREEN}Starting backup...${NC}" ;;
    *) echo -e "${YELLOW}Backup cancelled.${NC}"; exit 0 ;;
  esac
fi

# ─── SETUP (skip in dry-run) ────────────────────────────────
if ! $DRY_RUN; then
  mkdir -p "$BACKUP_DIR"
  touch "$LOG"

  # Lock file to prevent concurrent runs. Lives in the per-user runtime dir
  # (not /tmp) so other local users can't pre-create it as a symlink and trick
  # us into clobbering an arbitrary path. We create it atomically with
  # `set -o noclobber` — if the file already exists, the redirect fails and
  # we abort without touching it. Cleanup is handled by write_final_summary.
  LOCK_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
  mkdir -p "$LOCK_DIR" 2>/dev/null || true
  LOCK_FILE="$LOCK_DIR/steamdeck-backup.lock"
  if ! ( set -o noclobber; echo $$ > "$LOCK_FILE" ) 2>/dev/null; then
    existing_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "?")
    LOCK_FILE=""  # don't delete a lock file we didn't create
    fatal "Another backup is already running (pid $existing_pid, lock: $LOCK_DIR/steamdeck-backup.lock). Delete it and retry if wrong."
  fi
fi

# ─── SAFE COPY HELPER ───────────────────────────────────────
safe_copy() {
  local src="$1"
  local dest="$2"
  local cp_err
  if $DRY_RUN; then
    drylog "$src"
  elif cp_err=$(cp -r "$src" "$dest" 2>&1); then
    log "Backed up: $src"
  else
    # Surface the actual cp error (permission denied, no space, broken
    # symlink, etc.) instead of swallowing it. The diagnostics block in
    # the final summary becomes actionable instead of just "Failed to copy".
    error "Failed to copy: $src — ${cp_err:-unknown error}"
  fi
}

# ─── DOTFILES ───────────────────────────────────────────────
section "Dotfiles"

if ! $DRY_RUN; then
  mkdir -p "$BACKUP_DIR/dotfiles"
fi

declare -a DOTFILES=(
  "$HOME/.zshrc"
  "$HOME/.zprofile"
  "$HOME/.bashrc"
  "$HOME/.profile"
  "$HOME/.gitconfig"
  "$HOME/.gitignore_global"
)

for file in "${DOTFILES[@]}"; do
  if [ -f "$file" ]; then
    safe_copy "$file" "$BACKUP_DIR/dotfiles/"
  else
    $DRY_RUN && drywarn "$file (not found)" || warn "Skipped $file (not found)"
  fi
done

# ─── CONFIGS ────────────────────────────────────────────────
section "App Configs"

if ! $DRY_RUN; then
  mkdir -p "$BACKUP_DIR/configs"
fi

if [ -f "$HOME/.config/starship.toml" ]; then
  safe_copy "$HOME/.config/starship.toml" "$BACKUP_DIR/configs/"
else
  $DRY_RUN && drywarn "starship.toml (not found)" || warn "Skipped starship.toml (not found)"
fi

if [ -d "$HOME/.local/share/konsole" ]; then
  safe_copy "$HOME/.local/share/konsole" "$BACKUP_DIR/configs/konsole-profiles"
else
  $DRY_RUN && drywarn "Konsole profiles (not found)" || warn "Skipped Konsole profiles (not found)"
fi

if [ -f "$HOME/.config/konsolerc" ]; then
  safe_copy "$HOME/.config/konsolerc" "$BACKUP_DIR/configs/"
else
  $DRY_RUN && drywarn "konsolerc (not found)" || warn "Skipped konsolerc (not found)"
fi

# ─── AUTOSTART ENTRIES ──────────────────────────────────────
# ~/.config/autostart/ holds the .desktop entries that wire boot_sequence.sh
# (and Bridge) into KDE's autostart. Without backing this up, a fresh restore
# leaves the script on the Desktop but not actually running at boot — you'd
# have to manually re-create the entry from BOOT_SEQUENCE_README.md every
# time. The directory is plain text, no secrets, safe everywhere.
section "Autostart Entries"

if [ -d "$HOME/.config/autostart" ]; then
  if [ -z "$(ls -A "$HOME/.config/autostart" 2>/dev/null)" ]; then
    $DRY_RUN && drywarn "Autostart directory is empty" || warn "Autostart directory is empty"
  else
    AUTOSTART_COUNT=$(find "$HOME/.config/autostart" -maxdepth 1 -type f -name '*.desktop' | wc -l)
    if $DRY_RUN; then
      drylog "$AUTOSTART_COUNT .desktop autostart entries in ~/.config/autostart"
    else
      mkdir -p "$BACKUP_DIR/autostart"
      safe_copy "$HOME/.config/autostart/." "$BACKUP_DIR/autostart/"
      log "Backed up $AUTOSTART_COUNT autostart entries"
    fi
  fi
else
  $DRY_RUN && drywarn "No ~/.config/autostart directory" || warn "No ~/.config/autostart directory found"
fi

# ─── SSH KEYS ───────────────────────────────────────────────
section "SSH Keys"

if ! $DEST_IS_POSIX && ! $ALLOW_INSECURE_DEST; then
  warn "Skipping SSH keys: destination is $DEST_FSTYPE (use --allow-insecure-dest to override)"
elif [ -d "$HOME/.ssh" ]; then
  # Use process substitution (`< <(find ...)`) instead of `find | while`.
  # A pipe puts the `while` loop in a subshell, so any warn/error counter
  # bumps inside it would be lost when the subshell exits — leaving the
  # final summary saying "0 errors" even after partial SSH failures.
  if $DRY_RUN; then
    while IFS= read -r -d '' keyfile; do
      filename=$(basename "$keyfile")
      perms=$(stat -c "%a" "$keyfile" 2>/dev/null || echo "unknown")
      if [[ "$filename" != *.pub && "$perms" != "600" && "$perms" != "unknown" ]]; then
        drywarn "SSH key $filename has permissions $perms — should be 600!"
      else
        drylog "SSH key: $filename (permissions: $perms ✔)"
      fi
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f -print0)
  else
    SSH_DIR="$BACKUP_DIR/ssh"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    while IFS= read -r -d '' keyfile; do
      filename=$(basename "$keyfile")
      if cp_err=$(cp "$keyfile" "$SSH_DIR/$filename" 2>&1); then
        chmod 600 "$SSH_DIR/$filename"
        perms=$(stat -c "%a" "$keyfile" 2>/dev/null || echo "unknown")
        if [[ "$filename" != *.pub && "$perms" != "600" && "$perms" != "unknown" ]]; then
          warn "SSH private key $filename has permissions $perms (should be 600)"
        fi
        log "Backed up SSH file: $filename"
      else
        error "Failed to copy SSH file: $filename — $cp_err"
      fi
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f -print0)
    log "SSH backup complete — permissions locked to 600"
  fi
else
  $DRY_RUN && drywarn "No .ssh directory found" || warn "No .ssh directory found"
fi

# ─── KEEPASSXC VAULT ────────────────────────────────────────
# The .kdbx file is already encrypted at rest with the master password,
# so it's safe to copy as-is. Permissions are locked down anyway because
# losing this file = losing every secret it holds. KeePassXC writes the
# database atomically on save, so copying it while the app is open is
# safe — no need to quit KeePassXC first. If a key file is also used
# (~/Passwords.key or .keyx), copy it too: without it the .kdbx is
# unrecoverable even with the master password.
section "KeePassXC Vault"

KDBX_SRC="$HOME/Passwords.kdbx"
shopt -s nullglob
KDBX_KEYFILES=("$HOME"/Passwords.key "$HOME"/Passwords.keyx)
shopt -u nullglob

if ! $DEST_IS_POSIX && ! $ALLOW_INSECURE_DEST; then
  warn "Skipping KeePassXC vault: destination is $DEST_FSTYPE (use --allow-insecure-dest to override)"
elif [ -f "$KDBX_SRC" ]; then
  if $DRY_RUN; then
    KDBX_SIZE=$(du -h "$KDBX_SRC" 2>/dev/null | cut -f1)
    drylog "KeePassXC database: $KDBX_SRC (${KDBX_SIZE:-?})"
    for kf in "${KDBX_KEYFILES[@]}"; do
      [ -f "$kf" ] && drylog "KeePassXC key file: $kf"
    done
  else
    KEEPASS_DIR="$BACKUP_DIR/keepassxc"
    mkdir -p "$KEEPASS_DIR"
    chmod 700 "$KEEPASS_DIR"
    if kdbx_err=$(cp "$KDBX_SRC" "$KEEPASS_DIR/" 2>&1); then
      chmod 600 "$KEEPASS_DIR/$(basename "$KDBX_SRC")"
      log "Backed up KeePassXC database: $(basename "$KDBX_SRC")"
    else
      error "Failed to copy KeePassXC database: $KDBX_SRC — ${kdbx_err:-unknown error}"
    fi
    for kf in "${KDBX_KEYFILES[@]}"; do
      if [ -f "$kf" ]; then
        if kf_err=$(cp "$kf" "$KEEPASS_DIR/" 2>&1); then
          chmod 600 "$KEEPASS_DIR/$(basename "$kf")"
          log "Backed up KeePassXC key file: $(basename "$kf")"
        else
          error "Failed to copy KeePassXC key file: $kf — ${kf_err:-unknown error}"
        fi
      fi
    done
  fi
else
  $DRY_RUN && drywarn "$KDBX_SRC (not found)" || warn "Skipped $KDBX_SRC (not found)"
fi

# ─── OH MY ZSH PLUGINS ──────────────────────────────────────
section "Oh My Zsh Custom Plugins"

if [ -d "$HOME/.oh-my-zsh/custom/plugins" ]; then
  for plugin_dir in "$HOME/.oh-my-zsh/custom/plugins"/*/; do
    plugin_name=$(basename "$plugin_dir")
    [ "$plugin_name" = "example" ] && continue
    if [ -d "$plugin_dir/.git" ]; then
      remote=$(git -C "$plugin_dir" remote get-url origin 2>/dev/null || echo "")
      if [ -n "$remote" ]; then
        $DRY_RUN && drylog "Plugin: $plugin_name → $remote" || log "  Saved reinstall for: $plugin_name"
      else
        $DRY_RUN && drywarn "Plugin $plugin_name has no git remote" || warn "  $plugin_name has no git remote — skipping"
      fi
    fi
  done

  if ! $DRY_RUN; then
    mkdir -p "$BACKUP_DIR/omz-plugins"
    # Glob loop instead of `ls | grep` so filenames with spaces/newlines
    # (and the unparseability of `ls` output in general) can't bite us.
    : > "$BACKUP_DIR/omz-plugins/plugins-list.txt"
    for plugin_dir in "$HOME/.oh-my-zsh/custom/plugins"/*/; do
      pname=$(basename "$plugin_dir")
      [ "$pname" = "example" ] && continue
      printf '%s\n' "$pname" >> "$BACKUP_DIR/omz-plugins/plugins-list.txt"
    done
    {
      echo "#!/bin/bash"
      echo "# Auto-generated by backup.sh on $TIMESTAMP"
      echo "set -e"
      echo ""
    } > "$BACKUP_DIR/omz-plugins/reinstall-plugins.sh"
    for plugin_dir in "$HOME/.oh-my-zsh/custom/plugins"/*/; do
      plugin_name=$(basename "$plugin_dir")
      [ "$plugin_name" = "example" ] && continue
      if [ -d "$plugin_dir/.git" ]; then
        remote=$(git -C "$plugin_dir" remote get-url origin 2>/dev/null || echo "")
        # Shell-quote remote + plugin_name so a hostile/odd remote URL or
        # plugin folder name can't inject commands into the restore script.
        # The path prefix lives inside its own double-quoted string and the
        # plugin name is appended as a separate %q-quoted token (bash
        # concatenates adjacent quoted strings). Putting %q *inside* the
        # double-quotes would emit `\ ` or `$'…'` sequences which are not
        # escape sequences inside "..." and would silently corrupt the path.
        # shellcheck disable=SC2016
        # The literal $ZSH_CUSTOM in the printf format is intentional — it
        # must be expanded at restore time on the new machine, not now.
        [ -n "$remote" ] && printf 'git clone %q "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/"%q\n' "$remote" "$plugin_name" >> "$BACKUP_DIR/omz-plugins/reinstall-plugins.sh"
      fi
    done
    chmod +x "$BACKUP_DIR/omz-plugins/reinstall-plugins.sh"
  fi
else
  $DRY_RUN && drywarn "No Oh My Zsh plugins directory" || warn "No Oh My Zsh custom plugins directory found"
fi

# ─── FONTS ──────────────────────────────────────────────────
section "Fonts"

if [ -d "$HOME/.local/share/fonts" ]; then
  FONT_COUNT=$(find "$HOME/.local/share/fonts" -type f | wc -l)
  $DRY_RUN && drylog "$FONT_COUNT font files in ~/.local/share/fonts" || {
    mkdir -p "$BACKUP_DIR/fonts"
    safe_copy "$HOME/.local/share/fonts/." "$BACKUP_DIR/fonts/"
    log "Backed up $FONT_COUNT font files"
  }
else
  $DRY_RUN && drywarn "No fonts directory found" || warn "No custom fonts directory found"
fi

# ─── DISTROBOX ──────────────────────────────────────────────
section "Distrobox Containers"

if command -v distrobox &>/dev/null; then
  # Process substitution (`< <(distrobox list ...)`) instead of `... | while`
  # so any warn/error counter bumps inside the loop survive — a `... | while`
  # puts the body in a subshell and silently drops counter changes. Same fix
  # we applied to the SSH section.
  if $DRY_RUN; then
    drylog "Distrobox containers found:"
    while IFS='|' read -r _ name status image; do
      name=$(echo "$name" | xargs)
      image=$(echo "$image" | xargs)
      status=$(echo "$status" | xargs)
      [ -n "$name" ] && echo -e "${BLUE}    📋 $name → $image ($status)${NC}"
    done < <(distrobox list 2>/dev/null | tail -n +2)
  else
    mkdir -p "$BACKUP_DIR/distrobox"
    distrobox list > "$BACKUP_DIR/distrobox/containers-list.txt" 2>/dev/null || warn "Could not list containers"
    {
      echo "#!/bin/bash"
      echo "# Auto-generated by backup.sh on $TIMESTAMP"
      echo "set -e"
      echo ""
    } > "$BACKUP_DIR/distrobox/reinstall-containers.sh"
    while IFS='|' read -r _ name status image; do
      name=$(echo "$name" | xargs)
      image=$(echo "$image" | xargs)
      if [ -n "$name" ] && [ -n "$image" ]; then
        # Shell-quote both fields so a container name/image containing
        # metacharacters can't inject commands into the restore script.
        printf 'distrobox create --name %q --image %q\n' "$name" "$image" >> "$BACKUP_DIR/distrobox/reinstall-containers.sh"
        log "  Saved container: $name ($image)"
      fi
    done < <(distrobox list 2>/dev/null | tail -n +2)
    chmod +x "$BACKUP_DIR/distrobox/reinstall-containers.sh"
  fi
else
  $DRY_RUN && drywarn "distrobox not found" || warn "distrobox not found — skipping"
fi

# ─── PROJECTS ───────────────────────────────────────────────
section "Projects (~/codes)"

if [ -d "$HOME/codes" ]; then
  if ! $DRY_RUN; then
    mkdir -p "$BACKUP_DIR/projects"
    {
      echo "#!/bin/bash"
      echo "# Auto-generated by backup.sh on $TIMESTAMP"
      echo "set -e"
      echo "mkdir -p ~/codes && cd ~/codes"
      echo ""
    } > "$BACKUP_DIR/projects/reclone-projects.sh"
  fi

  for project_dir in "$HOME/codes"/*/; do
    [ -d "$project_dir" ] || continue
    project_name=$(basename "$project_dir")

    if [ -d "$project_dir/.git" ]; then
      remote=$(git -C "$project_dir" remote get-url origin 2>/dev/null || echo "")
      branch=$(git -C "$project_dir" branch --show-current 2>/dev/null || echo "main")

      if [ -n "$remote" ]; then
        if $DRY_RUN; then
          drylog "Project: $project_name → git clone $remote (branch: $branch)"
        else
          # Shell-quote remote, project_name, and branch — any of these can
          # contain metacharacters that would otherwise inject into the
          # restore script. Branch defaults are also user-controlled.
          printf 'git clone %q && cd %q && git checkout %q && cd ..\n' "$remote" "$project_name" "$branch" >> "$BACKUP_DIR/projects/reclone-projects.sh"
          log "Saved reclone: $project_name (branch: $branch)"
        fi
      else
        $DRY_RUN && drywarn "$project_name has no remote — would copy files" || {
          warn "$project_name has no remote — copying files instead"
          # Capture rsync stderr so a copy failure surfaces the actual reason
          # (perm denied, no space, broken symlink, etc.) in the diagnostics
          # block. Same pattern as safe_copy.
          rsync_err=$(rsync -a --exclude='node_modules' --exclude='dist' --exclude='.nx' --exclude='.cache' --exclude='*.log' \
            "$project_dir" "$BACKUP_DIR/projects/$project_name/" 2>&1) \
            || error "Failed to copy $project_name — ${rsync_err:-unknown error}"
        }
      fi
    else
      $DRY_RUN && drywarn "$project_name is not a git repo — would copy files" || {
        warn "$project_name is not a git repo — copying files"
        rsync_err=$(rsync -a --exclude='node_modules' --exclude='dist' --exclude='.nx' --exclude='.cache' \
          "$project_dir" "$BACKUP_DIR/projects/$project_name/" 2>&1) \
          || error "Failed to copy $project_name — ${rsync_err:-unknown error}"
      }
    fi
  done

  if ! $DRY_RUN; then
    chmod +x "$BACKUP_DIR/projects/reclone-projects.sh"
  fi
else
  $DRY_RUN && drywarn "$HOME/codes not found" || warn "$HOME/codes directory not found — skipping"
fi

# ─── SHELL SCRIPTS (~/Desktop/*.sh) ─────────────────────────
section "Shell Scripts"

# Strict whitelist — only these two scripts get backed up. Any other .sh on
# the Desktop is intentionally ignored (security: avoid sweeping up unrelated
# or sensitive scripts the user may have dropped there).
SCRIPTS_SRC="$HOME/Desktop"
SCRIPT_WHITELIST=("backup.sh" "boot_sequence.sh")

if ! $DRY_RUN; then
  mkdir -p "$BACKUP_DIR/scripts"
fi
for name in "${SCRIPT_WHITELIST[@]}"; do
  script="$SCRIPTS_SRC/$name"
  if [ -f "$script" ]; then
    safe_copy "$script" "$BACKUP_DIR/scripts/"
  else
    $DRY_RUN && drywarn "$script (not found)" || warn "Skipped $script (not found)"
  fi
done

# ─── DOCUMENTATION (~/Desktop/*.md) ─────────────────────────
section "Documentation"

shopt -s nullglob
DOC_FILES=("$HOME/Desktop"/*.md)
shopt -u nullglob

if [ ${#DOC_FILES[@]} -gt 0 ]; then
  if ! $DRY_RUN; then
    mkdir -p "$BACKUP_DIR/docs"
  fi
  for doc in "${DOC_FILES[@]}"; do
    safe_copy "$doc" "$BACKUP_DIR/docs/"
  done
else
  $DRY_RUN && drywarn "No .md docs found in ~/Desktop" || warn "No .md docs found in ~/Desktop"
fi

# ─── CHECKSUM (real run only) ───────────────────────────────
if ! $DRY_RUN; then
  section "Generating Checksums"
  # NUL-delimited so project filenames with spaces/newlines don't break
  # checksum generation or accidentally feed sha256sum the wrong path.
  find "$BACKUP_DIR" -type f ! -name "checksums.sha256" ! -name "backup.log" -print0 \
    | sort -z | xargs -0 sha256sum > "$BACKUP_DIR/checksums.sha256" 2>/dev/null \
    || warn "Could not generate checksums"
  log "Checksums saved — verify with: sha256sum -c $BACKUP_DIR/checksums.sha256"

  # Verify the checksums we just wrote by reading them back. This catches
  # silent corruption *during the write itself* — the failure mode of a
  # weak SD card block — which would otherwise only surface much later
  # when you actually try to restore. Cheap insurance: one extra read pass.
  section "Verifying Checksums"
  if ( cd "$BACKUP_DIR" && sha256sum -c --quiet checksums.sha256 ) >/tmp/sha256-verify-$$.log 2>&1; then
    log "Checksums verified — every file reads back as written"
    rm -f /tmp/sha256-verify-$$.log
  else
    error "Checksum verification FAILED — destination may be corrupt"
    error "  → See /tmp/sha256-verify-$$.log for the list of mismatched files"
    error "  → Do NOT trust this backup until you've investigated"
  fi
fi

# ─── BACKUP RETENTION (real run only) ───────────────────────
# Prune old backup-* siblings under $BACKUP_ROOT, keeping the most recent
# $BACKUP_KEEP. Runs only after a successful real run so a partial/corrupt
# backup never displaces a known-good older one. Mtime-based ordering uses
# %T@ + NUL framing for the same correctness reasons as the log pruning.
if ! $DRY_RUN && [ "$ERRORS" -eq 0 ]; then
  section "Backup Retention"
  pruned=0
  while IFS= read -r -d '' old_dir; do
    # Sanity-guard the rm: must be a direct child of $BACKUP_ROOT and must
    # match the backup-* shape. Same defense-in-depth as cleanup_on_error.
    if [ -n "$old_dir" ] && [[ "$old_dir" == "$BACKUP_ROOT"/backup-* ]] && [ -d "$old_dir" ]; then
      rm -rf "$old_dir" && log "Pruned old backup: $(basename "$old_dir")" && pruned=$((pruned + 1))
    fi
  done < <(
    find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'backup-*' -printf '%T@\t%p\0' 2>/dev/null \
      | sort -z -rn \
      | tail -z -n +$((BACKUP_KEEP + 1)) \
      | cut -z -f2-
  )
  if [ "$pruned" -eq 0 ]; then
    log "Retention OK: $BACKUP_KEEP-or-fewer backups present, nothing to prune"
  else
    log "Retention applied: pruned $pruned old backup(s), kept the most recent $BACKUP_KEEP"
  fi
fi

# ─── SUMMARY ────────────────────────────────────────────────
section "Done"

if $DRY_RUN; then
  echo -e "${CYAN}${BOLD}"
  echo "  🔍 Dry run complete!"
  echo "  ⚠  Warnings : $WARNINGS"
  echo ""
  echo "  Everything looks good? Run the real backup:"
  echo "  bash backup.sh"
  echo "  bash backup.sh /run/media/deck/MY_USB"
  echo -e "${NC}"
else
  # Tolerate du failure (transient I/O on a flaky SD card right at the end)
  # so the success block can still print and the EXIT trap can run cleanly.
  BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
  BACKUP_SIZE=${BACKUP_SIZE:-?}
  echo -e "${GREEN}${BOLD}"
  echo "  ✅ Backup finished!"
  echo "  📁 Location : $BACKUP_DIR"
  echo "  📦 Size     : $BACKUP_SIZE"
  echo "  ⚠  Warnings : $WARNINGS"
  echo "  ✖  Errors   : $ERRORS"
  echo ""
  echo "  To restore on a new machine:"
  echo "  1. bash distrobox/reinstall-containers.sh"
  echo "  2. bash omz-plugins/reinstall-plugins.sh"
  echo "  3. bash projects/reclone-projects.sh"
  echo "  4. Copy dotfiles/ and configs/ manually (see BACKUP_README.md)"
  echo ""
  echo "  To verify backup integrity:"
  echo "  sha256sum -c $BACKUP_DIR/checksums.sha256"
  echo -e "${NC}"

  if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}⚠ Backup completed with $ERRORS error(s). Check: $LOG${NC}"
    exit 1
  fi
fi
