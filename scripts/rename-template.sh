#!/usr/bin/env bash
#
# Mechanical rename of template identifiers on a fresh fork.
#
# Requires bash 3.2+ (uses `set -euo pipefail` and array-less syntax). Will
# NOT run under /bin/sh (e.g. dash on Debian, ash on Alpine) — invoke as
# `bash scripts/rename-template.sh` or via the shebang on a system with
# bash on PATH. macOS, Linux desktop distros, and standard CI images
# (ubuntu-latest, etc.) all ship bash by default.
#
# Replaces four categories of hard-coded values with fork-specific ones:
#   1. project name:   steamdeck-webdev-template   -> --project-name
#   2. GitHub owner:   victorvinci                 -> --github-owner
#   3. npm scope:      @mcb/                       -> @<npm-scope>/
#   4. maintainer:     victorvinci@protonmail.com  -> --maintainer-email
#
# Touches only the files in the explicit allowlists below. Historical records
# (CHANGELOG.md, .ai-attribution.jsonl, docs/SECURITY-AUDIT-v1.0.0*.md) are
# NOT touched — they are point-in-time records that should keep the original
# names for audit traceability.
#
# Idempotent when called with the same arguments (running twice is a no-op
# on the second pass because the search strings no longer match).
#
# Usage:
#   scripts/rename-template.sh \
#       --project-name     my-cool-app \
#       --github-owner     alice \
#       --npm-scope        acme \
#       --maintainer-email alice@example.com \
#       [--force-dirty] \
#       [--skip-check]
#
# Afterwards, review the diff and commit the rename as a single commit.
# The script runs `npm run format` and `npm run check` at the end; both
# must pass before you commit. Pass `--skip-check` to skip them when you
# plan to verify by hand (e.g. iterating on the rename arguments).

set -euo pipefail

PROJECT_NAME=""
GITHUB_OWNER=""
NPM_SCOPE=""
MAINTAINER_EMAIL=""
FORCE_DIRTY="no"
SKIP_CHECK="no"

usage() {
    cat <<'EOF' >&2
Usage:
    scripts/rename-template.sh \
        --project-name     <kebab-case>          e.g. my-cool-app
        --github-owner     <gh-handle>           e.g. alice  (no leading @)
        --npm-scope        <npm-scope>           e.g. acme   (no leading @)
        --maintainer-email <email>               e.g. alice@example.com
        [--force-dirty]                          allow running on a dirty worktree
        [--skip-check]                           skip the trailing format + check step

Run from the repository root.
EOF
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --project-name)     PROJECT_NAME="${2:-}";     shift 2 ;;
        --github-owner)     GITHUB_OWNER="${2:-}";     shift 2 ;;
        --npm-scope)        NPM_SCOPE="${2:-}";        shift 2 ;;
        --maintainer-email) MAINTAINER_EMAIL="${2:-}"; shift 2 ;;
        --force-dirty)      FORCE_DIRTY="yes";         shift   ;;
        --skip-check)       SKIP_CHECK="yes";          shift   ;;
        -h|--help)          usage ;;
        *) echo "Unknown argument: $1" >&2; usage ;;
    esac
done

[ -n "$PROJECT_NAME"     ] || { echo "Missing --project-name"     >&2; usage; }
[ -n "$GITHUB_OWNER"     ] || { echo "Missing --github-owner"     >&2; usage; }
[ -n "$NPM_SCOPE"        ] || { echo "Missing --npm-scope"        >&2; usage; }
[ -n "$MAINTAINER_EMAIL" ] || { echo "Missing --maintainer-email" >&2; usage; }

# Validate input shapes to catch fat-fingers before we touch files.
if ! printf '%s' "$PROJECT_NAME" | grep -Eq '^[a-z][a-z0-9-]*$'; then
    echo "Invalid --project-name '$PROJECT_NAME': must be lowercase kebab-case (a-z, 0-9, '-')." >&2
    exit 1
fi
if ! printf '%s' "$GITHUB_OWNER" | grep -Eq '^[a-zA-Z0-9][a-zA-Z0-9-]*$'; then
    echo "Invalid --github-owner '$GITHUB_OWNER': GitHub handle characters only, no leading '@'." >&2
    exit 1
fi
if ! printf '%s' "$NPM_SCOPE" | grep -Eq '^[a-z0-9][a-z0-9_-]*$'; then
    echo "Invalid --npm-scope '$NPM_SCOPE': must start with a-z0-9 and contain only a-z, 0-9, '-', '_'. No leading '@'." >&2
    exit 1
fi
if ! printf '%s' "$MAINTAINER_EMAIL" | grep -Eq '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'; then
    echo "Invalid --maintainer-email '$MAINTAINER_EMAIL': expected a simple local@host.tld shape." >&2
    exit 1
fi

# Anchor at the repo root regardless of where the user invoked us from.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Bail unless the worktree is clean — the script is destructive and a dirty
# tree makes the resulting diff impossible to review. --force-dirty is an
# escape hatch for script authors iterating on the rename script itself.
if [ "$FORCE_DIRTY" != "yes" ]; then
    if [ -n "$(git status --porcelain 2>/dev/null || true)" ]; then
        echo "Refusing to run with uncommitted changes. Commit or stash first, or pass --force-dirty." >&2
        exit 1
    fi
fi

# Portable in-place sed. GNU accepts `sed -i '<expr>'`, BSD requires `sed -i
# '' '<expr>'`; both accept the tmpfile form below.
inplace_sed() {
    local expr="$1"
    shift
    for f in "$@"; do
        if [ ! -f "$f" ]; then
            echo "WARN: expected file not found, skipping: $f" >&2
            continue
        fi
        sed "$expr" "$f" > "$f.tmp"
        mv "$f.tmp" "$f"
    done
}

echo "==> Renaming with:"
echo "    project-name     = $PROJECT_NAME"
echo "    github-owner     = $GITHUB_OWNER"
echo "    npm-scope        = @$NPM_SCOPE"
echo "    maintainer-email = $MAINTAINER_EMAIL"
echo

# Files that legitimately RETAIN template strings — never rewritten. This
# mirrors the EXCLUDE in scan-template-residuals.sh EXACTLY: this script and
# the scanner both hold the strings as literal search patterns, docs/FORK.md
# + docs/UPGRADE.md document the rename mapping, and CHANGELOG / the
# attribution log are point-in-time history. Keeping the two exclude sets
# byte-identical IS the invariant — the rename rewrites precisely the files
# (and strings) the residual scanner checks, so neither can drift from the
# other. If you edit this regex, edit the scanner's to match.
TEMPLATE_EXCLUDE='^(CHANGELOG\.md|\.ai-attribution\.jsonl|docs/SECURITY-AUDIT-v1\.0\.0|scripts/rename-template\.sh|scripts/scan-template-residuals\.sh|docs/FORK\.md|docs/UPGRADE\.md)'

# Rewrite every occurrence of a fixed literal across all tracked files,
# discovered dynamically via `git grep` rather than a hand-curated per-pass
# list. The old lists drifted silently whenever a new file adopted a template
# identifier: the OpenAPI module (registry.ts importing @mcb/types,
# openapi.json's API title) and the gitleaks files were added after the lists
# were last curated, so a renamed fork failed `npm run check` (TS2307 on the
# unrewritten @mcb/types import) and then the residual scan. git grep keeps
# every pass in lockstep with the repo automatically.
#
# Array-less for bash 3.2 (see header); word-splitting on the file list is
# safe because tracked paths in this repo contain no spaces or newlines.
# `git grep -lF` is a fixed-string search for DISCOVERY only — the sed itself
# is unchanged from the original (regex `s|literal|replacement|g`, same
# literals and `|` delimiter, none of which contain `|`). `|| true` keeps
# `set -e`/pipefail from aborting when a literal matches nothing.
rename_token() {
    local literal="$1" replacement="$2" files
    files=$(git grep -lF "$literal" | grep -vE "$TEMPLATE_EXCLUDE" || true)
    if [ -n "$files" ]; then
        echo "    $(printf '%s\n' "$files" | grep -c .) file(s)"
        # shellcheck disable=SC2086
        inplace_sed "s|${literal}|${replacement}|g" $files
    else
        echo "    (no files reference '${literal}')"
    fi
}

# ORDER MATTERS: the maintainer email contains 'victorvinci' as its local
# part, so substitute the whole email FIRST — otherwise the owner pass below
# rewrites the local part and produces a broken address. Both passes are now
# dynamic, so an email in ANY file (not just a curated few) is caught before
# the owner pass runs.
echo "==> 1/4  maintainer email (victorvinci@protonmail.com -> ${MAINTAINER_EMAIL})"
rename_token 'victorvinci@protonmail.com' "${MAINTAINER_EMAIL}"

echo "==> 2/4  npm scope (@mcb/ -> @${NPM_SCOPE}/)"
rename_token '@mcb/' "@${NPM_SCOPE}/"

echo "==> 3/4  project name (steamdeck-webdev-template -> ${PROJECT_NAME})"
# git grep finds package-lock.json automatically (the project name lives at
# the root and the empty-key workspace entry), so package.json and the
# lockfile stay in sync without naming either explicitly.
rename_token 'steamdeck-webdev-template' "${PROJECT_NAME}"

echo "==> 4/4  github owner (victorvinci -> ${GITHUB_OWNER})"
rename_token 'victorvinci' "${GITHUB_OWNER}"

if [ "$SKIP_CHECK" = "yes" ]; then
    echo
    echo "==> Skipping format + check (--skip-check). Run \`npm run format && npm run check\` yourself before committing."
else
    echo
    echo "==> Running: npm run format  (prettier re-normalises anything sed mangled)"
    npm run format --silent

    echo "==> Running: npm run check   (format:check + lint + typecheck + test)"
    if ! npm run check; then
        echo
        echo "npm run check failed. The rename left the repo in a bad state." >&2
        echo "Review the diff, fix by hand or re-run with corrected args, and commit only when check is green." >&2
        exit 1
    fi
fi

echo
echo "==> Rename complete."
echo "    Review: git diff"
echo "    Commit: git add -A && git commit -m 'chore: rename template to ${PROJECT_NAME}'"
echo
echo "Next manual steps (this script can't automate them — see docs/FORK.md):"
echo "  - replace .github/CODEOWNERS.txt handle with your actual reviewers (or delete the file)"
echo "  - update the 'Built on a Steam Deck' notice in README.md if it doesn't apply to you"
echo "  - strip the sample Users domain if your new project doesn't need it"
echo "  - configure branch rulesets, Nx Cloud, Renovate, Pages per docs/FORK.md"
