#!/bin/bash
# ============================================================
# 🔐 STEAMDECK BOOT SEQUENCE — Proton Bridge + KeePassXC
# Waits for KeePassXC's Secret Service to appear on D-Bus AND
# for the default collection to be unlocked, then launches
# Proton Mail Bridge. The unlock check is required: KeePassXC
# registers the bus name as soon as it starts, before the kdbx
# is unlocked, so launching on bus-name alone races Bridge into
# a broken "No keychain available" state.
#
# Usage:
#   bash boot_sequence.sh             # interactive (auto dry-run + confirm)
#   bash boot_sequence.sh --dry-run   # check only, launches nothing
#   bash boot_sequence.sh --boot      # unattended (called by autostart)
#   bash boot_sequence.sh --help
# ============================================================

set -euo pipefail
IFS=$'\n\t'

# ─── USAGE ──────────────────────────────────────────────────
usage() {
  echo "Usage: bash boot_sequence.sh [--dry-run|--boot]"
  echo ""
  echo "  --dry-run   Validate environment, show what would happen, exit"
  echo "  --boot      Unattended mode for autostart (no prompts, no colors needed)"
  echo "  (no flag)   Interactive: auto dry-run, confirm, then run"
  echo ""
  exit 0
}

# ─── FLAGS ──────────────────────────────────────────────────
DRY_RUN=false
BOOT_MODE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --boot)    BOOT_MODE=true ;;
    --help|-h) usage ;;
    *) echo "Unknown argument: $arg"; usage ;;
  esac
done

# ─── CONFIG ─────────────────────────────────────────────────
KEEPASS_APP_ID="org.keepassxc.KeePassXC"
BRIDGE_APP_ID="ch.protonmail.protonmail-bridge"
SECRET_BUS_NAME="org.freedesktop.secrets"
SECRET_DEFAULT_PATH="/org/freedesktop/secrets/aliases/default"
# Two separate timeouts so Stage A's slow-boot delay can't eat into the
# user's "type your master password" budget. Stage A is fast (D-Bus name
# registration after KeePassXC starts) — 60s is plenty even on cold boots.
# Stage B is the human one — keep it at 300s.
STAGE_A_TIMEOUT_SEC=60       # how long to wait for the bus name to appear
STAGE_B_TIMEOUT_SEC=300      # how long to wait for the user to unlock the kdbx
POLL_INTERVAL_SEC=2
LOG_KEEP=20                  # how many past run logs to keep
WARNINGS=0
ERRORS=0

# ─── LOGGING ────────────────────────────────────────────────
# Every invocation gets its own timestamped log under XDG state. Output is
# tee'd live (terminal + file), with ANSI colors stripped from the file copy
# so it stays grep-friendly. A `latest.log` symlink always points at the most
# recent run. Old runs beyond $LOG_KEEP are pruned automatically.
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop-scripts/boot_sequence"
mkdir -p "$LOG_DIR"
if   [ "${BOOT_MODE:-false}" = "true" ]; then MODE_TAG=boot
elif [ "${DRY_RUN:-false}"   = "true" ]; then MODE_TAG=dryrun
else                                          MODE_TAG=interactive
fi
RUN_START_EPOCH=$(date +%s)
RUN_START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$LOG_DIR/$(date +%Y%m%d_%H%M%S)_${MODE_TAG}.log"
ln -sfn "$(basename "$LOG_FILE")" "$LOG_DIR/latest.log"

# Tee everything (stdout+stderr) to the log file with colors stripped.
# `sed -u` is line-buffered so the file stays current as the script runs.
# Capture the tee process PID so the EXIT trap can close our FDs and `wait`
# on it deterministically — without that we'd have to `sleep` and hope tee
# flushed in time, which races on slow filesystems.
exec > >(tee >(sed -u 's/\x1B\[[0-9;]*[mGKHF]//g' > "$LOG_FILE")) 2>&1
TEE_PID=$!

# Prune older logs (only real files, never the symlink). NUL-delimited so a
# pathological filename can't trick the pipeline into rm'ing the wrong path.
find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' -printf '%T@\t%p\0' 2>/dev/null \
  | sort -z -rn | tail -z -n +$((LOG_KEEP + 1)) | cut -z -f2- | xargs -0 -r rm -f

echo "📝 Logging this run to: $LOG_FILE"

# ─── COLORS ─────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}✔ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $1${NC}"; ((WARNINGS++)) || true; }
error()   { echo -e "${RED}✖ $1${NC}"; ((ERRORS++)) || true; }
section() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}"; }
fatal()   { echo -e "${RED}${BOLD}💀 FATAL: $1${NC}"; exit 1; }
drylog()  { echo -e "${BLUE}  📋 [DRY RUN] Would do: $1${NC}"; }
drywarn() { echo -e "${YELLOW}  ⚠  [DRY RUN] $1${NC}"; ((WARNINGS++)) || true; }

# ─── FINAL SUMMARY (runs on every exit, success OR failure) ─
# Writes a human-readable result block at the end of the log so future-you can
# tell at a glance what happened, when, and what to check next if it failed.
# All commands in this function are reached via `trap write_final_summary EXIT`
# below, but the linter's reachability analysis doesn't follow trap
# registrations and flags everything as unreachable — hence the disable.
# shellcheck disable=SC2317
write_final_summary() {
  local exit_code=$?
  local end_human end_epoch duration
  end_human=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)
  duration=$((end_epoch - RUN_START_EPOCH))

  echo ""
  echo "════════════════════════════════════════════════════════════"
  if [ "$exit_code" -eq 0 ]; then
    echo "✅ FINAL RESULT: SUCCESS"
  else
    echo "❌ FINAL RESULT: FAILED (exit code $exit_code)"
  fi
  echo "   📋 Mode:     $MODE_TAG"
  echo "   🕐 Started:  $RUN_START_HUMAN"
  echo "   🕑 Ended:    $end_human"
  echo "   ⏱  Duration: ${duration}s"
  echo "   ⚠  Warnings: $WARNINGS"
  echo "   ✖  Errors:   $ERRORS"
  echo "   📂 Log file: $LOG_FILE"

  if [ "$exit_code" -ne 0 ]; then
    echo ""
    echo "   🔍 Diagnostics — copy/paste these to investigate:"
    echo ""
    echo "   1️⃣  Is Secret Service on the bus at all?"
    echo "       busctl --user list | grep org.freedesktop.secrets"
    echo ""
    echo "   2️⃣  Is the kdbx actually unlocked? (should print 'b false')"
    echo "       busctl --user get-property org.freedesktop.secrets \\"
    echo "         /org/freedesktop/secrets/aliases/default \\"
    echo "         org.freedesktop.Secret.Collection Locked"
    echo ""
    echo "   3️⃣  Is KeePassXC running?"
    echo "       pgrep -af keepassxc"
    echo ""
    echo "   4️⃣  Bridge's own log (look for 'IsLocked' or 'vault will not be encrypted'):"
    echo "       ls -t ~/.var/app/ch.protonmail.protonmail-bridge/data/protonmail/bridge-v3/logs/*_bri_*.log | head -1"
    echo ""
    echo "   5️⃣  Re-run interactively to see the full dry-run plan:"
    echo "       bash ~/Desktop/boot_sequence.sh"
    echo ""
    echo "   ⚠  If Bridge's log shows 'vault will not be encrypted', the on-disk"
    echo "      vault is corrupted and you need to reconfigure Proton accounts."
    echo "      See BOOT_SEQUENCE_README.md → 'Insecure vault' section."
  fi
  echo "════════════════════════════════════════════════════════════"

  # Close our stdout/stderr so the tee subprocess sees EOF on its input,
  # then wait for it to drain and exit. Deterministic — no race, no sleep.
  exec >&- 2>&-
  wait "$TEE_PID" 2>/dev/null || true
}
trap write_final_summary EXIT

# Legacy ERR trap kept for backwards compatibility — emits a marker line and
# bumps $ERRORS so the EXIT-trap summary block reflects that an unexpected
# failure happened. Without this bump, a crash exits non-zero but the summary
# would still show "Errors: 0", which is contradictory.
# shellcheck disable=SC2317
cleanup_on_error() {
  echo -e "\n${RED}${BOLD}💀 Boot sequence hit an unexpected error!${NC}"
  ((ERRORS++)) || true
}
trap cleanup_on_error ERR

# ─── HEADER ─────────────────────────────────────────────────
if ! $BOOT_MODE; then
  echo -e "${CYAN}${BOLD}"
  if $DRY_RUN; then
    echo "  🔍 BOOT SEQUENCE — DRY RUN MODE"
    echo "  Nothing will be launched. Just checking the environment."
  else
    echo "  🔐 BOOT SEQUENCE — Proton Bridge + KeePassXC"
  fi
  echo -e "${NC}"
fi

# ─── PRE-FLIGHT CHECKS ──────────────────────────────────────
# In interactive mode (no flags), the parent skips pre-flight because it's
# about to delegate to a --dry-run child that runs the same checks. This
# avoids printing every check twice.
SKIP_PREFLIGHT=false
if ! $BOOT_MODE && ! $DRY_RUN; then
  SKIP_PREFLIGHT=true
fi

if ! $SKIP_PREFLIGHT; then
$BOOT_MODE || section "Pre-flight Checks"

# Must not run as root
if [ "$EUID" -eq 0 ]; then
  fatal "Do not run this script as root. Run as your normal user (deck)."
fi

# Required commands
for cmd in flatpak busctl; do
  if ! command -v "$cmd" &>/dev/null; then
    fatal "Required command not found: $cmd"
  fi
done
$BOOT_MODE || log "Required commands available: flatpak, busctl"

# KeePassXC flatpak installed? Hard required — the whole script exists to wait
# for it. If it's missing, fail loudly in both interactive AND boot modes so the
# log makes it obvious. Autostart will surface the failure in the run-history log.
if ! flatpak info "$KEEPASS_APP_ID" &>/dev/null; then
  error "KeePassXC flatpak not installed ($KEEPASS_APP_ID)"
  error "  → Install with: flatpak install flathub $KEEPASS_APP_ID"
  fatal "Cannot continue without KeePassXC — refusing to launch Bridge into a missing keychain."
fi
$BOOT_MODE || log "KeePassXC flatpak installed"

# Bridge flatpak installed? Same deal — hard required.
if ! flatpak info "$BRIDGE_APP_ID" &>/dev/null; then
  error "Proton Mail Bridge flatpak not installed ($BRIDGE_APP_ID)"
  error "  → Install with: flatpak install flathub $BRIDGE_APP_ID"
  fatal "Cannot continue without Proton Mail Bridge."
fi
$BOOT_MODE || log "Proton Mail Bridge flatpak installed"

# KeePassXC FdoSecrets enabled in config?
KEEPASS_INI="$HOME/.var/app/$KEEPASS_APP_ID/config/keepassxc/keepassxc.ini"
if [ -f "$KEEPASS_INI" ]; then
  if grep -q '^Enabled=true' <(awk '/^\[FdoSecrets\]/{f=1;next} /^\[/{f=0} f' "$KEEPASS_INI"); then
    $BOOT_MODE || log "KeePassXC FdoSecrets is enabled"
  else
    warn "KeePassXC FdoSecrets does not appear to be enabled in $KEEPASS_INI"
    warn "  → Open KeePassXC → Settings → Secret Service Integration → enable it"
  fi
else
  warn "KeePassXC config file not found: $KEEPASS_INI (first run?)"
fi

# Bridge already running? (don't double-launch)
BRIDGE_ALREADY_RUNNING=false
if flatpak ps --columns=application 2>/dev/null | grep -qx "$BRIDGE_APP_ID"; then
  BRIDGE_ALREADY_RUNNING=true
  $BOOT_MODE || warn "Proton Bridge is already running — will not relaunch"
fi

$BOOT_MODE || log "Pre-flight checks passed ✔"
fi  # end SKIP_PREFLIGHT guard

# ─── DRY RUN: SHOW PLAN AND EXIT ────────────────────────────
if $DRY_RUN; then
  section "Plan"
  drylog "Stage A: wait for $SECRET_BUS_NAME on the user D-Bus (timeout: ${STAGE_A_TIMEOUT_SEC}s)"
  drylog "Stage B: wait for the default collection to be Locked=false (timeout: ${STAGE_B_TIMEOUT_SEC}s)"
  drylog "          (Stage B is what actually blocks until you type the kdbx password)"
  if $BRIDGE_ALREADY_RUNNING; then
    drywarn "Bridge already running — would skip launch"
  else
    drylog "Once both stages pass, launch: flatpak run $BRIDGE_APP_ID"
  fi

  # Show current Secret Service status as a hint
  if busctl --user list 2>/dev/null | grep -q "$SECRET_BUS_NAME"; then
    log "Stage A satisfied: Secret Service is on D-Bus right now ✔"
    locked_now=$(busctl --user get-property org.freedesktop.secrets \
                   "$SECRET_DEFAULT_PATH" \
                   org.freedesktop.Secret.Collection Locked 2>/dev/null || echo "")
    if [ "$locked_now" = "b false" ]; then
      log "Stage B satisfied: default collection is currently unlocked ✔"
    elif [ "$locked_now" = "b true" ]; then
      warn "Stage B NOT satisfied: default collection is currently locked"
    else
      warn "Stage B status unknown (no default alias yet, or query failed)"
    fi
  else
    warn "Stage A NOT satisfied: Secret Service is not on D-Bus — KeePassXC isn't running"
  fi

  section "Done"
  echo -e "${CYAN}${BOLD}"
  echo "  🔍 Dry run complete!"
  echo "  ⚠  Warnings : $WARNINGS"
  echo "  ✖  Errors   : $ERRORS"
  echo ""
  echo "  Looks good? Run for real:"
  echo "  bash boot_sequence.sh"
  echo -e "${NC}"
  exit 0
fi

# ─── AUTO DRY-RUN + CONFIRM (interactive only) ──────────────
if ! $BOOT_MODE; then
  echo -e "${CYAN}${BOLD}"
  echo "  🔍 Running dry run first so you can review the plan..."
  echo -e "${NC}"
  # Resolve $0 to an absolute path so the dry-run child re-execs the same
  # file regardless of cwd or how we were invoked (relative path, symlink).
  bash "$(realpath "$0")" --dry-run
  echo ""
  echo -e "${YELLOW}${BOLD}━━━ Ready to wait for KeePassXC and launch Bridge? ━━━${NC}"
  read -r -p "$(echo -e "${BOLD}Proceed? [y/N]: ${NC}")" confirm
  case "$confirm" in
    [yY][eE][sS]|[yY]) echo -e "${GREEN}Starting...${NC}" ;;
    *) echo -e "${YELLOW}Cancelled.${NC}"; exit 0 ;;
  esac
fi

# ─── WAIT FOR SECRET SERVICE ────────────────────────────────
$BOOT_MODE || section "Waiting for Secret Service (Stage A: bus name)"

# Re-check (state may have changed since dry-run, and parent skipped pre-flight)
if flatpak ps --columns=application 2>/dev/null | grep -qx "$BRIDGE_APP_ID"; then
  $BOOT_MODE || warn "Bridge is already running — nothing to do"
  exit 0
fi

# Heartbeat in --boot mode: print one line so a tail-er can see we're alive.
# Re-printed every HEARTBEAT_EVERY_SEC so it's obvious the script is polling, not hung.
HEARTBEAT_EVERY_SEC=10
last_heartbeat=-999
$BOOT_MODE && echo "boot_sequence: [Stage A] waiting for $SECRET_BUS_NAME on user D-Bus..."

waited_a=0
while [ "$waited_a" -lt "$STAGE_A_TIMEOUT_SEC" ]; do
  if busctl --user list 2>/dev/null | grep -q "$SECRET_BUS_NAME"; then
    if $BOOT_MODE; then
      echo "boot_sequence: [Stage A] ✔ Secret Service detected after ${waited_a}s"
    else
      log "Stage A passed: Secret Service on D-Bus after ${waited_a}s"
    fi
    break
  fi
  if $BOOT_MODE && [ $((waited_a - last_heartbeat)) -ge $HEARTBEAT_EVERY_SEC ]; then
    echo "boot_sequence: [Stage A] still waiting... (${waited_a}s / ${STAGE_A_TIMEOUT_SEC}s)"
    last_heartbeat=$waited_a
  fi
  sleep "$POLL_INTERVAL_SEC"
  waited_a=$((waited_a + POLL_INTERVAL_SEC))
done

if [ "$waited_a" -ge "$STAGE_A_TIMEOUT_SEC" ]; then
  error "Timed out after ${STAGE_A_TIMEOUT_SEC}s waiting for $SECRET_BUS_NAME (Stage A)"
  error "  → Is KeePassXC running at all?"
  exit 1
fi

# ─── STAGE B: WAIT FOR COLLECTION TO UNLOCK ─────────────────
# KeePassXC registers the bus name immediately, but the kdbx is still locked
# until the user types the master password. Bridge MUST NOT launch before then,
# or it will get org.freedesktop.Secret.Error.IsLocked, cache "no keychain", and
# silently rewrite vault.enc as insecure — corrupting the stored vault key.
$BOOT_MODE || section "Waiting for KeePassXC database to unlock (Stage B)"
$BOOT_MODE && echo "boot_sequence: [Stage B] waiting for KeePassXC database to be unlocked (type your master password)..."
last_heartbeat=-999

# Stage B has its own independent budget so a slow-booting Stage A can't eat
# into the user's typing time. waited_b resets to 0 here.
waited_b=0
while [ "$waited_b" -lt "$STAGE_B_TIMEOUT_SEC" ]; do
  locked=$(busctl --user get-property org.freedesktop.secrets \
             "$SECRET_DEFAULT_PATH" \
             org.freedesktop.Secret.Collection Locked 2>/dev/null || echo "")
  if [ "$locked" = "b false" ]; then
    if $BOOT_MODE; then
      echo "boot_sequence: [Stage B] ✔ default collection unlocked after ${waited_b}s"
    else
      log "Stage B passed: default collection unlocked after ${waited_b}s"
    fi
    break
  fi
  if $BOOT_MODE && [ $((waited_b - last_heartbeat)) -ge $HEARTBEAT_EVERY_SEC ]; then
    echo "boot_sequence: [Stage B] still waiting for unlock... (${waited_b}s / ${STAGE_B_TIMEOUT_SEC}s)"
    last_heartbeat=$waited_b
  fi
  sleep "$POLL_INTERVAL_SEC"
  waited_b=$((waited_b + POLL_INTERVAL_SEC))
done

# Final verification — don't launch Bridge into a locked collection under any circumstance
locked_final=$(busctl --user get-property org.freedesktop.secrets \
                 "$SECRET_DEFAULT_PATH" \
                 org.freedesktop.Secret.Collection Locked 2>/dev/null || echo "")
if [ "$locked_final" != "b false" ]; then
  error "Timed out after ${STAGE_B_TIMEOUT_SEC}s waiting for the default collection to unlock"
  error "  → Open KeePassXC and unlock '$HOME/Passwords.kdbx' (or whichever DB is exposed)."
  error "  → Refusing to launch Bridge — doing so now would overwrite vault.enc as insecure."
  exit 1
fi

# ─── LAUNCH BRIDGE ──────────────────────────────────────────
$BOOT_MODE || section "Launching Proton Bridge"

# Use setsid + nohup so Bridge survives this script exiting (important for autostart)
setsid nohup flatpak run "$BRIDGE_APP_ID" >/dev/null 2>&1 &
bridge_pid=$!
disown || true

# Verify Bridge actually came up. `flatpak run` can fail immediately (broken
# install after a SteamOS update, missing runtime, etc.) and our backgrounded
# launch would silently report success. Poll for the app id in `flatpak ps`
# for up to BRIDGE_VERIFY_TIMEOUT seconds before declaring victory.
BRIDGE_VERIFY_TIMEOUT=10
verified=false
for ((i = 0; i < BRIDGE_VERIFY_TIMEOUT; i++)); do
  if flatpak ps --columns=application 2>/dev/null | grep -qx "$BRIDGE_APP_ID"; then
    verified=true
    break
  fi
  sleep 1
done

if $verified; then
  if $BOOT_MODE; then
    echo "boot_sequence: ✔ launched Proton Bridge (pid $bridge_pid, verified after ${i}s)"
  else
    log "Proton Bridge launched and verified running (pid $bridge_pid, after ${i}s)"
  fi
else
  error "Bridge launch did NOT show up in 'flatpak ps' within ${BRIDGE_VERIFY_TIMEOUT}s"
  error "  → flatpak run may have failed (broken install? missing runtime?)"
  error "  → Try manually: flatpak run $BRIDGE_APP_ID"
  exit 1
fi

# ─── SUMMARY ────────────────────────────────────────────────
if ! $BOOT_MODE; then
  section "Done"
  echo -e "${GREEN}${BOLD}"
  echo "  ✅ Boot sequence complete!"
  echo "  ⚠  Warnings : $WARNINGS"
  echo "  ✖  Errors   : $ERRORS"
  echo -e "${NC}"
fi

exit 0
