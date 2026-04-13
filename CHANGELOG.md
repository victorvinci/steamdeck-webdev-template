# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **`.gitlab-ci.yml` — restored missing jobs and fixed broken e2e image.** Re-added `commitlint`, `npm-audit`, `attribution-guard`, and `storybook-build` jobs that had gone missing during earlier edits, and corrected the `e2e` job image from the malformed `://microsoft.com` to `mcr.microsoft.com/playwright:v1.55.0-jammy`.
- **Nx Cloud run fragmentation — single `start-ci-run` per pipeline.** Removed `npx nx-cloud start-ci-run` from the `build` and `e2e` jobs in `.gitlab-ci.yml`; only the `check` job calls it now. Calling it in every job was registering three separate Nx Cloud pipeline executions per push, which fragmented the dashboard and broke commit attribution display.
- **`commitlint` CI job — only lint the MR title.** Previously the job also linted every commit in the MR range, which blocked MRs on pre-existing non-conforming debug commits. Since the merge is squashed to the MR title, title-only validation is sufficient.
- **CI build job — TanStack Router double-generation.** The `build` job was failing on `File apps/frontend/src/routeTree.gen.ts already exists. Cannot overwrite.`, a known issue with the `@tanstack/router-plugin` generator running twice inside a single Vite build. Bumped `@tanstack/react-router` and `@tanstack/router-plugin` to latest (`1.168.19` / `1.167.20`) and added `--no-distribution` to every `npx nx-cloud start-ci-run` invocation in `.gitlab-ci.yml` to silence the ambiguous-distribution warning at the same time.

### Added

- **`npm run check` script in `package.json`** — runs `format:check`, `lint`, `typecheck`, and `test` sequentially so every gate can be verified in one command.
- **`npm run build` script in `package.json`** — runs `check` first, then `nx run-many --target=build --all`, so a build can't succeed with failing gates. `README.md` command table and `CONTRIBUTING.md` pre-PR checklist updated to reference `npm run check`.
- **GitLab CI pipeline** — `.gitlab-ci.yml` (extends the pre-existing stub). Stages: `quality` → `build` → `test` → `e2e` → `report`. Jobs:
    - `check` (format / lint / typecheck / test, uses `nx affected` on MRs and `nx run-many` on default branches, with JUnit artifact upload)
    - `build` (affected-aware; uploads `dist/` artifact)
    - `storybook-build` (enforces stories still compile)
    - `e2e` on the official Playwright image, with `.playwright/` cache and failure-only report upload
    - `lighthouse` (LHCI against `dist/apps/frontend` using `lighthouserc.json`, allow_failure)
    - `commitlint` (MR-only, checks every commit in the range plus the MR title)
    - `npm-audit` (allow_failure, `--audit-level=high --omit=dev`)
    - `attribution-guard` (MR-only; fails MRs that touch `apps/` or `libs/` without updating `CHANGELOG.md`, warns if `.ai-attribution.jsonl` wasn't updated)
- **GitLab security templates included** — `Security/SAST.gitlab-ci.yml`, `Security/Secret-Detection.gitlab-ci.yml` (gitleaks under the hood), and `Security/Dependency-Scanning.gitlab-ci.yml`. Template jobs opt out of the Node `before_script`/cache so they don't try to `npm ci` first.
- **Renovate config** — `renovate.json` with weekly Monday schedule, grouped updates for `@nx/*`, `@storybook/*`, `@tanstack/*`, `@types/*`, `eslint*`, and a dependency dashboard. Replaces the earlier Dependabot draft.
- **Commitlint** — `commitlint.config.js` extending `@commitlint/config-conventional`. Enforced locally by `.husky/commit-msg` and in CI by the `commitlint` job. `@commitlint/cli` + `@commitlint/config-conventional` added to devDependencies.
- **Lighthouse CI config** — `lighthouserc.json` runs against the built frontend static output, enforces a11y ≥ 0.9 (error) and perf/best-practices/SEO ≥ 0.9 (warn), disables HTTPS-only checks that don't apply to static asserts.
- **Nx Cloud hooks** — CI sets `NX_BRANCH` and documents the `NX_CLOUD_ACCESS_TOKEN` variable for remote cache. Distributed task execution (agents) is stubbed in `.gitlab-ci.yml` as opt-in.
- **Husky + lint-staged** — `.husky/pre-commit` runs `lint-staged`; `.lintstagedrc.json` runs `eslint --fix` + `prettier --write` on staged code and explicitly ignores `.ai-attribution.jsonl` so its one-line-per-entry format can't be reformatted. `prepare` script added so `husky` installs hooks on `npm install`.
- **`npm run check:affected` script** — `format:check` + `nx affected -t lint typecheck test` for quick iteration on big branches.
- **Frontend env validation** — `apps/frontend/src/lib/env.ts` parses `import.meta.env` with Zod. `apps/frontend/src/lib/api.ts` now imports from it instead of touching `import.meta.env` directly.
- **Request-id correlation end-to-end** — backend `pino-http` now sets `x-request-id` on the response (`apps/backend/src/main.ts`), CORS exposes the header, and the frontend axios client attaches a client-generated id on outgoing requests and logs the id from the response when a request fails (`apps/frontend/src/lib/api.ts`).

### Changed

- **Docs sweep for new scripts** — `README.md` Production Deployment now uses `npm run build` (with a note on bypassing gates); `CLAUDE.md` commands section lists `npm run check` and `npm run build`.

## [0.1.0] — 2026-04-12

### Added

- **Shared API contract in `libs/types/src/lib/api.ts`** — Zod as single source of truth. `UserSchema`, `ListUsersQuerySchema`, `ListUsersResponseSchema` drive both runtime validation and inferred TS types (`User`, `ListUsersQuery`, `ListUsersResponse`). Also exports `ApiSuccess<T>` / `ApiError` / `ApiResponse<T>` + `isApiError` narrowing helper. `libs/types/README.md` documents the pattern.
- **`libs/utils/src/lib/utils.ts`** — first real shared utilities: `formatError(unknown): string` and typed `isDefined<T>` guard. Spec files cover both.
- **Backend `GET /api/users` endpoint** — `apps/backend/src/routes/users.ts` + `services/users.service.ts`. Uses `validate(ListUsersQuerySchema, 'query')` middleware, typed `RowDataPacket` rows, named placeholder SQL, returns `ApiSuccess<ListUsersResponse>`.
- **`apps/backend/src/errors/AppError.ts`** — `AppError` base class (`statusCode`, `isOperational`) plus `BadRequestError` / `NotFoundError` / `ConflictError` subclasses. Error handler preserves operational status codes and collapses everything else to a generic 500.
- **Pino structured logging** — `apps/backend/src/config/logger.ts` with redaction paths for `authorization`, `cookie`, `password`, `token`. `pino-http` wired in `main.ts` with `genReqId` for request-id correlation; `pino-pretty` in dev only.
- **Graceful shutdown** in `apps/backend/src/main.ts` — SIGTERM/SIGINT drain the HTTP server, close the MySQL pool, and force-exit after 10 s if anything hangs.
- **Frontend users feature** — `apps/frontend/src/lib/api/users.ts` with a `usersKeys` query-key factory and a `useUsersQuery` hook. `apps/frontend/src/components/UsersList.tsx` is a pure presentational component; `UsersList.stories.tsx` covers Default / Empty / SingleUser. `apps/frontend/src/routes/index.tsx` consumes the hook with loading / error / retry states.
- **TS path aliases** `@mcb/types` and `@mcb/utils` in `tsconfig.base.json` (with `baseUrl: "."`) — consumed by both apps via `nxViteTsPaths()` on the frontend and Node16 resolution on the backend.
- **Backend e2e coverage** — `apps/backend-e2e/src/backend/backend.spec.ts` tests `/api/health`, `/api/users` happy path, `/api/users` 400 validation, and 404 on unknown routes.
- **`.editorconfig`**, **`CONTRIBUTING.md`**, and **`SECURITY.md`** at the repo root — contributor-facing docs covering indent/EOL conventions, branch/commit/test workflow, and private vulnerability reporting.
- **Backend serve watch mode** — `apps/backend/project.json` sets `"watch": true` on `serve` so `npm run be` reloads on change.
- **Commit attribution rule** in `CLAUDE.md` and all three agent definitions: every AI-authored commit must carry a `Co-Authored-By: <runtime-model-id> ` trailer so `git log` reveals which model wrote what.
- **`.nvmrc`** pinning Node to `20.12.0` so contributors get the right runtime automatically via `nvm use`.
- **CHANGELOG-update rule for agents.** `CLAUDE.md` now mandates that every AI agent update `CHANGELOG.md` under `[Unreleased]` before reporting a task done — not a suggestion, a blocking requirement. The three agent definitions (`frontend-reviewer`, `backend-api`, `test-writer`) all carry a matching reminder in their instructions. `README.md` documents the rule for human contributors too.
- **CHANGELOG link in `README.md`** just below the tagline so forkers find release history immediately.

### Added

- **`apps/backend/src/config/env.ts`** — Zod-validated environment loader. Backend now refuses to start if any required variable is missing or malformed.
- **`apps/backend/src/middleware/validate.ts`** — reusable Zod validation middleware for `body` / `query` / `params`. Use it on every route that accepts user input.
- **`express-rate-limit`** — global limiter at 100 req/min/IP, configured with `standardHeaders: 'draft-7'`.
- **Helmet CSP** — explicit `default-src`/`script-src` `'self'`, `object-src`/`frame-ancestors` `'none'`, `Cross-Origin-Resource-Policy: same-site`, `Referrer-Policy: no-referrer`.
- **Body size limits** — `express.json({ limit: '100kb' })` and matching `urlencoded` limit.
- **`trust proxy`** — enabled when `NODE_ENV=production` so rate limiting sees real client IPs behind a load balancer.
- **`docker-compose.yml`** — local MySQL 8.4 with health check, named volume, and `db/schema.sql` mounted into `/docker-entrypoint-initdb.d/`.
- **`db/schema.sql`** — placeholder schema with a `schema_version` table to track future migrations.
- **`LICENSE`** — MIT.
- **`CHANGELOG.md`** — this file.
- **`zod`** and **`express-rate-limit`** added to dependencies.
- **`tsconfig.base.json`** — `strict: true`, `noImplicitOverride`, `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch` enabled workspace-wide.

### Changed

- **`libs/types` and `libs/utils` `package.json`** — dropped `"type": "module"`. The libs are consumed via TS path aliases at source level, and `"type": "module"` made the backend's Node16 module resolution treat them as ESM (breaking `tsc --noEmit` with TS1479/TS1541). Removing it has no runtime effect since nothing actually imports the compiled JS.
- **`libs/types/eslint.config.mjs`** and **`libs/utils/eslint.config.mjs`** — added `ignoredDependencies: ['vitest']` and `tsconfig.spec.json` to `ignoredFiles` so `@nx/dependency-checks` stops flagging `vitest` as a missing dep (it's only referenced via `tsconfig.spec.json`'s `types` array).
- **`tsconfig.base.json`** — added `"baseUrl": "."` so the new `@mcb/*` paths resolve.
- **`apps/frontend/.storybook/main.ts`** — fixed story glob (`../src/app/**` → `../src/**`) so the new component stories are actually picked up.
- **`apps/frontend/src/routes/__root.tsx`** — removed unused `Link` import (caught by strict `noUnusedLocals`).
- **`package.json` version** bumped from `0.0.0` to `0.1.0` to match the initial release entry.
- **`eslint.config.mjs`** — configured `@typescript-eslint/no-unused-vars` with `argsIgnorePattern: '^_'` so underscore-prefixed parameters (required for Express error-handler arity) no longer trip the linter.
- **`apps/frontend/src/main.tsx`** — replaced the `document.getElementById('root')!` non-null assertion with an explicit null check that throws a clear error. Removes the last `no-non-null-assertion` warning in the frontend.
- **`apps/frontend/.storybook/main.ts`** — `getAbsolutePath` return type changed from `any` to `string`. Clears the `no-explicit-any` warning.

### Changed

- **AI attribution switched from inline comments to an append-only JSONL log.** Inline `// ai: claude-opus-4-6` markers proved far too noisy — every line of hardening-pass code carried one, diffs were unreadable, and reviewers would quickly start ignoring them. Replaced with `.ai-attribution.jsonl` at the repo root: one JSON object per line, one entry per AI pass, listing date / model / scope / description / files. `jq -s '.' .ai-attribution.jsonl` reads the whole log. The file is in `.prettierignore` so formatters don't reflow it (one line = one entry is load-bearing for merge safety).
- **`CLAUDE.md`** — AI-attribution section rewritten to document the new log, its schema, and append/merge rules.
- **`.claude/agents/*.md`** — frontend-reviewer, backend-api, and test-writer agents updated to reference the log instead of inline markers.
- **`README.md`** — contributing note updated to mention the log.

### Changed

- **`apps/backend/src/main.ts`** — completely reworked: helmet with explicit CSP, CORS locked to `FRONTEND_URL` (no localhost fallback), body size limits, rate limiter, `trust proxy`, `x-powered-by` header disabled, env loaded from validated `env.ts`.
- **`apps/backend/src/middleware/errorHandler.ts`** — no longer leaks stack traces. Returns the real error message in development, a generic `"Internal server error"` in production. Full error still logged server-side.
- **`apps/backend/src/config/db.ts`** — pulls from validated `env`, enables `namedPlaceholders` and `waitForConnections`.
- **`apps/backend/src/routes/health.ts`** — now returns `503` (not `500`) when the DB is unreachable, and logs the underlying error server-side.
- **`apps/frontend/src/main.tsx`** — `ReactQueryDevtools` is dynamically imported and only mounted when `import.meta.env.DEV` is true. Devtools no longer ship in production bundles.
- **`apps/frontend/src/lib/api.ts`** — throws at module load if `VITE_API_URL` is unset (no silent localhost fallback).
- **`apps/backend-e2e/src/support/global-setup.ts`** — cleaned up, comments tightened.
- **`scripts/dev-setup.sh`** — rewritten as an idempotent bootstrap. `set -euo pipefail`, no more `sudo`, uses `docker compose up -d mysql` and waits on the container health check.
- **`.env.example`** — `JWT_SECRET` and `SESSION_SECRET` removed (no auth ships), `DB_PASSWORD` placeholder changed from `secret` to `change-me`, comments added explaining each block.
- **`README.md`** — full rewrite. New sections: Prerequisites, Quick Start, Manual Setup (non-Docker path), Daily Development (npm-script reference table), Database (reset/migration guidance), Environment Variables (full table with required/default columns + `VITE_*`-is-public warning), Production Deployment (8-step checklist), Security (forker checklist).
- **`.gitignore`** — `CLAUDE.md`, `AGENTS.md`, `.agents/`, and `.github/` removed from the ignore list so AI instructions and CI workflows can be tracked.

### Removed

- **Inline `// ai: claude-opus-4-6` markers stripped** from every file touched in the hardening pass: backend `main.ts`, `config/env.ts`, `config/db.ts`, `middleware/errorHandler.ts`, `middleware/validate.ts`, `routes/health.ts`, `backend-e2e/support/global-setup.ts`, frontend `main.tsx` + `lib/api.ts`, `docker-compose.yml`, `db/schema.sql`, `scripts/dev-setup.sh`.

First hardening pass before opening the boilerplate to the public. Security defaults, env validation, infra, and docs all moved into a fork-ready state. **JWT stub removed** — fork and add real auth before exposing any protected data.

### Removed

- **JWT stub from frontend `api.ts`** — `localStorage` token read, `Authorization` header injection, and the 401 interceptor are gone. The backend never had matching auth, so this was misleading dead code. Re-add real auth (JWT, sessions, OAuth, Auth.js, …) when you need it.
- **`JWT_SECRET` / `SESSION_SECRET`** from `.env.example`.
- Unused `Link` import in `apps/frontend/src/routes/__root.tsx` (surfaced by the new strict-mode `noUnusedLocals`).

### Security

- **Stack-trace leakage fixed.** Production error responses now return a generic message; details stay in server logs.
- **CORS hardened.** No wildcard, no localhost fallback — `FRONTEND_URL` is required and validated by Zod.
- **Rate limiting added.** 100 req/min/IP globally; tune per-route as your traffic grows.
- **Body size capped** at 100 KB to prevent memory-exhaustion attacks. Raise per-route only if needed.
- **Helmet CSP made explicit** instead of relying on permissive defaults.
- **`x-powered-by: Express` header removed** so the framework isn't advertised to attackers.
- **Env validation at boot** — the app fails fast on missing or malformed config rather than starting in a broken state.
- **`mysql2` configured with `namedPlaceholders: true`** — combined with the existing parameterized queries, this keeps the boilerplate's SQL safe by default. Document new code must follow suit.
- **Outstanding `npm audit` finding documented.** Direct `axios` is on the latest version (`1.15.0`); the 7 critical CVEs all live under transitive dev dependencies (`@module-federation/*` via `@nx/react`, `jsdom` via `@tootallnate/once`). They are **not** shipped to production bundles. `npm audit fix --force` would jump `jsdom` to v29 and break Vitest, so the upgrade is deferred until upstream releases. Re-check on every release.
- **No authentication is included.** The README and CLAUDE.md now state this explicitly. Forks must add their own auth layer before exposing protected data.

### Notes

- Workspace-wide verification after this pass: `npm run typecheck` ✓ (3 projects), `npm run lint` ✓ (6 projects), `npm test` ✓ (4 projects), `npx nx build backend` ✓, `npx nx build frontend` ✓ (298 KB / 93 KB gzip).
- Two pre-existing ESLint warnings remain in `apps/frontend/src/main.tsx` (`@typescript-eslint/no-non-null-assertion` on `document.getElementById('root')!`). Not introduced by this pass — left as-is.
- Per `CLAUDE.md`, every line of AI-generated code in this release carries an `// ai: claude-opus-4-6` marker.
