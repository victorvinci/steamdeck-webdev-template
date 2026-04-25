# Contributing

Thanks for considering a contribution — this project is meant to be easy to fork and easy to hack on. A few conventions keep it that way.

## Getting set up

```bash
git clone git@github.com:victorvinci/steamdeck-webdev-template.git
cd steamdeck-webdev-template
npm install
npm run setup        # creates .env, starts MySQL (docker compose, or native mysqld fallback)
npm run dev          # runs frontend + backend in parallel
```

See [`README.md`](./README.md) for manual (non-Docker) setup.

## Branches and commits

- Branch off `develop`: `git checkout -b feat/<short-name>` or `fix/<short-name>`.
- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.
- Keep commits focused — one logical change per commit beats one giant squash.

## Before you open a PR

All of these must pass locally:

```bash
npm run check   # format:check + lint + typecheck + test, in one go
```

Additional expectations:

- **Every new frontend component needs a Storybook story** (`*.stories.tsx`, co-located) covering at least the default state plus any meaningful variants.
- **Every new backend route needs integration coverage** in `apps/backend-e2e` — happy path plus at least one validation failure.
- **Pure backend helpers should ship unit tests next to source.** Middleware, error classes, and services that don't need a DB belong in Jest specs co-located with their source (e.g. `apps/backend/src/middleware/validate.spec.ts`). Integration tests are for wiring; unit tests are for branches. Do both when both apply.
- **Shared types and Zod schemas live in `libs/types`.** Never duplicate a request/response type across the frontend and backend.
- **Database schema changes go through `db/migrations/`.** Add a new numbered SQL file, append it to `db/schema.sql`, and run `npm run migrate`. See [Database](./README.md#database) for the full workflow.
- **Update `CHANGELOG.md`** under `## [Unreleased]` with a one-line entry describing user-facing impact. Use Keep-a-Changelog section headings (`Added`, `Changed`, `Fixed`, `Removed`, `Security`).
- **Never commit `.env`** or anything else containing secrets.

## Signing your commits

Commits landing on `develop` and `main` must be signed. The branch rulesets require `Verified` on every commit, and unsigned commits are rejected at push/merge time.

If you haven't set up signing on this machine yet:

- **SSH key (simplest if you already push over SSH):** follow GitHub's [Telling Git about your signing key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key) → "SSH" tab, then set `git config --global commit.gpgsign true` and `git config --global gpg.format ssh`. Upload the **same** SSH key under Settings → SSH and GPG keys → "New SSH key" with key type **Signing Key** (separate from the Authentication Key GitHub already trusts).
- **GPG key (if your team already uses GPG):** same doc, "GPG" tab. Upload the public key under Settings → SSH and GPG keys → "New GPG key".

Verify locally with `git log --show-signature -1` on your most recent commit — you should see `Good signature from ...`. Verify on GitHub by looking for the green **Verified** badge on the commit after pushing.

AI-authored commits created by Claude Code (and similar assistants) sign with the contributor's configured key — the tool inherits the local `commit.gpgsign` setting, so enabling signing once covers human and AI commits alike.

## AI-assisted contributions

This repo tracks AI-written code in [`CLAUDE.md`](./CLAUDE.md) and [`.ai-attribution.jsonl`](./.ai-attribution.jsonl). If you use an AI assistant to write or edit code in this repo, append one JSON line to the attribution log per the schema in `CLAUDE.md`, and make sure the `CHANGELOG.md` rule above is followed — the agent instructions under `.claude/agents/` already enforce this, but the rule applies to human contributors too.

When committing AI-assisted work, follow the **two-commit flow** documented in [`CLAUDE.md` → "Two-commit flow (MANDATORY when committing)"](./CLAUDE.md#ai-attribution-rule-important): one work commit (code + `CHANGELOG.md`, no JSONL touch) followed by a separate attribution commit (only `.ai-attribution.jsonl`). Push both together so CI runs once on the bundle. The split keeps the work commit's diff readable for reviewers without losing the audit-log entry, and the doc explains why `git commit --amend` is the wrong tool here.

## Pull requests

- Open the PR against `develop` (the integration branch). `main` is the release branch — PRs land there only via `develop → main` merges.
- Fill in the description with **what** changed and **why**. The CHANGELOG entry is not a substitute.
- Tag reviewers once CI is green.

See [`docs/RELEASE.md`](./docs/RELEASE.md) for the full release flow (version bump, `develop → main` PR, tagging, GitHub Release, post-release sync).

Breaking changes to any of the public surfaces listed in [`docs/SEMVER.md`](./docs/SEMVER.md) require a **major** version bump. When unsure, err on the side of calling it a major — the doc has the explicit trigger list.

## Reporting security issues

**Please do not open public issues for security vulnerabilities.** Email the maintainer privately (see [`SECURITY.md`](./SECURITY.md)) so the fix can ship before the details are public.

## Code of Conduct

Participation in this project is governed by the [Code of Conduct](./CODE_OF_CONDUCT.md). Report concerns privately per the contacts listed there.
