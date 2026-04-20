<!--
  Title format: `hotfix: <short description>` (or `fix: <description>` if you prefer)
  Hotfix PRs branch from `main`, rebase-merge into `main`, and skip
  `develop`. A cherry-pick sync PR into `develop` is required post-tag
  (not a merge — develop's linear_history rule rejects merge commits).
  See `docs/RELEASE.md` → "Hotfix flow" and use `hotfix-sync.md` for the
  follow-up sync PR.

  Use via: `gh pr create --template hotfix.md` or append `?template=hotfix.md`
  to the compare URL.
-->

## Summary

<!-- What's the bug, why can it not wait for the normal release cadence? -->

-

## Fix

<!-- What changed and why this is the minimal safe fix. Link the issue/incident. -->

-

## Pre-merge checklist

- [ ] Branch cut from `main` (not `develop`) as `hotfix/<slug>`
- [ ] Fix is minimal — no opportunistic refactors or unrelated changes
- [ ] `CHANGELOG.md` updated under `## [Unreleased]` with the hotfix entry
- [ ] `.ai-attribution.jsonl` appended if AI-assisted (see `CLAUDE.md` schema)
- [ ] Tests added or existing coverage demonstrably exercises the fix path
- [ ] `ci pass` green on this PR

## Merge

- [ ] Merged via **Rebase and merge** (the only method the `main` ruleset allows)
- [ ] Admin bypass used if solo-merging (main requires 1 CODEOWNERS approval by default)

## Post-merge actions

<!-- Complete these immediately after the rebase-merge lands. -->

- [ ] Patch version bumped on `main` and tag pushed: `git tag -a vX.Y.(Z+1) -m "vX.Y.(Z+1)" && git push origin vX.Y.(Z+1)`
- [ ] GitHub Release published (notes sourced from the `[Unreleased]` hotfix entry, which should then be promoted)
- [ ] Hotfix synced into `develop` via a cherry-pick PR using `hotfix-sync.md` — open it immediately after the tag is pushed. See `docs/RELEASE.md` → "Hotfix flow" step 5 for the full recipe.
