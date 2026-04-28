# Release workflow

How we cut a version of `steamdeck-webdev-template`. The workflow encodes the branch model enforced by the `develop` and `main` rulesets plus the `release-tags` ruleset, and is designed to work alongside the two-commit AI-attribution flow documented in `CLAUDE.md`.

## Branch model

```text
feature/* ──▶ develop ──▶ main ──▶ tag X.Y.Z
  (squash)     (rebase)      (annotated tag)
```

- **`develop`** — integration branch. Feature and chore PRs squash-merge here. One squashed commit per PR keeps `git log develop` readable as a list of features.
- **`main`** — release branch. Only `develop → main` PRs land here, via rebase-merge, so each develop commit replays onto main with linear history.
- **`refs/tags/[0-9]*`** — annotated release tags cut on `main` (numeric SemVer, no leading `v`). Protected by the `release-tags` ruleset (no delete, no move, no force-push) once pushed.

## Rulesets relevant to releases

Summary of what's enforced; see the GitHub repo rulesets page for the authoritative source.

| Ruleset        | Target               | Approvals | Merge method | Other                                                                    |
| -------------- | -------------------- | --------- | ------------ | ------------------------------------------------------------------------ |
| `develop`      | `refs/heads/develop` | 0         | squash       | linear history, signed commits, `ci pass` required                       |
| `main`         | `refs/heads/main`    | 1         | rebase       | signed commits, CODEOWNERS, `require_last_push_approval`, `update` block |
| `release-tags` | `refs/tags/[0-9]*`   | —         | —            | block delete, update, non-fast-forward                                   |

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
git switch -c chore/bump-X.Y.Z
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

Append one JSONL line to `.ai-attribution.jsonl`. The schema lives in `CLAUDE.md`; use scope `release-X.Y.Z`.

```sh
cat >> .ai-attribution.jsonl <<'JSON'
{"date":"YYYY-MM-DD","model":"claude-<model-id>","scope":"release-X.Y.Z","description":"Bumped version to X.Y.Z and promoted CHANGELOG.","files":["package.json","package-lock.json","CHANGELOG.md"]}
JSON
git add .ai-attribution.jsonl
git commit -m "chore(attribution): log release-X.Y.Z

Co-Authored-By: claude-<model-id>"
```

One line per entry — the file is in `.prettierignore` and must stay un-reformatted. The `Co-Authored-By` trailer on the work commit is the durable audit signal; the JSONL entry carries the structured metadata (`scope`, `description`, `files`). No commit SHA is captured because squash- and rebase-merges rewrite it — see `CLAUDE.md` for the full rationale.

### 6. PR 1 — `chore/bump-X.Y.Z` → `develop`

```sh
git push -u origin chore/bump-X.Y.Z
gh pr create --base develop --title "chore(release): bump version to X.Y.Z" --template bump.md
```

`--template bump.md` loads `.github/PULL_REQUEST_TEMPLATE/bump.md`, which enumerates the bump-specific checks (no dep drift, CHANGELOG promoted, attribution appended). Fill in the `X.Y.Z` placeholders and tick the boxes as you go.

Wait for `ci pass` to complete, then squash-merge via the GitHub UI (the only merge method develop allows). The squash rewrites the work commit's SHA — that's why the schema no longer carries a `commit` field. The `Co-Authored-By` trailer travels into the squashed commit message, and the pre-squash history is preserved under the PR's "Commits" tab for reference.

### 7. PR 2 — `develop` → `main`

```sh
git switch develop && git pull --ff-only origin develop
gh pr create --base main --head develop --title "chore(release): X.Y.Z" --template release.md
```

`--template release.md` loads `.github/PULL_REQUEST_TEMPLATE/release.md`, which covers the pre-merge checks, the rebase-merge note, and the post-merge tag/release/sync reminders. Fill in the `X.Y.Z` placeholders and tick the boxes as you go.

Wait for CI on this PR, then **Merge (rebase)** through the GitHub UI. Use the admin bypass prompt if you're the only maintainer. Each commit from develop replays onto main with a new SHA.

### 8. Tag and release

```sh
git switch main
git pull --ff-only origin main
git tag -a X.Y.Z -m "X.Y.Z"
git push origin X.Y.Z
```

The `release-tags` ruleset activates on push — from now on the tag can't be deleted or moved without admin bypass.

The tag push triggers [`.github/workflows/release.yml`](../.github/workflows/release.yml), which creates the GitHub Release automatically: it extracts the `## [X.Y.Z]` section from `CHANGELOG.md` via `scripts/extract-changelog-section.sh`, generates a CycloneDX SBOM, mints a SLSA build-provenance attestation for that SBOM via `actions/attest-build-provenance`, and publishes the release with the SBOM attached as an asset. No manual `gh release create` needed.

Consumers who want to verify the SBOM came from this repo's release pipeline (and not, say, a tampered mirror) can run:

```sh
gh attestation verify sbom.cdx.json --repo <owner>/<repo>
```

The attestation is keyed to the workflow's OIDC identity, so it proves the SBOM was produced by `.github/workflows/release.yml` running against a tag on `main` — anyone who tampers with the SBOM after the fact will fail the verify.

If the workflow fails (e.g. the CHANGELOG wasn't promoted before tagging and the fallback to auto-generated notes isn't what you want), you can re-run it from the Actions tab or publish manually:

```sh
./scripts/extract-changelog-section.sh X.Y.Z | gh release create X.Y.Z --title "X.Y.Z" --notes-file -
```

The script prints the content between `## [X.Y.Z]` and the next `## [` header — the section body only, without the header itself, which `gh release create` renders separately via `--title`.

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
3. PR `hotfix/<slug>` → `main` using the hotfix template (`gh pr create --base main --template hotfix.md`), rebase-merge via admin bypass.
4. Tag `X.Y.(Z+1)` and release.
5. Sync the fix into `develop` via a **cherry-pick PR** — not a merge. `develop`'s `required_linear_history` rule rejects merge commits, and `develop` will normally have diverged during the hotfix, so the release-PR fast-forward trick (`push origin/main:develop`) would discard develop's un-merged work. Use the cherry-pick flow instead:

    ```sh
    git switch develop && git pull --ff-only origin develop
    git switch -c hotfix-sync/<slug>
    # Identify the hotfix commit(s) landed on main. Usually one rebased commit.
    git log main --not develop --oneline
    # Cherry-pick each hotfix commit from main. Resolve CHANGELOG-section
    # conflicts by keeping develop's existing [Unreleased] section and
    # appending the hotfix bullet under it (the [X.Y.(Z+1)] header lives
    # on main only).
    git cherry-pick <hotfix-sha>
    git push -u origin hotfix-sync/<slug>
    gh pr create --base develop --template hotfix-sync.md
    ```

    The sync PR squash-merges into develop like any other feature PR. Open it immediately after the tag is pushed so the CHANGELOG and code stay aligned across branches. If the cherry-pick conflicts can't be resolved cleanly (large rewrites landed on develop since the hotfix branched), fall back to re-applying the fix by hand on a fresh branch off develop — whichever path is used, the sync PR template applies.

## Things this flow deliberately avoids

- **`npm install` during bump.** Drags in incidental dep updates and muddies the release diff. Use `npm version`.
- **Pre-merge deployment gates on `main`.** The old `required_deployments: ["main"]` rule created a chicken-and-egg with the post-merge `pages.yml` deploy. Removed so merging into main works cleanly; the deployment still runs post-merge, just no longer as a pre-merge gate.
- **Squash or rebase on release tags.** Tags are immutable by policy — the `release-tags` ruleset blocks delete and update so a pushed `X.Y.Z` always points at exactly one commit.
- **`npm version X.Y.Z` without `--no-git-tag-version`.** The default creates a commit and tag you don't want yet; you want the tag on `main` post-merge, not on the feature branch.

## Operational levers

- **`NX_CLOUD_ENABLED` (repo variable).** Kill switch for Nx Cloud, wired into `ci.yml`, `ci-scheduled.yml`, and `pages.yml`. Flip to `false` if Nx Cloud is having an outage (e.g. free-plan quota exhaustion) and CI is stuck — the pipeline falls back to the local filesystem cache and keeps gating PRs without needing a code change. Full setup, semantics, and the quota-failure-mode explanation live in [README → Nx Cloud configuration](../README.md#nx-cloud-configuration); don't duplicate the details here.
