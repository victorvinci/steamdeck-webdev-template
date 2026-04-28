#!/usr/bin/env bash
# scripts/lint-migrations.sh
#
# Guard rails for db/migrations/. Catches the most common destructive-DDL
# footguns at PR time, before they ship.
#
# Usage:
#   bash scripts/lint-migrations.sh                 # lint db/migrations/
#   bash scripts/lint-migrations.sh path/to/dir     # lint a different dir
#
# Why this exists:
#   migrate.ts wraps each migration in a transaction, but the comment in
#   that file is explicit: "DDL statements (CREATE, ALTER, DROP, TRUNCATE)
#   implicitly commit and cannot be rolled back." So the safety net is at
#   author time, not run time. This script is that net.
#
# Rules (errors — fail CI):
#   - filename                  ^[0-9]+_[a-z0-9_-]+\.sql$
#   - duplicate-prefix          two files share a numeric prefix
#   - drop-table                DROP TABLE without IF EXISTS
#   - drop-database             DROP DATABASE (any form)
#   - drop-column               DROP COLUMN without IF EXISTS
#
# Rules (warnings — print but don't fail):
#   - numbering-gap             previous prefix N, current > N+1
#   - drop-index                DROP INDEX without IF EXISTS
#   - truncate                  TRUNCATE wipes all rows
#   - rename-table              RENAME TABLE breaks code referencing the old name
#
# Override syntax (in the .sql file):
#   -- lint-migrations: allow-<rule>
# Applies if present on the same line as the violation OR within the
# 3 lines immediately above it. Use this to acknowledge a deliberate
# deviation that has been reviewed.
#
# Example:
#   -- lint-migrations: allow-drop-table
#   DROP TABLE legacy_audit;
#
# Limitations (intentional, v1):
#   - Pattern matching is line-oriented. Multi-line ALTER statements
#     (e.g. ADD COLUMN ... NOT NULL split across lines) are not analyzed
#     for the NOT-NULL-without-DEFAULT case. That check would need a
#     statement-aware parser; deferred until we hit a real miss.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# If the first argument is an existing directory, lint that. Otherwise fall
# back to db/migrations/. The fallback also catches the lint-staged case,
# where staged .sql paths are appended as positional args — duplicate-prefix
# and numbering-gap checks need the full set of files anyway, so a per-file
# invocation wouldn't be meaningful.
if [ -n "${1:-}" ] && [ -d "$1" ]; then
    MIGRATIONS_DIR="$1"
else
    MIGRATIONS_DIR="$ROOT/db/migrations"
fi

errors=0
warnings=0
files_scanned=0

if [ -t 1 ]; then
    RED=$'\033[31m'
    YELLOW=$'\033[33m'
    GREEN=$'\033[32m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
else
    RED='' YELLOW='' GREEN='' DIM='' RESET=''
fi

err() {
    printf '%sERROR%s %s\n' "$RED" "$RESET" "$1" >&2
    errors=$((errors + 1))
}

warn() {
    printf '%sWARN %s %s\n' "$YELLOW" "$RESET" "$1" >&2
    warnings=$((warnings + 1))
}

if [ ! -d "$MIGRATIONS_DIR" ]; then
    echo "No migrations directory at $MIGRATIONS_DIR — nothing to lint."
    exit 0
fi

shopt -s nullglob
files=("$MIGRATIONS_DIR"/*.sql)
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
    echo "No migrations in $MIGRATIONS_DIR — nothing to lint."
    exit 0
fi

# Sort lexicographically so 002 follows 001 even if filesystem returns them
# out of order on weird mounts.
IFS=$'\n' read -r -d '' -a files < <(printf '%s\n' "${files[@]}" | sort && printf '\0')

# 1) Filename + numbering checks
FILENAME_RE='^[0-9]+_[a-z0-9_-]+\.sql$'
declare -A seen_prefix
prev_num=-1
for path in "${files[@]}"; do
    f="$(basename "$path")"
    files_scanned=$((files_scanned + 1))
    if [[ ! "$f" =~ $FILENAME_RE ]]; then
        err "$f  filename must match ^[0-9]+_<slug>.sql (lowercase a-z, digits, _, -)"
        continue
    fi
    num="${f%%_*}"
    num_int=$((10#$num))
    if [ -n "${seen_prefix[$num]:-}" ]; then
        err "$f  duplicate numeric prefix '$num' (also used by ${seen_prefix[$num]})"
    else
        seen_prefix[$num]="$f"
    fi
    if [ $prev_num -ge 0 ] && [ $num_int -gt $((prev_num + 1)) ]; then
        prev_str=$(printf '%03d' "$prev_num")
        warn "$f  numbering gap (previous was ${prev_str}, this is ${num})"
    fi
    prev_num=$num_int
done

# 2) Per-file content rules
#
# has_override <file> <line_no> <rule_name>
#   → returns 0 if an override marker is present on the line itself or
#     within the 3 lines above it; 1 otherwise.
has_override() {
    local path=$1 lineno=$2 rule=$3 start
    start=$((lineno - 3))
    [ $start -lt 1 ] && start=1
    sed -n "${start},${lineno}p" "$path" \
        | grep -qE "lint-migrations:[[:space:]]+allow-${rule}\\b"
}

# scan_rule <file> <pattern> <antipattern_or_empty> <severity> <rule> <msg>
#   pattern        — case-insensitive ERE that flags a violation.
#   antipattern    — if non-empty, lines also matching this are skipped
#                    (used to exclude the safe form, e.g. "DROP TABLE IF EXISTS").
#   severity       — "error" or "warning".
#   rule           — short slug used in override comments.
#   msg            — human message printed to stderr.
scan_rule() {
    local path=$1 pattern=$2 anti=$3 severity=$4 rule=$5 msg=$6
    local f
    f="$(basename "$path")"
    local lineno line
    while IFS=: read -r lineno line; do
        [ -z "${lineno:-}" ] && continue
        if [ -n "$anti" ] && grep -qiE "$anti" <<<"$line"; then
            continue
        fi
        if has_override "$path" "$lineno" "$rule"; then
            continue
        fi
        local snippet
        snippet="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//' | cut -c1-80)"
        if [ "$severity" = "error" ]; then
            err "$f:$lineno  $msg  ${DIM}→ ${snippet}${RESET}"
        else
            warn "$f:$lineno  $msg  ${DIM}→ ${snippet}${RESET}"
        fi
    done < <(grep -niE "$pattern" "$path" || true)
}

for path in "${files[@]}"; do
    f="$(basename "$path")"
    [[ "$f" =~ $FILENAME_RE ]] || continue

    scan_rule "$path" \
        '\bdrop[[:space:]]+table\b' \
        'drop[[:space:]]+table[[:space:]]+if[[:space:]]+exists' \
        error 'drop-table' \
        "DROP TABLE without IF EXISTS"

    scan_rule "$path" \
        '\bdrop[[:space:]]+database\b' \
        '' \
        error 'drop-database' \
        "DROP DATABASE is destructive — almost never what a migration should do"

    scan_rule "$path" \
        '\bdrop[[:space:]]+column\b' \
        'drop[[:space:]]+column[[:space:]]+if[[:space:]]+exists' \
        error 'drop-column' \
        "DROP COLUMN without IF EXISTS"

    scan_rule "$path" \
        '\bdrop[[:space:]]+index\b' \
        'drop[[:space:]]+index[[:space:]]+if[[:space:]]+exists' \
        warning 'drop-index' \
        "DROP INDEX without IF EXISTS"

    scan_rule "$path" \
        '\btruncate[[:space:]]+(table[[:space:]]+)?[a-z_]' \
        '' \
        warning 'truncate' \
        "TRUNCATE wipes all rows — confirm this is intentional"

    scan_rule "$path" \
        '\brename[[:space:]]+table\b' \
        '' \
        warning 'rename-table' \
        "RENAME TABLE silently breaks any code still referencing the old name"
done

echo
if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    printf '%sOK%s   scanned %d migration(s); no issues.\n' "$GREEN" "$RESET" "$files_scanned"
else
    printf 'Scanned %d migration(s): %d error(s), %d warning(s).\n' \
        "$files_scanned" "$errors" "$warnings"
fi

[ $errors -gt 0 ] && exit 1
exit 0
