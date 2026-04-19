# Release workflow

How we cut a version of `steamdeck-webdev-template`. The workflow encodes the branch model enforced by the `develop` and `main` rulesets plus the `release-tags` ruleset, and is designed to work alongside the two-commit AI-attribution flow documented in `CLAUDE.md`.

## Branch model

```
feature/* ──▶ develop ──▶ main ──▶ tag vX.Y.Z
  (squash)     (rebase)      (annotated tag)
```

- **`develop`** — integration branch. Feature and chore PRs squash-merge here. One squashed commit per PR keeps `git log develop` readable as a list of features.
- **`main`** — release branch. Only `develop → main` PRs land here, via rebase-merge, so each develop commit replays onto main with linear history.
- **`refs/tags/v*`** — annotated release tags cut on `main`. Protected by the `release-tags` ruleset (no delete, no move, no force-push) once pushed.

## Rulesets relevant to releases

Summary of what's enforced; see the GitHub repo rulesets page for the authoritative source.

| Ruleset        | Target               | Approvals | Merge method | Other                                                    |
| -------------- | -------------------- | --------- | ------------ | -------------------------------------------------------- |
| `develop`      | `refs/heads/develop` | 0         | squash       | linear history, `ci pass` required                       |
| `main`         | `refs/heads/main`    | 1         | rebase       | CODEOWNERS, `require_last_push_approval`, `update` block |
| `release-tags` | `refs/tags/v*`       | —         | —            | block delete, update, non-fast-forward                   |

The `Convert PR to Draft` workflow still runs on freshly opened PRs (saving CI minutes until the author marks ready), but is **not** a required status check — it's a one-shot side-effect on `opened`, so making it a gate would leave new commits blocked by an unsatisfiable pending check.

The `main` ruleset grants repo admins `bypass_mode: always`, which is how a solo maintainer can merge the `develop → main` PR without a second reviewer. Bypass is an explicit choice — click **Merge anyway** on the PR, not a habit.

## Prerequisites

Before starting a release, confirm:

1. `develop` CI is green.
2. `CHANGELOG.md` has an `## [Unreleased]` section describing what will ship.
3. No open PRs targeting `develop` that should have made it into this release.
4. You're a repo admin (or have a second reviewer lined up) for the `develop → main` merge.

## Step-by-step

All commands assume you start from a clean `develop` checkout:

```sh
git switch develop
git pull --ff-only origin develop
```

### 1. Branch

```sh
git switch -c chore/bump-vX.Y.Z
```

Use `chore/bump-<version>` consistently so the purpose is obvious in the PR list.

### 2. Bump the version

Use npm's built-in bump — it edits `package.json` and both `version` fields in `package-lock.json`, and does nothing else. No dependency drift, no auto-commit, no auto-tag.

```sh
npm version X.Y.Z --no-git-tag-version
```

Do **not** use `npm install` as a way to sync the lockfile — that re-resolves the whole dependency graph against the registry and will drag incidental bumps into what should be a pure version-bump PR.

### 3. Promote `CHANGELOG.md`

Rename the `## [Unreleased]` header to `## [X.Y.Z] - YYYY-MM-DD`, and insert a fresh empty `## [Unreleased]` above it. The empty `[Unreleased]` gives the next PR a place to land without conflicts.

Before:

```markdown
## [Unreleased]

### Fixed

- **Fixed** …
```

After:

```markdown
## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD

### Fixed

- **Fixed** …
```

### 4. Work commit

Stage everything **except** `.ai-attribution.jsonl`:

```sh
git add package.json package-lock.json CHANGELOG.md docs/RELEASE.md # + anything else touched
git commit -m "chore(release): bump version to X.Y.Z

Co-Authored-By: claude-<model-id>"
```

The `Co-Authored-By` trailer is mandatory for AI-authored commits (see `CLAUDE.md`). Use the runtime model ID, not a guess.

### 5. Attribution commit

Append one JSONL line to `.ai-attribution.jsonl`. The schema lives in `CLAUDE.md`; use scope `release-vX.Y.Z`.

```sh
cat >> .ai-attribution.jsonl <<'JSON'
{"date":"YYYY-MM-DD","model":"claude-<model-id>","scope":"release-vX.Y.Z","description":"Bumped version to X.Y.Z and promoted CHANGELOG.","files":["package.json","package-lock.json","CHANGELOG.md"]}
JSON
git add .ai-attribution.jsonl
git commit -m "chore(attribution): log release-vX.Y.Z

Co-Authored-By: claude-<model-id>"
```

One line per entry — the file is in `.prettierignore` and must stay un-reformatted. The `Co-Authored-By` trailer on the work commit is the durable audit signal; the JSONL entry carries the structured metadata (`scope`, `description`, `files`). No commit SHA is captured because squash- and rebase-merges rewrite it — see `CLAUDE.md` for the full rationale.

### 6. PR 1 — `chore/bump-vX.Y.Z` → `develop`

```sh
git push -u origin chore/bump-vX.Y.Z
gh pr create --base develop --title "chore(release): bump version to X.Y.Z" --body "$(cat <<'EOF'
## Summary

- Bumps version to X.Y.Z
- Promotes `## [Unreleased]` → `## [X.Y.Z]` in CHANGELOG

## Test plan

- [x] `npm version` diff is limited to version fields
- [x] CI green
EOF
)"
```

Wait for `ci pass` to complete, then squash-merge via the GitHub UI (the only merge method develop allows). The squash rewrites the work commit's SHA — that's why the schema no longer carries a `commit` field. The `Co-Authored-By` trailer travels into the squashed commit message, and the pre-squash history is preserved under the PR's "Commits" tab for reference.

### 7. PR 2 — `develop` → `main`

```sh
git switch develop && git pull --ff-only origin develop
gh pr create --base main --head develop --title "release: vX.Y.Z" --body "$(cat <<'EOF'
## Summary

Release vX.Y.Z — see `CHANGELOG.md` for the full changelist.

## Test plan

- [x] CI green on develop
- [x] Admin-bypass merge (main ruleset requires 1 approval; solo releases use the admin bypass granted by the ruleset)
EOF
)"
```

Wait for CI on this PR, then **Merge (rebase)** through the GitHub UI. Use the admin bypass prompt if you're the only maintainer. Each commit from develop replays onto main with a new SHA.

### 8. Tag and release

```sh
git switch main
git pull --ff-only origin main
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

The `release-tags` ruleset activates on push — from now on the tag can't be deleted or moved without admin bypass.

Publish the GitHub Release, auto-sourcing notes from the CHANGELOG section you just promoted:

```sh
awk -v ver="X.Y.Z" '
  $0 ~ "^## \\[" ver "\\]" { grab = 1; next }
  grab && /^## \[/          { exit }
  grab                      { print }
' CHANGELOG.md | gh release create vX.Y.Z --title "vX.Y.Z" --notes-file -
```

The `awk` extracts the content between `## [X.Y.Z]` and the next `## [` header — the section body only, without the header itself, which `gh release create` renders separately via `--title`.

### 9. Post-release sync

After step 7, `main` has rebased copies of each develop commit (new SHAs). Left alone, `develop` stays one commit "behind" `main` forever — the old develop SHAs are unreachable from `main` and vice versa, which GitHub reports as divergence on every subsequent `develop → main` PR.

The fix is to fast-forward `develop` to `main`'s tip, which is a force-update from develop's perspective (since the rebased SHAs are a different chain). Merging `main` into `develop` would work but creates a merge commit, which violates develop's `required_linear_history` rule.

```sh
git fetch origin
git push origin origin/main:develop --force-with-lease
```

This retargets `refs/heads/develop` on the remote to whatever `origin/main` currently points at. `--force-with-lease` makes the push refuse if someone else has pushed to develop since your last fetch — protecting against concurrent work.

The `develop` ruleset blocks force-pushes (`non_fast_forward`), so this push requires admin bypass. It's a deliberate, infrequent action — once per release — not a habit.

Once the push lands, pull locally so your working copy matches:

```sh
git switch develop
git fetch origin
git reset --hard origin/develop
```

## Hotfix flow (for reference)

Not part of the normal release cadence, but when a critical fix must skip develop:

1. Branch from `main` as `hotfix/<slug>`.
2. Fix + CHANGELOG (under `[Unreleased]`) + attribution.
3. PR `hotfix/<slug>` → `main` (rebase, admin bypass).
4. Tag `vX.Y.(Z+1)` and release.
5. Back-merge `main` → `develop` so the fix isn't lost on the next release.

## Things this flow deliberately avoids

- **`npm install` during bump.** Drags in incidental dep updates and muddies the release diff. Use `npm version`.
- **Pre-merge deployment gates on `main`.** The old `required_deployments: ["main"]` rule created a chicken-and-egg with the post-merge `pages.yml` deploy. Removed so merging into main works cleanly; the deployment still runs post-merge, just no longer as a pre-merge gate.
- **Squash or rebase on release tags.** Tags are immutable by policy — the `release-tags` ruleset blocks delete and update so a pushed `vX.Y.Z` always points at exactly one commit.
- **`npm version X.Y.Z` without `--no-git-tag-version`.** The default creates a commit and tag you don't want yet; you want the tag on `main` post-merge, not on the feature branch.
