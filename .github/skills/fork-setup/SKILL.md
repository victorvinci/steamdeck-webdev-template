---
name: fork-setup
description: Onboard a fresh fork of this template — rename the project and walk the one-time GitHub/service setup. USE WHEN the user says "set up my fork", "onboard this fork", "rename the template", "make this my own project", "I just forked this", or is starting a new project from the template. Drives scripts/rename-template.sh plus the docs/FORK.md checklist.
---

# Set up a fork

`docs/FORK.md` is the source of truth for fork onboarding. This skill drives the
mechanical rename and then walks the manual GitHub/service steps that can't be
scripted.

## User instructions

$ARGUMENTS

Collect up front: the new **project name**, the new **GitHub owner/org**, the
new **npm scope** (replaces `@mcb`), and the maintainer **email** — the rename
needs all of them.

## Steps

1. **Rename.** Run `scripts/rename-template.sh` with the new identifiers (see
   `docs/FORK.md` for exact flags). It rewrites the project name, npm scope,
   owner, and maintainer email across the tree via dynamic `git grep`
   discovery. It runs `npm run format` + `npm run check` at the end unless you
   pass `--skip-check`.
2. **Verify no residue.** Run `bash scripts/scan-template-residuals.sh` — it
   shares the rename script's exclude set, so a clean scan means the rename hit
   exactly the files the scanner checks. Commit the rename (including the
   `package-lock.json` `name`-field changes — see the TROUBLESHOOTING entry on
   the "dirty lockfile after rename", that change is correct).
3. **Walk `docs/FORK.md`'s manual steps** (these are GitHub/dashboard-side and
   not in any file): branch **rulesets** (`develop`, `main`, `release-tags` —
   the release flow depends on them; recreate per the table in
   `docs/RELEASE.md`), **GitHub Pages** source, **Nx Cloud** (`NX_CLOUD_ACCESS_TOKEN`
   secret + `NX_CLOUD_ENABLED` variable), the **Renovate** app, and **commit
   signing** (the rulesets require `Verified` commits).
4. **Solo-maintainer trap.** If this is a solo fork, the `main` ruleset's
   `require_code_owner_review` + the catch-all `CODEOWNERS.txt` will block every
   merge — add yourself to the ruleset's bypass list (or drop the rule). See
   `docs/FORK.md` → "Solo-maintainer trap".
5. **Decide what to strip.** A fork doesn't need the template's demo `/api/users`
   slice, the `users` table migration, the live-demo URLs, or the
   `scripts/steamdeck/` host helpers. `docs/FORK.md` lists what's safe to remove
   once the template has served its purpose.
6. **Confirm green.** `npm run check` on the renamed tree; bootstrap the DB
   (`npm run setup`) and `npm run dev` to confirm the app runs end-to-end.

## Notes

- Don't blanket-`git merge upstream/main` after renaming — every rename-touched
  file conflicts. To pull later template improvements, use `docs/UPGRADE.md`
  (cherry-pick by SHA or replay from CHANGELOG), not a merge.
