#!/usr/bin/env bash
# Scan the working tree for template strings (`steamdeck-webdev-template`,
# `@mcb/`, `victorvinci`) that should have been rewritten by
# `scripts/rename-template.sh` but weren't.
#
# Used by `.github/workflows/ci-scheduled.yml`'s `template-rename`
# self-test job: that job runs the rename script against a test set of
# values (`foo-fork`, `alice`, `acme`) and then invokes this scanner to
# confirm no original template strings remain in files outside the
# documented exceptions.
#
# WHY THIS LIVES IN A SEPARATE SCRIPT:
#   This file is intentionally NOT in `scripts/rename-template.sh`'s
#   allowlist for any sed pass — its literal search patterns must survive
#   a rename run so they can detect true residuals. If the patterns lived
#   inline in `ci-scheduled.yml` (which IS in the rename allowlist), the
#   rename's `s|steamdeck-webdev-template|<NEW>|g` pass would rewrite the
#   patterns themselves, leaving the scan looking for the wrong strings
#   and silently missing real residuals while falsely flagging the
#   workflow file's own test-invocation lines.
#
# WHEN TO UPDATE THE EXCLUDE REGEX:
#   - A new file deliberately keeps a template reference (e.g. it
#     documents the upstream template's GitHub URL for forks tracking
#     it). Add it to EXCLUDE — the scan would otherwise flag it forever.
#   - A new file accidentally contains a template reference: do NOT
#     add to EXCLUDE; instead, add it to the appropriate sed pass in
#     `scripts/rename-template.sh` so forks get a clean rename.

set -euo pipefail

EXCLUDE='^(CHANGELOG\.md|\.ai-attribution\.jsonl|docs/SECURITY-AUDIT-v1\.0\.0|scripts/rename-template\.sh|scripts/scan-template-residuals\.sh|docs/FORK\.md|docs/UPGRADE\.md)'

REMAINING=$(git ls-files | grep -vE "$EXCLUDE" | xargs grep -l 'steamdeck-webdev-template\|@mcb/\|victorvinci' 2>/dev/null || true)

if [ -n "$REMAINING" ]; then
    echo "::error::Residual template strings after rename in:" >&2
    echo "$REMAINING" >&2
    echo "" >&2
    echo "These files contain 'steamdeck-webdev-template', '@mcb/', or 'victorvinci'" >&2
    echo "but are NOT in scripts/rename-template.sh's allowlist for any sed pass" >&2
    echo "and NOT in this script's EXCLUDE regex. Either add them to the" >&2
    echo "appropriate sed pass, or — if they're intentionally untouched" >&2
    echo "(point-in-time records, upstream URL references) — add them to the" >&2
    echo "EXCLUDE regex at the top of scripts/scan-template-residuals.sh." >&2
    exit 1
fi
echo "OK — no residual template strings in checked-in files."
