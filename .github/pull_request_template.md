<!--
  This is the default PR template. For release-flow PRs, use a selectable one:
    - bump.md        — chore/bump-vX.Y.Z  → develop
    - release.md     — develop            → main
    - hotfix.md      — hotfix/<slug>      → main
    - hotfix-sync.md — hotfix-sync/<slug> → develop (cherry-pick post-tag)
  Usage: `gh pr create --template <name>.md`
         or append `?template=<name>.md` to the compare URL.
  See docs/RELEASE.md for the full flow.
-->

## Summary

<!-- What does this PR do and why? 1-3 bullet points. -->

-

## Test plan

<!-- How did you verify this works? Check all that apply. -->

- [ ] `npm run check` passes (format, lint, typecheck, tests)
- [ ] Tested locally in the browser (if UI change)
- [ ] Storybook stories added or updated to cover the change (mandatory for any new or changed frontend component — see `CLAUDE.md`)
- [ ] e2e tests pass (`npm run e2e`)
- [ ] `CHANGELOG.md` updated under `## [Unreleased]`
- [ ] Docs touched if user-facing behaviour changed (`README.md`, `docs/`, or `docs/TROUBLESHOOTING.md` for fork-onboarding gotchas)
- [ ] `.ai-attribution.jsonl` appended if AI-assisted (see `CLAUDE.md` schema)

## Notes

<!-- Anything reviewers should know: trade-offs, follow-ups, related issues. Delete if empty. -->
