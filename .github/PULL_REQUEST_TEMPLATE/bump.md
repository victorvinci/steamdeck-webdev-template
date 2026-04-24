<!--
  Title format: `chore(release): bump version to X.Y.Z`
  This PR squash-merges into `develop` and is the prerequisite for the
  `develop → main` release PR. See `docs/RELEASE.md` steps 2–6.

  Use via: `gh pr create --template bump.md` or append `?template=bump.md`
  to the compare URL.
-->

## Summary

- Bumps version to `X.Y.Z`
- Promotes `## [Unreleased]` → `## [X.Y.Z] - YYYY-MM-DD` in `CHANGELOG.md` (leaves a fresh empty `## [Unreleased]` above it)

## Test plan

- [ ] `npm version X.Y.Z --no-git-tag-version` used (no dependency re-resolution)
- [ ] Diff limited to `package.json`, both `package-lock.json` version fields, and `CHANGELOG.md`
- [ ] Empty `## [Unreleased]` left above `## [X.Y.Z] - YYYY-MM-DD`
- [ ] `.ai-attribution.jsonl` appended with `scope: release-vX.Y.Z` (if AI-assisted)
- [ ] `ci pass` green on this PR

## Notes

<!-- Anything reviewers should know: deferred items, follow-ups after the release lands, etc. Delete if empty. -->
