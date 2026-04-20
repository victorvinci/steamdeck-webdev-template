#!/usr/bin/env bash
# Extract one version's section from CHANGELOG.md.
#
# Usage: scripts/extract-changelog-section.sh <version> [changelog-path]
#   <version>        — e.g. 1.2.3 (no leading v)
#   [changelog-path] — defaults to CHANGELOG.md in the current dir
#
# Prints the section body (everything between `## [<version>]` and the next
# `## [` header), WITHOUT the header line — GitHub Release renders the
# title separately, so including the header duplicates it in the release
# notes.
#
# Exits 0 and prints the section if found (even if empty body).
# Exits 1 with an error message on stderr if no matching header exists.
#
# Used by `.github/workflows/release.yml` (auto-populates release notes on
# tag push) and `docs/RELEASE.md` (manual fallback recipe).

set -euo pipefail

VERSION="${1:?usage: $0 <version> [changelog-path]}"
CHANGELOG="${2:-CHANGELOG.md}"

if [ ! -f "$CHANGELOG" ]; then
    echo "error: changelog file not found: $CHANGELOG" >&2
    exit 1
fi

# awk: grab lines after `## [<VERSION>]`, stop at the next `## [` header.
# Literal-string match via `index()` — `$0 ~ ...` would interpolate `ver`
# into a regex, so a tag name containing `.`, `*`, `[`, etc. (release notes
# input is maintainer-controlled but still worth making dumb-safe) would
# match unintended sections or fail to match the intended one.
# `found` flips to 1 when we see the target header, so we can detect
# "no match" and fail loudly instead of silently emitting nothing.
OUTPUT=$(awk -v ver="$VERSION" '
    index($0, "## [" ver "]") == 1 { grab = 1; found = 1; next }
    grab && /^## \[/                { grab = 0 }
    grab                            { print }
    END                             { exit found ? 0 : 1 }
' "$CHANGELOG")

if [ $? -ne 0 ]; then
    echo "error: no '## [$VERSION]' section in $CHANGELOG" >&2
    exit 1
fi

printf '%s\n' "$OUTPUT"
