---
name: release
description: Cut a versioned release (develop → main → tag) following docs/RELEASE.md. USE WHEN the user says "cut a release", "release X.Y.Z", "ship a version", "do the release", "bump and release", or asks to publish a new version. Drives the full bump → develop PR → main PR → tag → post-release-sync flow with mandatory human gates before anything irreversible.
---

# Cut a release

Orchestrates the `develop → main → tag` release for this template.

**`docs/RELEASE.md` is the source of truth.** This skill is the executable
layer on top of it — if the two ever disagree, RELEASE.md wins and this file
should be corrected. Read the matching RELEASE.md step before each phase; do
not re-derive the branch model from memory.

## Current state

- **Branch:** !`git branch --show-current`
- **Version:** !`node -e "console.log(require('./package.json').version)"`

## User instructions

$ARGUMENTS

If the user names a version, use it. Otherwise propose one from the
`[Unreleased]` CHANGELOG content and the SemVer policy in `docs/SEMVER.md`
(when in doubt, that doc says err toward major).

## Hard gates (do NOT cross without explicit user confirmation)

1. **Pushing the tag** (step 8). The tag push triggers `release.yml`, which
   publishes a **public** GitHub Release. The `release-tags` ruleset makes the
   tag **immutable** — it cannot be moved or deleted afterward. STOP and get an
   explicit "go" before `git push origin <X.Y.Z>`.
2. **The `develop → main` rebase-merge** and the **post-release force-push to
   develop** both require **admin bypass**. Surface them explicitly; never
   present a bypass as routine.

If running unattended, stop at gate 1 and hand the exact tag commands to the
human. Everything before gate 1 is reversible; the tag is not.

## Preconditions (verify first)

- `develop` CI is green and you are at `origin/develop` (`git fetch` then
  `git reset --hard origin/develop` on a clean tree).
- `CHANGELOG.md` has a populated `## [Unreleased]` section.
- The release milestone has **no open** issues/PRs
  (`gh pr list --search "milestone:vX.Y.Z state:open"`).
- You (or the user) are a repo admin — the main merge and sync need bypass.

## Steps

Follow `docs/RELEASE.md` steps 1–9. Summary with this repo's specifics:

1. **Branch:** `git switch -c chore/bump-X.Y.Z` off develop.
2. **Bump:** `npm version X.Y.Z --no-git-tag-version` (edits `package.json` +
   both `package-lock.json` version fields, nothing else). **Never** `npm
install` here — it drags in incidental dep bumps.
3. **Promote CHANGELOG:** rename `## [Unreleased]` → `## [X.Y.Z] - YYYY-MM-DD`
   (use the user's local date — see CLAUDE.md memory on dates) and leave a fresh
   empty `## [Unreleased]` above it. Verify with
   `./scripts/extract-changelog-section.sh X.Y.Z` — `release.yml` uses this
   exact output for the release notes.
4. **Work commit:** stage everything **except** `.ai-attribution.jsonl`
   (`package.json`, `package-lock.json`, `CHANGELOG.md`). Message
   `chore(release): bump version to X.Y.Z` with a `Co-Authored-By:` trailer.
5. **Attribution commit:** append one JSONL line with `scope: release-X.Y.Z`,
   then commit just `.ai-attribution.jsonl`.
6. **PR to develop:** push, then
   `gh pr create --base develop --milestone "vX.Y.Z" --title "chore(release):
bump version to X.Y.Z"` with the **filled** `bump.md` template as the body
   (substitute the `X.Y.Z`/date placeholders; don't pass raw `--template`).
   Attach the milestone **at create** (memory: `feedback_pr_milestone_at_create`).
7. **Wait for CI, then merge:** GitHub force-drafts new PRs (`force-draft.yml`),
   so the heavy jobs only run after the PR is marked ready — `gh pr ready` it,
   watch the **latest** run (not the first), confirm `ci pass` **and CodeQL**
   are green (CodeQL runs because the bump touches `package.json`), then
   squash-merge to develop.
8. **`develop → main` PR:** `gh pr create --base main --head develop --title
"chore(release): X.Y.Z"` with the filled `release.md` template. Wait for CI,
   then **Merge (rebase)** — admin bypass (gate 2).
9. **Tag (GATE 1 — confirm first):**
    ```sh
    git switch main && git pull --ff-only origin main
    git tag -a X.Y.Z -m "X.Y.Z"   # numeric, NO leading v
    git push origin X.Y.Z          # ← publishes the release; immutable
    ```
    Then watch `release.yml`; if it falls back to auto-notes unexpectedly, see
    RELEASE.md step 8's manual `gh release create` recovery.
10. **Post-release sync (step 9, admin bypass — gate 2):**
    `git push origin origin/main:develop --force-with-lease`, then locally
    `git switch develop && git fetch origin && git reset --hard origin/develop`.

## Conflict handling

`.ai-attribution.jsonl` and `CHANGELOG.md` conflict often when other PRs merged
during the release. For `.ai-attribution.jsonl`, **keep both lines** (never pick
one — CLAUDE.md rule). For `CHANGELOG.md`, keep both entries and collapse
duplicate `### Added/Changed/...` subsections into one.
