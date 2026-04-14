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

- Branch off `main`: `git checkout -b feat/<short-name>` or `fix/<short-name>`.
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
- **Shared types and Zod schemas live in `libs/types`.** Never duplicate a request/response type across the frontend and backend.
- **Update `CHANGELOG.md`** under `## [Unreleased]` with a one-line entry describing user-facing impact. Use Keep-a-Changelog section headings (`Added`, `Changed`, `Fixed`, `Removed`, `Security`).
- **Never commit `.env`** or anything else containing secrets.

## AI-assisted contributions

This repo tracks AI-written code in [`CLAUDE.md`](./CLAUDE.md) and [`.ai-attribution.jsonl`](./.ai-attribution.jsonl). If you use an AI assistant to write or edit code in this repo, append one JSON line to the attribution log per the schema in `CLAUDE.md`, and make sure the `CHANGELOG.md` rule above is followed — the agent instructions under `.claude/agents/` already enforce this, but the rule applies to human contributors too.

## Pull requests

- Open the PR against `main`.
- Fill in the description with **what** changed and **why**. The CHANGELOG entry is not a substitute.
- Tag reviewers once CI is green.

## Reporting security issues

**Please do not open public issues for security vulnerabilities.** Email the maintainer privately (see [`SECURITY.md`](./SECURITY.md)) so the fix can ship before the details are public.
