<!--
  Title format: `release: X.Y.Z`
  This PR rebase-merges `develop` into `main`. See `docs/RELEASE.md` for the
  full workflow (including the post-merge tag, GitHub release, and develop
  fast-forward steps).

  Use via: `gh pr create --template release.md` or append `?template=release.md`
  to the compare URL.
-->

## Summary

Release v`X.Y.Z` — see `CHANGELOG.md` under `## [X.Y.Z]` for the full changelist.

<!-- Optional: 2–3 bullets calling out headline changes for skim-readers. -->

-

## Pre-merge checklist

- [ ] Bump PR (`chore(release): bump version to X.Y.Z`) already squash-merged into `develop`
- [ ] `CHANGELOG.md` on develop has `## [X.Y.Z] - YYYY-MM-DD` promoted above a fresh empty `## [Unreleased]`
- [ ] `package.json` + `package-lock.json` version fields read `X.Y.Z`
- [ ] `ci pass` green on `develop` (and on this PR)
- [ ] No unmerged PRs against `develop` that should have shipped in this release

## Merge

- [ ] Merged via **Rebase and merge** (the only method the `main` ruleset allows)
- [ ] Admin bypass used if solo-merging (main requires 1 CODEOWNERS approval by default)

## Post-merge actions

<!-- Complete these immediately after the rebase-merge lands. Commands in docs/RELEASE.md steps 8–9. -->

- [ ] Tag pushed: `git tag -a X.Y.Z -m "X.Y.Z" && git push origin X.Y.Z`
- [ ] GitHub Release published (notes auto-sourced from the promoted CHANGELOG section)
- [ ] `develop` fast-forwarded to `main` via `git push origin origin/main:develop --force-with-lease` (requires admin bypass on `develop`)
