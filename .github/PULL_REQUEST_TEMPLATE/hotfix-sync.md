<!--
  Title format: `chore: sync hotfix vX.Y.(Z+1) into develop`
  Cherry-picks a hotfix from main into develop so the fix isn't lost
  on the next release. Open this PR immediately after the hotfix tag
  is pushed. See docs/RELEASE.md → "Hotfix flow" step 5 for the full
  recipe (including why a merge commit isn't an option).

  Use via: `gh pr create --template hotfix-sync.md` or append
  `?template=hotfix-sync.md` to the compare URL.
-->

## Summary

Syncs hotfix `vX.Y.(Z+1)` from `main` into `develop` via cherry-pick.

- Hotfix PR: #
- Hotfix commit(s) on `main`:
- Tag: `vX.Y.(Z+1)` (already pushed)

## Pre-merge checklist

- [ ] Branch cut from `develop` (not `main`) as `hotfix-sync/<slug>`
- [ ] Hotfix commit(s) identified via `git log main --not develop --oneline` and cherry-picked in order
- [ ] Cherry-pick applied cleanly, or conflicts resolved (see Notes below)
- [ ] `CHANGELOG.md` bullet lives under develop's `## [Unreleased]` section (the `[X.Y.(Z+1)]` header is main-only)
- [ ] No new `.ai-attribution.jsonl` entry needed — the original hotfix entry travels with the cherry-picked commit. Add a new entry **only** if this PR required non-trivial manual work beyond the cherry-pick itself.
- [ ] `ci pass` green on this PR

## Notes

<!-- Conflicts resolved, CHANGELOG reconciliation, any deviation from a plain cherry-pick. Delete if trivial. -->
