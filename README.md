# Steamdeck Webdev Template

A full-stack Nx monorepo boilerplate with a React frontend, an Express backend, and MySQL — ready to fork for new projects.

**Live demo:** [Frontend app](https://victorvinci.github.io/steamdeck-webdev-template/) · [Storybook](https://victorvinci.github.io/steamdeck-webdev-template/storybook/)

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/victorvinci/steamdeck-webdev-template/badge)](https://scorecard.dev/viewer/?uri=github.com/victorvinci/steamdeck-webdev-template)

See [CHANGELOG.md](./CHANGELOG.md) for release history.

> **Built on a Steam Deck running SteamOS.** This template was developed end-to-end inside a **Linux Mint Distrobox container** on SteamOS, because SteamOS's root filesystem is immutable and read-only by default — you can't install system packages (node, mysql, docker) onto the host without unlocking it, and unlocking resets on every OS update. Running development inside Distrobox sidesteps that entirely: the container is a normal mutable Mint install with its own `/usr`, `/home`, and package manager, and the host stays pristine.
>
> **Why this matters for you:** nothing in this repo is Steam Deck-specific — the code, scripts, and CI all work on any Linux/macOS machine — but the dev-setup scripts (`scripts/dev-setup-native.sh`, the `npm run setup` flow, the `sudo mysql` auth_socket paths) were written and tested assuming you're inside a **Debian/Ubuntu-family userland** (Mint, Ubuntu, Debian) with normal sudo, not on bare SteamOS. If you're on a Steam Deck yourself, create a Mint distrobox (`distrobox create --name mint --image linuxmintd/mint22-amd64`) and clone the repo inside it — everything else in this README applies as-is.
>
> **Editor setup on Steam Deck:** VS Code / Cursor / any editor of choice is installed **inside the Distrobox container** (not on the SteamOS host) and launched from there, so it sees the container's toolchain and pathed binaries. Git, node, docker, and mysql clients all live in the container.
>
> **Steam Deck host helpers.** `scripts/steamdeck/` ships two host-level utility scripts that are **not** part of the project build — they keep a Steam Deck dev workstation livable across SteamOS updates (which wipe the root filesystem) and day-to-day boots. They're bundled here so a fresh Deck can clone this repo and immediately restore its dev environment without hunting them down:
>
> - **`backup.sh`** + **`BACKUP_README.md`** — backs up dotfiles (`.zshrc`, `.gitconfig`, …), SSH keys, KDE autostart entries, Starship/KeePassXC/terminal configs, font installs, VS Code/Cursor plugin lists, and project references to a chosen destination (external drive recommended). Successful runs verify SHA-256 checksums immediately and auto-rotate old backups. Run it on a healthy Deck, restore from it on a freshly-reimaged one.
> - **`boot_sequence.sh`** + **`BOOT_SEQUENCE_README.md`** — KDE autostart helper that fixes the Proton Mail Bridge "No keychain available" race on boot. Waits for KeePassXC to register `org.freedesktop.secrets` on D-Bus **and for the database to be unlocked** before launching Bridge. Without this two-stage gate, Bridge can race ahead against a locked vault and silently rewrite `vault.enc` as unencrypted — unrecoverable without reconfiguring every Proton account. The READMEs explain the D-Bus mechanics and the `.desktop` autostart wiring.
>
> Both scripts have their own changelog at `scripts/steamdeck/CHANGELOG.md` (separate from this repo's top-level `CHANGELOG.md` — they evolve independently from the web template).

> **Heads-up:** this boilerplate intentionally **ships without authentication**. Add your own auth layer (JWT, sessions, OAuth, Auth.js, etc.) before exposing protected data. See [Security](#security).

> **New fork?** Read [`docs/FORK.md`](./docs/FORK.md) first. It walks through the mechanical rename (`scripts/rename-template.sh`), the GitHub-side setup (Pages, rulesets, Nx Cloud, Renovate), and what to strip out once the template has served its purpose. Skipping it and running the Quick Start below will work, but you'll inherit the template's name, CODEOWNERS, and live-demo URLs — not what you want for a new project.

---

## Table of Contents

- [Tech Stack](#tech-stack)
- [Scope](#scope)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Setup](#manual-setup)
- [Daily Development](#daily-development)
- [Testing](#testing)
- [API Surface](#api-surface)
- [CI / CD](#ci--cd)
- [Database](#database)
- [Environment Variables](#environment-variables)
- [Production Deployment](#production-deployment)
- [Security](#security)
- [Troubleshooting](./docs/TROUBLESHOOTING.md)
- [Forking this template](./docs/FORK.md)
- [Pulling template updates into your fork](./docs/UPGRADE.md)
- [Contributing](./CONTRIBUTING.md)
- [Code of Conduct](./CODE_OF_CONDUCT.md)
- [Security](./SECURITY.md)
- [License](#license)

---

## Tech Stack

| Layer         | Technology                                                  |
| ------------- | ----------------------------------------------------------- |
| Monorepo      | [Nx](https://nx.dev)                                        |
| Frontend      | React 19, TypeScript, Vite, TanStack Router, TanStack Query |
| Backend       | Node.js 24+, Express 5, TypeScript                          |
| Database      | MySQL 8 (via `mysql2`)                                      |
| Validation    | [Zod](https://zod.dev)                                      |
| Security mw   | helmet, cors, express-rate-limit                            |
| Testing       | Vitest / Jest (unit), Playwright (e2e)                      |
| Component dev | Storybook (addon-a11y for accessibility audits)             |
| Linting       | ESLint + Prettier                                           |

---

## Scope

What ships with this template — and, equally important, what doesn't. The point is to give a fork a working monorepo skeleton with safe defaults, **not** a half-complete product. Things in the "doesn't ship" column are deliberate omissions, not bugs.

**Ships with:**

- Full Nx workspace wired for `nx affected` (per-PR CI, scheduled CI, distributed cache via Nx Cloud, filesystem cache fallback).
- React + Vite frontend with TanStack Router (file-based) + TanStack Query (server state) + Storybook (component dev with `addon-a11y`).
- Express 5 backend with helmet, CORS, rate limiting (skips `/api/health/*`), pino structured logging with `x-request-id` propagation, graceful SIGTERM/SIGINT shutdown.
- Shared `libs/types` (Zod schemas + inferred TS types — single source of truth across both apps) and `libs/utils` (dependency-free helpers).
- MySQL 8 dev DB via Docker Compose (with a `dev-setup-native.sh` fallback for hosts without Docker), numbered SQL migrations under `db/migrations/`, transaction-wrapped migration runner.
- Demo `/api/users` route end-to-end: Zod schema → service layer → MySQL pool → React Query hook → component → Storybook + Playwright + Jest + Vitest coverage.
- Release flow: `develop → main → tag` with bump / release / hotfix / hotfix-sync PR templates, signed-commit branch rulesets, `release.yml` SBOM + GitHub Release publication, fork-rename script (`scripts/rename-template.sh`) + onboarding doc (`docs/FORK.md`).
- AI-assisted development scaffolding: `CLAUDE.md` agent contract, `.ai-attribution.jsonl` audit log, two-commit attribution flow, CI guard validating each new line is parseable JSON.

**Does not ship with — fork concerns:**

- **Authentication / authorisation.** No login, sessions, JWTs, OAuth, RBAC, or password handling. The `/api/users` demo is unauthenticated by design.
- **Real domain schema.** `db/migrations/001_initial.sql` provisions a single `users` table for the demo. Replace it with your own schema; the migration runner doesn't care what's in there.
- **ORM or query builder.** Direct `mysql2` with named placeholders — no Prisma / Drizzle / Knex. Add one if you want; nothing in the template assumes its absence.
- **Production deployment IaC.** GitHub Pages publishes the frontend (see `pages.yml`) but there's no Terraform / Pulumi / Helm / Docker production image for the backend. The `Production Deployment` section below covers the runtime expectations; the substrate is your call.
- **Payments, email, queue, cache.** No Stripe, no SES, no Redis, no BullMQ. Each fork pulls in what it needs.
- **Feature flags / experiment framework.** No GrowthBook / LaunchDarkly / Unleash wiring.
- **Observability beyond logs.** Pino prints structured logs with `x-request-id` for stitching, but no APM / tracing / metrics exporter is shipped.
- **i18n.** English-only strings; no `react-intl` / `i18next` setup.

The boundary is: **patterns and infrastructure that every web app needs** (typed API contracts, signed releases, working CI, env validation, graceful shutdown) ship; **product-specific subsystems** (auth, payments, observability vendor) don't. If a feature would force a decision a fork should make for itself, it stays out.

---

## Project Structure

```text
steamdeck-webdev-template/
├── apps/
│   ├── frontend/               # React + Vite + TanStack Router
│   │   ├── src/
│   │   │   ├── components/     # Presentational components (+ co-located *.stories.tsx)
│   │   │   ├── lib/            # Axios client, env validation, query hooks
│   │   │   ├── routes/         # File-based routing (TanStack Router)
│   │   │   └── main.tsx        # Entry — React, Router, QueryClient setup
│   │   └── .storybook/         # Storybook config (addon-a11y for accessibility audits)
│   ├── frontend-e2e/           # Playwright e2e tests
│   ├── backend/                # Express REST API
│   │   ├── openapi.json        # Generated OAS 3.0.3 snapshot — npm run gen:openapi
│   │   └── src/
│   │       ├── config/         # env.ts (Zod-validated), db.ts (MySQL pool), logger.ts (Pino)
│   │       ├── errors/         # AppError base class + HTTP subclasses
│   │       ├── middleware/     # errorHandler, notFound, validate (Zod)
│   │       ├── openapi/        # registry.ts (zod-to-openapi) + serve.ts (mounts /docs, !isProd)
│   │       ├── routes/         # /api/health/{live,ready}, /api/users, …
│   │       ├── services/       # Data access layer (SQL queries)
│   │       └── main.ts         # Entry (helmet, CORS, rate-limit, graceful shutdown)
│   └── backend-e2e/            # Backend integration tests (Jest)
├── libs/
│   ├── types/                  # @mcb/types — shared Zod schemas + inferred TS types
│   └── utils/                  # @mcb/utils — small dependency-free helpers
├── db/
│   ├── migrations/             # Numbered SQL migration files (001_initial.sql, …)
│   ├── schema.sql              # Bootstrap script — aggregates migrations for first init
│   └── seed.sql                # Local-only dev seed data; loaded by `npm run db:reset`
├── scripts/
│   ├── dev-setup.sh            # Idempotent dev bootstrap (auto-detects docker vs native mysqld)
│   ├── dev-setup-native.sh     # Native MySQL fallback used when docker is unavailable
│   ├── migrate.ts              # Lightweight DB migration runner (reads db/migrations/)
│   ├── db-reset.ts             # Drop tables → migrate → seed; refuses in production
│   ├── gen-openapi.ts          # Regenerates apps/backend/openapi.json from Zod schemas
│   ├── check-env.ts            # Diffs `.env` against `.env.example`; runs ahead of `npm run dev`
│   ├── lint-migrations.sh      # Pre-commit + CI safety lint for db/migrations/*.sql
│   ├── extract-changelog-section.sh  # Pulls a single version's notes out of CHANGELOG.md
│   ├── rename-template.sh      # Renames the template for a fresh fork (project, npm scope, owner)
│   ├── scan-template-residuals.sh    # Self-test that the rename script left no template strings behind
│   └── steamdeck/              # Steam Deck host helpers (separately versioned, not part of the build)
├── .devcontainer/              # Dev Containers / Codespaces config (Open in Codespaces → ready in ~90s)
├── .github/
│   ├── ISSUE_TEMPLATE/         # Bug report and feature request issue forms
│   ├── pull_request_template.md
│   ├── PULL_REQUEST_TEMPLATE/  # Specialized templates (release / hotfix / hotfix-sync / bump)
│   ├── actions/                # Reusable composite actions (setup-node-deps, resolve-nx-base)
│   ├── docker/                 # Pre-baked Playwright + mysql-client image used by the e2e job
│   └── workflows/              # CI (ci.yml), scheduled checks (ci-scheduled.yml),
│                               #   CodeQL SAST (codeql.yml), OSSF Scorecard (scorecard.yml),
│                               #   auto-draft PRs (force-draft.yml), GitHub Pages (pages.yml),
│                               #   release pipeline (release.yml), PR-size labeler (pr-size.yml)
├── docker-compose.yml          # Local MySQL service
├── nx.json                     # Nx workspace config (plugins, namedInputs, targetDefaults)
├── tsconfig.base.json          # Root TypeScript config (path aliases: @mcb/types, @mcb/utils)
├── eslint.config.mjs           # ESLint flat config (module boundary enforcement)
├── renovate.json               # Renovate dependency automation (grouped by ecosystem)
├── lighthouserc.json           # Lighthouse CI assertions (weekly scheduled run)
├── commitlint.config.js        # Conventional Commits enforcement
├── .markdownlint-cli2.jsonc    # Markdown lint rules (Prettier-aware; user-doc scoped via ignores)
├── .gitleaks.toml              # gitleaks ruleset (default rules + path allowlist)
├── .gitleaksignore             # Per-finding fingerprint ignores for gitleaks (currently empty)
├── .ai-attribution.jsonl       # Append-only AI provenance log — see CLAUDE.md
├── .gitattributes              # LF enforcement, binary markers, generated-file collapse
├── .dockerignore               # Keeps Docker build context small for future Dockerfiles
└── .env.example                # Template — copy to .env
```

---

## Prerequisites

- **Node.js** ≥ 24.0.0
- **npm** ≥ 10.0.0
- **MySQL 8** — either via **Docker Compose** (default, recommended) or **natively-installed `mysqld`**. `npm run setup` auto-detects which path to use; see [Manual Setup](#manual-setup) for the native flow's requirements.

---

## Quick Start

The fastest path is **GitHub Codespaces** or a local **VS Code Dev Container**: click `Code → Codespaces → Create codespace`, or open the repo locally and pick `Reopen in Container`. The devcontainer (`.devcontainer/devcontainer.json`) provisions Node 24 + MySQL 8.4, runs `npm ci && npm run migrate`, and forwards ports 4200 / 3000 / 6006 — from cold start to a working `npm run dev` is ~90 seconds with no host-side setup.

If you'd rather work directly on the host:

```bash
git clone git@github.com:victorvinci/steamdeck-webdev-template.git
cd steamdeck-webdev-template

# 1. Install JS dependencies
npm install

# 2. Bootstrap dev environment — creates .env, starts MySQL (via docker compose
#    if Docker is installed, otherwise falls back to a locally-running mysqld),
#    waits for it, and loads db/schema.sql. See Manual Setup for the native path.
npm run setup

# 3. Run frontend + backend together
npm run dev
```

You should now have:

- **Frontend** → <http://localhost:4200>
- **Backend** → <http://localhost:3000>
- **Health checks:**
    - <http://localhost:3000/api/health/live> — liveness, no dependencies touched (`{ data: { status: "ok" } }`)
    - <http://localhost:3000/api/health/ready> — readiness, pings MySQL (`{ data: { status: "ok", db: "connected" } }`; `503` if DB is unreachable)
    - <http://localhost:3000/api/health> — back-compat alias for `/ready` (same response shape)

> The first run will pull the `mysql:8.4` image — give it a minute.

---

## Manual Setup

`scripts/dev-setup.sh` (which `npm run setup` calls) auto-detects whether Docker is available. If `docker` is missing, it transparently `exec`s `scripts/dev-setup-native.sh`, which provisions the same database + user + schema against a locally-running `mysqld`. This is the path contributors on hosts without Docker (e.g. SteamOS, sandboxed CI images) should take.

**Requirements for the native path:**

- `mysql` client + `mysqld` installed and listening on `localhost:${DB_PORT:-3306}`
- `sudo` access to connect as MySQL root via the unix socket (the `auth_socket` plugin — the default on Debian/Ubuntu `mysql-server` packages, so `sudo mysql` Just Works there)
- `DB_PASSWORD` in `.env` that satisfies **both** constraints below (the CHANGELOG spells out why):
    - Shell-safe: `[A-Za-z0-9_-]` only. The bash script sources `.env` via `. ./.env`, so unquoted `&`/`$`/`;`/`'` break parsing.
    - MySQL `validate_password` policy (default on 8.x): digit + mixed case + at least one non-alphanumeric. `_` and `-` count as non-alphanumeric, so `A1b2_C3-...` is fine.

Then just run:

```bash
npm install
npm run setup   # detects no docker → runs native bootstrap
npm run dev
```

`npm run dev` runs `npm run check-env` between `setup` and the `serve` step — it diffs `.env` against `.env.example` and exits early with a friendly message if any required key is missing or empty, so you never get a confusing `undefined.foo` failure on the first request.

### Truly by-hand (no script)

If you'd rather skip the script entirely:

1. **Install MySQL 8** locally and start it.
2. **Create your env file** and edit credentials to match what you're about to provision:

    ```bash
    cp .env.example .env
    ```

3. **Create the database and user** (values must match `.env`):

    ```sql
    CREATE DATABASE steamdeck_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER 'steamdeck'@'localhost' IDENTIFIED BY '<your-password>';
    GRANT ALL PRIVILEGES ON steamdeck_dev.* TO 'steamdeck'@'localhost';
    FLUSH PRIVILEGES;
    ```

4. **Load the schema:**

    ```bash
    mysql -u steamdeck -p steamdeck_dev < db/schema.sql
    ```

5. **Install and run:**

    ```bash
    npm install
    npm run dev
    ```

---

## Daily Development

All commands are defined in `package.json` — prefer them over raw `nx` invocations.

Every command below maps to an entry in `package.json` → `scripts`. The table is the full list — if a script isn't here, it doesn't exist.

| Command                        | What it does                                                                                                                                  |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **Bootstrap**                  |                                                                                                                                               |
| `npm run setup`                | One-shot dev bootstrap — creates `.env` from `.env.example`, starts MySQL (Docker Compose or native `mysqld` fallback), loads `db/schema.sql` |
| `npm run dev`                  | Runs `setup` then serves frontend + backend in parallel                                                                                       |
| `npm run fe`                   | Frontend only (`http://localhost:4200`)                                                                                                       |
| `npm run be`                   | Backend only (`http://localhost:3000`)                                                                                                        |
| `npm run storybook`            | Storybook for the frontend                                                                                                                    |
| **Quality gates**              |                                                                                                                                               |
| `npm run lint`                 | Lint every project                                                                                                                            |
| `npm run lint:fix`             | Lint + autofix                                                                                                                                |
| `npm run lint:md`              | Lint user-facing Markdown (README / CHANGELOG / docs/) — config in `.markdownlint-cli2.jsonc`                                                 |
| `npm run lint:migrations`      | Lint `db/migrations/*.sql` for destructive-DDL footguns; runs in pre-commit + CI                                                              |
| `npm run format`               | Prettier write across the whole repo                                                                                                          |
| `npm run format:check`         | Prettier check (CI-friendly, non-mutating)                                                                                                    |
| `npm run typecheck`            | `tsc --noEmit` across every project                                                                                                           |
| `npm run check`                | `format:check` + `lint` + `typecheck` + `test` in sequence — run this before every PR                                                         |
| `npm run check:affected`       | Same as `check`, but only on Nx-affected projects                                                                                             |
| `npm run preflight`            | `check` + `e2e` + Storybook build — full local CI dry-run, catches what `check` skips                                                         |
| `npm run check-env`            | Verifies `.env` has every key declared (uncommented) in `.env.example`; fails fast if not                                                     |
| **Unit tests**                 |                                                                                                                                               |
| `npm test`                     | All unit tests (all projects)                                                                                                                 |
| `npm run test:fe`              | Frontend tests (Vitest)                                                                                                                       |
| `npm run test:be`              | Backend tests (Jest)                                                                                                                          |
| `npm run test:types`           | `libs/types` tests                                                                                                                            |
| `npm run test:utils`           | `libs/utils` tests                                                                                                                            |
| `npm run test:storybook`       | Smoke-test every story (renders without errors). Requires `npm run storybook` running in another terminal at `:6006`                          |
| **E2E tests**                  |                                                                                                                                               |
| `npm run e2e`                  | All e2e suites (`frontend-e2e` + `backend-e2e`)                                                                                               |
| `npm run e2e:fe`               | Frontend e2e only (Playwright)                                                                                                                |
| `npm run e2e:be`               | Backend e2e only (Jest)                                                                                                                       |
| **Database**                   |                                                                                                                                               |
| `npm run migrate`              | Apply pending database migrations from `db/migrations/`                                                                                       |
| `npm run migrate:status`       | Show which migrations are applied vs pending                                                                                                  |
| `npm run db:reset`             | Drop every table, re-apply all migrations, load `db/seed.sql`. Refuses if `NODE_ENV=production`                                               |
| **API contract**               |                                                                                                                                               |
| `npm run gen:openapi`          | Regenerate `apps/backend/openapi.json` from the Zod schemas in `libs/types`                                                                   |
| `npm run gen:openapi:check`    | Regenerate then `git diff --exit-code` — the drift gate that CI runs                                                                          |
| **Build**                      |                                                                                                                                               |
| `npm run build`                | Runs `check` first, then builds every project (outputs to `dist/`)                                                                            |
| `npm run clean`                | Remove `dist/`, `.nx/cache`, `storybook-static`, and `coverage` build artifacts                                                               |
| **Lifecycle hooks**            |                                                                                                                                               |
| `npm run prepare`              | Installs Husky git hooks — runs automatically after `npm install`, you normally won't invoke it by hand                                       |
| **Raw Nx escape hatches**      |                                                                                                                                               |
| `npx nx graph`                 | Visualize the project dependency graph                                                                                                        |
| `npx nx affected -t lint test` | Run arbitrary targets on Nx-affected projects only                                                                                            |

---

## Testing

- **Unit tests** live next to source as `*.spec.ts(x)` — Vitest in the frontend / `libs/types`, Jest in the backend / `libs/utils`.
- **E2E tests** live in `apps/frontend-e2e` (Playwright) and `apps/backend-e2e` (Jest integration tests).
- **Storybook stories** are mandatory for every new frontend component (`*.stories.tsx`, co-located). The `@storybook/addon-a11y` addon runs axe-core accessibility audits in the Storybook panel; core essentials (controls, actions, viewport, docs) are built into Storybook 10.
- **Storybook smoke tests** run via `@storybook/test-runner` — every `*.stories.tsx` is opened in headless Chromium and asserted to render without errors. Run locally with `npm run storybook` in one terminal and `npm run test:storybook` in another, or let the `storybook test` CI job catch regressions on PRs (gated on the same `frontend` paths-filter as the build).

```bash
npm test             # all unit tests
npm run e2e          # all e2e suites (frontend + backend)
npm run e2e:fe       # frontend e2e only (Playwright)
npm run e2e:be       # backend e2e only (Jest)
```

> First local e2e run: `npx playwright install` to fetch browser binaries. The e2e targets depend on `backend:serve` via Nx, so you don't need to start the backend yourself — but make sure your `.env` / MySQL are provisioned first (`npm run setup`).

---

## API Surface

The demo backend exposes three routes. Schemas live in `libs/types/src/lib/api.ts` and are the single source of truth — both apps import from `@mcb/types`, so the contract can never drift between server and client.

### OpenAPI / Swagger UI

The Zod schemas in `libs/types` are also the source of truth for an OpenAPI 3.0.3 document, generated by `apps/backend/src/openapi/registry.ts` (`@asteasolutions/zod-to-openapi`). Three surfaces:

- **Swagger UI at `/docs`** — interactive request builder, mounted automatically when `NODE_ENV !== 'production'`. Hit it at <http://localhost:3000/docs> after `npm run be`. Gated off in production by default — see `apps/backend/src/main.ts` for the toggle (one-line removal of the `!isProd` guard if you want public docs; apply rate-limiting first).
- **Raw JSON at `/api/openapi.json`** — same gating as `/docs`. Useful for `openapi-typescript`, Postman import, or any other code-gen / doc-rendering tool.
- **Committed snapshot at `apps/backend/openapi.json`** — regenerated by `npm run gen:openapi`. Reviewers see API-shape changes inline in the PR diff. The `openapi-drift` CI job runs `npm run gen:openapi:check` (regen → `git diff --exit-code`) so a schema edit that wasn't followed by a regen fails the build. The file is in `.prettierignore` so the generator's stable 4-space-sorted-keys output isn't reformatted by Prettier's array-collapse heuristic.

The OpenAPI document version is hardcoded in `apps/backend/src/openapi/registry.ts` (constant `API_VERSION`) — bump it on breaking API changes, separately from the npm package version.

### Response envelope

Every successful response is wrapped in:

```ts
type ApiSuccess<T> = { data: T };
```

Every error response is:

```ts
type ApiError = {
    error: string; // human-readable summary
    issues?: Array<{ path: string; message: string }>; // present for Zod validation failures
};
```

`ApiResponse<T> = ApiSuccess<T> | ApiError`. Use the `isApiError` type guard from `@mcb/types` to branch.

### Routes

#### `GET /api/health/live`

Liveness probe. Doesn't touch the DB. A failure means the process is wedged — orchestrator should restart.

- **Response (200):** `{ "data": { "status": "ok" } }`

#### `GET /api/health/ready`

Readiness probe. Pings the MySQL pool with `SELECT 1`. A failure means the instance is alive but can't serve requests — orchestrator should stop routing traffic without restarting.

- **Response (200):** `{ "data": { "status": "ok", "db": "connected" } }`
- **Response (503):** `{ "error": "Database unavailable" }`

`GET /api/health` is retained as an alias of `/ready` for back-compat with probes that haven't been updated to the split.

#### `GET /api/users?limit=20&offset=0`

Lists users with pagination.

- **Query params (Zod-validated, coerced from strings):**
    - `limit` — integer 1–100, default `20`
    - `offset` — integer ≥ 0, default `0`
- **Response (200):**

    ```json
    {
        "data": {
            "users": [
                {
                    "id": 1,
                    "name": "Ada Lovelace",
                    "email": "ada@example.com",
                    "createdAt": "2026-04-12T00:00:00.000Z"
                }
            ],
            "total": 1
        }
    }
    ```

- **Response (400):** `{ "error": "...", "issues": [{ "path": "limit", "message": "Number must be less than or equal to 100" }] }`

### Cross-cutting behaviour

Every route shares the middleware stack from `apps/backend/src/main.ts`:

- `helmet` security headers (CSP, referrer policy, frame-ancestors).
- `cors` with `origin: env.FRONTEND_URL` and `credentials: true`.
- `express-rate-limit` at 100 req/min per IP, **skipping `/api/health/*`** so orchestrator probes don't burn the budget.
- `pino-http` request logging with `x-request-id` propagation (client-supplied IDs are validated against `/^[a-zA-Z0-9-]{1,64}$/`; otherwise a fresh UUID is assigned).
- 100 KB body / form payload cap.

---

## CI / CD

Three GitHub Actions workflows ship with the repo. Together they form a gating pipeline on every PR, a scheduled dependency/perf/housekeeping pipeline, and a SAST pipeline.

### Per-PR (`.github/workflows/ci.yml`)

Runs on every pull request (and on push to `main` / `develop` as the non-affected full variant). These jobs **gate** merges — a red check blocks the PR.

- `detect` — path-filter job that outputs `code` (any app/lib/config change) and `frontend` (frontend-specific change). Gates the heavy jobs (`check`, `storybook-build`, `e2e`, `commitlint`) — docs-only PRs pay only ~1 min (detect + attribution-guard + ci-pass) while branch protection stays unblocked. `attribution-guard` intentionally isn't gated by `code`, since AI commits can touch docs/workflows/configs and still owe a JSONL entry
- `check` — `format:check` + `nx affected -t lint typecheck test` + `nx affected -t build`, wrapped in an Nx Cloud CI run for distributed cache + self-healing. Uploads `dist/` as an artifact. Quality gates and build are merged into one job to avoid a redundant checkout + `npm ci` on a second runner
- `storybook-build` — ensures every story still compiles (skipped on backend-only changes via the `frontend` path filter). Uploads the static build as a 1-day artifact so the next job can reuse it.
- `storybook-test` — `@storybook/test-runner` opens every story in headless Chromium and asserts it renders without errors (catches stale prop renames, deleted exports, throw-on-mount regressions that the build alone wouldn't fail on). Downloads the static build from `storybook-build` instead of rebuilding — saves ~1 min per PR.
- `markdown-lint` — `markdownlint-cli2` over user-facing docs. Gated on a `markdown` paths-filter so PRs without MD changes skip it.
- `openapi-drift` — runs `npm run gen:openapi:check` (regen → `git diff --exit-code`) so a Zod schema edit that wasn't followed by an `apps/backend/openapi.json` regen fails the build. Gated on an `openapi` paths-filter (`libs/types/`, `apps/backend/src/openapi/`, the snapshot, the generator script).
- `gitleaks` — secret scan over the full git history of the PR branch. Complements GitHub-native Secret Scanning (which catches known-vendor patterns) by adding a generic-API-key entropy rule + ~150 vendor token formats, and the same scan runs locally in `.husky/pre-commit` so a leak never has to leave the dev machine. Config in `.gitleaks.toml`; per-finding mutes go in `.gitleaksignore`. CI downloads the gitleaks binary directly (checksum-pinned by SHA256) instead of using `gitleaks/gitleaks-action` — the action requires a paid licence for any org-owned repo, even free public ones.
- `e2e` — Playwright (frontend) + Jest (backend) against a real `mysql:8.4` service container, seeded from `db/schema.sql`
- `commitlint` — enforces Conventional Commits on the PR title (squash-merge makes the title the final commit)
- `attribution-guard` — runs on every non-draft PR and enforces two rules. (1) If `apps/` or `libs/` changed, a `CHANGELOG.md` entry is required. (2) If any commit in the PR carries an AI-assistant `Co-Authored-By` trailer (claude, Claude Code, GPT, Gemini, Copilot, Cursor, Devin, Codex, …), the PR must also contain at least one net-new line in `.ai-attribution.jsonl`. Human-only PRs don't need a JSONL append. Automation bots (dependabot, renovate, github-actions) are explicitly excluded from the trailer match
- `ci-pass` — aggregator status check. Point branch protection at this single job instead of listing every job by name. It passes when every upstream job succeeded or was intentionally skipped (e.g. `storybook-build` on a backend-only PR), and fails if any upstream job failed or was cancelled.

`storybook-build`, `storybook-test`, and `e2e` only run on `pull_request` events — on `push` to `main` / `develop` they're skipped, because the PR that just squash-merged already ran them. `check` + `build` + CodeQL still run on push as belt-and-braces. Pushes whose only diff is `.ai-attribution.jsonl` skip CI entirely via `paths-ignore`; bundled two-commit pushes (work + attribution) still trigger CI because the work commit touches non-ignored files.

### Weekly (`.github/workflows/ci-scheduled.yml`)

Runs every Monday at 05:23 UTC, also `workflow_dispatch`-able on demand. Designed to fit inside a single free-tier weekly slot (~15–20 min total). These jobs **don't gate** — they file or update tracking issues when they find something, and auto-close those issues when the tree is clean again.

- `dep-health` — rollup of three dependency checks that previously ran as separate jobs:
    - `npm audit --omit=dev --audit-level=high` against production deps
    - `license-checker` scan for GPL/AGPL/LGPL/SSPL/CC-BY-NC/EUPL in production deps
    - `npm outdated --omit=dev` rollup (a single-view companion to Renovate's per-package PRs)
- `bundle-size` — builds the frontend once and runs **both** a gzipped-bundle budget check against `.github/bundle-size-baseline.json` (fails the weekly check if bundle grows >10%) **and** Lighthouse CI against the same `dist/` (asserts the categories in `lighthouserc.json`). Lighthouse used to live in the per-PR pipeline with `continue-on-error: true` — pure minute burn that never gated anything. Moved here so perf regressions still surface weekly without paying for them on every PR.
- `stale-branches` — lists branches with no commits in the last 90 days (excluding `main` / `develop`) and files a janitor issue. No auto-deletion.

### SAST (`.github/workflows/codeql.yml`)

GitHub CodeQL on JS/TS. Runs on every PR and weekly via cron — **not** on push-to-main/develop, because in a PR-based workflow the PR run covers the same code and a post-merge re-run would just double-count minutes. `workflow_dispatch` is enabled so you can re-run manually without pushing an empty commit.

### Supply-chain (`.github/workflows/scorecard.yml`)

OSSF Scorecard runs on push-to-main, weekly via cron (off-cycle from CodeQL), on `branch_protection_rule` events (regression catcher), and on `workflow_dispatch`. SARIF reports land in the GitHub Security tab; the public score is hosted at `scorecard.dev` and renders the badge at the top of this README. Complements CodeQL — CodeQL is SAST on the source, Scorecard is configuration / process scanning on the repo itself (catches branch-protection drift, unpinned action SHAs, missing signed releases, dangerous-workflow patterns).

### GitHub Pages (`.github/workflows/pages.yml`)

Deploys the frontend app and Storybook as a static site on every push to `main`:

| Path          | Content                                          |
| ------------- | ------------------------------------------------ |
| `/`           | Frontend app (Vite build with `--base=/<repo>/`) |
| `/storybook/` | Storybook component library                      |

**Setup (one-time):** Go to repo `Settings → Pages → Source` and select **GitHub Actions**. The first push to `main` after that provisions the `github-pages` environment automatically.

> **Note:** The frontend is a static export — API calls won't work on GitHub Pages. The `VITE_API_URL` is set to a placeholder at build time (see the `env:` block on the `build-frontend` step in `.github/workflows/pages.yml`) to satisfy the Zod env validation.

### Repo-level security features

- **Secret Scanning** and **Dependabot Alerts** are enabled at the repo level — no workflow file needed. The `gitleaks` CI job (above) layers a generic-entropy rule + ~150 vendor token formats on top of native Secret Scanning's known-pattern catalogue, and the same scan runs locally in `.husky/pre-commit` so leaks fail at commit time, not at push time.
- **Renovate** is configured in `renovate.json`. Enable it by installing the **Renovate GitHub App** on the repo; dependency updates arrive grouped by ecosystem so you don't drown in PRs.

### Cache story

- **Nx Cloud (remote cache + self-healing)** is the primary cache when enabled (see "Nx Cloud configuration" below). Provides distributed task execution, cross-PR cache hits, and the `npx nx fix-ci` self-healing step wired into every gating job.
- **Local `.nx/cache` filesystem fallback** is always on via `.github/actions/setup-node-deps`. Keyed on `package-lock.json`, so any dep bump (Nx included) invalidates it. This is the only cache a **fresh fork** gets on day one — before Nx Cloud is configured — and it still turns warm `nx affected` runs into near-instant no-ops on unchanged projects. When Nx Cloud is enabled the two stack (filesystem L1, cloud L2) and don't conflict.

### Nx Cloud configuration

Nx Cloud is wired in via `nxCloudId` in `nx.json` and controlled from CI by two repo-level settings that must be set up once per fork (`Settings → Secrets and variables → Actions`):

| Name                    | Kind     | Required when Nx Cloud is active | Purpose                                                                                                                                                                                                                                                                                                    |
| ----------------------- | -------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NX_CLOUD_ACCESS_TOKEN` | Secret   | yes                              | Access token for your Nx Cloud workspace. Grab it from cloud.nx.app → your org → Workspace settings.                                                                                                                                                                                                       |
| `NX_CLOUD_ENABLED`      | Variable | yes                              | Kill switch. Set to `true` to use Nx Cloud; set to `false` to bypass it entirely. When `false`, `ci.yml` blanks `NX_CLOUD_ACCESS_TOKEN`, exports `NX_NO_CLOUD=true`, and skips the `nx-cloud start-ci-run` step — so `nx affected` runs everything locally on the GitHub runner with the filesystem cache. |

**Why the kill switch exists.** Nx Cloud's free plan has a monthly task budget. When you exceed it, the Nx Cloud org is disabled and every CI run fails at the first `nx-cloud start-ci-run` call with `This Nx Cloud organization has been disabled due to exceeding the FREE plan`. Until the quota resets (or you upgrade), CI is fully stuck. Flipping `NX_CLOUD_ENABLED` to `false` in repo settings takes CI off Nx Cloud immediately — no code change, no revert — and the pipeline keeps gating PRs from the local filesystem cache. Flip it back to `true` when quota resets.

Blanking `NX_CLOUD_ACCESS_TOKEN` alone is **not** enough: `nxCloudId` in `nx.json` is what `nx` uses to decide whether to talk to the cloud at all, and with a valid `nxCloudId` and no token it still tries to authorize and fails. The `NX_NO_CLOUD` env var is the documented escape hatch that bypasses `nxCloudId`; that's why `ci.yml` sets both.

### One-time setup for a new fork

1. Create (or adopt) an Nx Cloud workspace and copy its access token.
2. Add `NX_CLOUD_ACCESS_TOKEN` as an **Actions secret**.
3. Add `NX_CLOUD_ENABLED` as an **Actions variable** (not a secret — it's not sensitive) with value `true`.

Until step 2 is done, the filesystem cache described above still gives you most of the speedup. Until step 3 is done, Nx Cloud is effectively off regardless of step 2 (the env expression evaluates to empty).

---

## Database

### Schema and migrations

Schema changes live in **`db/migrations/`** as numbered SQL files (`001_initial.sql`, `002_add_roles.sql`, …). The migration runner at `scripts/migrate.ts` tracks which files have been applied in a `schema_migrations` table and only runs new ones.

```bash
npm run migrate          # apply all pending migrations
npm run migrate:status   # show applied vs pending
```

**How the schema gets loaded on first boot** depends on your setup path:

- **Docker path:** `db/schema.sql` is mounted into `/docker-entrypoint-initdb.d/` and auto-loaded on the **first** `docker compose up mysql`. It aggregates all migrations and marks them as applied in `schema_migrations`, so a subsequent `npm run migrate` is a no-op.
- **Native path:** `scripts/dev-setup-native.sh` pipes `db/schema.sql` through `mysql`. Same result — schema created, migrations marked as applied.
- **CI:** the e2e job loads `db/schema.sql` into the MySQL service container before tests run.

**After first boot**, use `npm run migrate` to apply new migration files. When you add a migration, also append its SQL to `db/schema.sql` and add an `INSERT IGNORE INTO schema_migrations` line so fresh databases stay in sync.

### Adding a new migration

1. Create `db/migrations/NNN_description.sql` (next number in sequence).
2. Write idempotent SQL (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, etc.).
3. Append the same SQL to `db/schema.sql` and add `INSERT IGNORE INTO schema_migrations (version) VALUES ('NNN_description.sql');`.
4. Run `npm run migrate` locally to apply it.

### Resetting the local database

The fastest path — drops every table, re-applies all migrations, then loads `db/seed.sql` for a predictable dev dataset. Works against both the Docker and native MySQL setups (it just runs SQL against the configured `DB_*`):

```bash
npm run db:reset
```

The script refuses to run when `NODE_ENV=production`. It's intentionally paranoid — destroying data on the wrong machine is worse than a false negative on a misconfigured laptop.

If you want to wipe at the OS / container level instead (e.g. you suspect MySQL itself is in a bad state, not just the schema):

```bash
# Docker path — wipes the container volume:
docker compose down -v && npm run setup

# Native path — drop the database and re-provision:
sudo mysql -e "DROP DATABASE steamdeck_dev;" && npm run setup
```

### Query safety

**Queries must use parameter placeholders** (`?` or `:named`). Never interpolate user input into SQL strings — `mysql2` is configured with `namedPlaceholders: true`.

---

## Environment Variables

Backend env is **validated at startup** by `apps/backend/src/config/env.ts` (Zod). The app refuses to start if any required variable is missing or malformed.

| Variable              | Required       | Default                 | Consumer         | Notes                                                                                                                                                                  |
| --------------------- | -------------- | ----------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NODE_ENV`            | no             | `development`           | backend          | `development` \| `test` \| `production`                                                                                                                                |
| `HOST`                | no             | `localhost`             | backend, e2e     | Backend bind host                                                                                                                                                      |
| `PORT`                | no             | `3000`                  | backend, e2e     | Backend bind port                                                                                                                                                      |
| `DB_HOST`             | **yes**        | —                       | backend, scripts |                                                                                                                                                                        |
| `DB_PORT`             | no             | `3306`                  | backend, scripts |                                                                                                                                                                        |
| `DB_NAME`             | **yes**        | —                       | backend, scripts |                                                                                                                                                                        |
| `DB_USER`             | **yes**        | —                       | backend, scripts |                                                                                                                                                                        |
| `DB_PASSWORD`         | **yes**        | —                       | backend, scripts | Use a strong value in any non-local env                                                                                                                                |
| `DB_ROOT_PASSWORD`    | docker-compose | —                       | docker-compose   | MySQL root password — only read by the dev `docker-compose.yml`. Must differ from `DB_PASSWORD` so leaking the app credential doesn't grant root on the dev container. |
| `DB_CONNECTION_LIMIT` | no             | `10`                    | backend          |                                                                                                                                                                        |
| `FRONTEND_URL`        | **yes**        | —                       | backend          | Exact CORS origin — no wildcards                                                                                                                                       |
| `VITE_API_URL`        | **yes**        | —                       | frontend         | Read by the frontend at build time                                                                                                                                     |
| `BASE_URL`            | no             | `http://localhost:4200` | frontend-e2e     | Where Playwright points the browser. Only override when running e2e against a non-default URL (staging, custom dev port).                                              |

> **`VITE_*` vars are public.** Anything in a `VITE_` variable is bundled into the frontend and visible to every user. Never put secrets there.

> **`DB_ROOT_PASSWORD` is dev-only.** It's referenced by `docker-compose.yml` to provision the local MySQL container's root account. The Zod schema in `apps/backend/src/config/env.ts` deliberately doesn't read it — production deployments should not provide it to the backend.

---

## Production Deployment

Generic checklist — adapt to your platform of choice.

1. **Build:**

    ```bash
    npm run build
    ```

    (Runs format/lint/typecheck/tests first, then builds every project. Drop to `npx nx run-many -t build` if you need to skip the gates.)

    Outputs land in `dist/apps/frontend` (static files) and `dist/apps/backend` (Node bundle).

2. **Set `NODE_ENV=production`.** This switches the error handler to a generic message (no stack traces leaked) and enables `trust proxy` so rate limiting works behind a load balancer.

3. **Inject env vars from a real secrets manager** (AWS Secrets Manager, GCP Secret Manager, Doppler, 1Password, Vault). Do **not** ship a `.env` file in your image.

4. **Set `FRONTEND_URL` to your real frontend origin** — CORS will reject anything else.

5. **Terminate TLS at your reverse proxy / load balancer**, and forward `X-Forwarded-*` headers so Express sees the real client IP.

    The backend calls `app.set('trust proxy', 1)` when `NODE_ENV=production` (see `apps/backend/src/main.ts`). The `1` is correct when there is **exactly one** proxy hop between the client and Node — the most common case (single ALB/ELB, single nginx, Fly/Render/Railway platform proxy). If your topology differs you **must** change the value, because Express uses it to decide which `X-Forwarded-For` entry to trust as the client IP — and `express-rate-limit` buckets requests by that IP, so a wrong value lets any client spoof their IP and bypass the rate limiter.
    - **No proxy** (Node directly on the public internet — rare): set `trust proxy` to `false`. `req.ip` will then come from the TCP socket, not `X-Forwarded-For`.
    - **Multiple proxies** (e.g. Cloudflare in front of nginx in front of Node): set to the exact hop count (`2` in that example) or use `'loopback, linklocal, uniquelocal'` plus any trusted upstream CIDRs. Do **not** use `true` — that trusts every hop, which is exactly the spoof path.
    - See the [Express `trust proxy` docs](https://expressjs.com/en/guide/behind-proxies.html) for the full option list.

6. **Serve the frontend as static files** behind a CDN (Cloudflare, CloudFront, Fastly). The frontend is a pure SPA — no Node runtime needed for the FE.

7. **Run database migrations** as part of your deploy pipeline: `npm run migrate` (see [Database](#database)).

8. **Monitor:** wire the two health endpoints to your platform:
    - **Liveness probe** → `/api/health/live` (cheap; failure = restart the instance).
    - **Readiness probe** → `/api/health/ready` (pings the DB; failure = stop routing traffic without restarting).
    - Avoid pointing liveness at `/ready` — a blipping DB will restart-loop healthy app processes.
    - `/api/health` is still served as an alias of `/ready` for older probes that haven't been updated.

---

## Security

This boilerplate ships with sane defaults, but **security is your responsibility before going live**. Run through this checklist on every fork:

- [ ] `helmet` is on with an explicit CSP — tighten `script-src` / `style-src` for your real app.
- [ ] `cors` is locked to `FRONTEND_URL`. Wildcards are never used.
- [ ] `express-rate-limit` is enabled (100 req/min/IP by default — tune for your traffic).
- [ ] `express.json` body limit is 100 KB. Raise per-route only if needed.
- [ ] All env vars are validated by Zod at boot — the app fails fast on missing config.
- [ ] Error responses do **not** leak stack traces in production.
- [ ] All MySQL queries use parameter placeholders. Audit any code that builds SQL strings.
- [ ] **No authentication is included.** Add a real auth layer before exposing protected data. Recommended: short-lived JWTs with refresh tokens, or signed sessions stored in Redis.
- [ ] HTTPS is enforced at your edge (load balancer / CDN).
- [ ] `trust proxy` is set when running behind a reverse proxy (already wired for `NODE_ENV=production`).
- [ ] Run `npm audit` before every release. Some transitive dev dependencies (`@module-federation/*`, `jsdom` via `@tootallnate/once`) currently flag CVEs but are **not shipped to production** — they only affect the dev tooling and tests. Verify with `npm ls <package>` if in doubt.
- [ ] Rotate `DB_PASSWORD` and any other secrets on a schedule.
- [ ] Never commit `.env`. It is gitignored — keep it that way. The `.husky/pre-commit` hook + `gitleaks` CI job will catch most accidental secret commits, but they're a backstop, not a substitute for not staging the file in the first place.

If you discover a vulnerability in this boilerplate, please **do not** open a public issue — report it privately per [`SECURITY.md`](./SECURITY.md) (GitHub's Private vulnerability reporting, under `Security → Advisories → Report a vulnerability`).

---

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the full guide — branches, commits, testing expectations, and the Storybook / CHANGELOG / shared-types rules. Before proposing a breaking change, consult [`docs/SEMVER.md`](./docs/SEMVER.md) for the public-surface contract and major-version triggers.

Security issues should be reported privately per [`SECURITY.md`](./SECURITY.md), **not** as public issues.

> **AI-generated code:** this repo tracks AI-written changes in two places:
>
> 1. An append-only log at `.ai-attribution.jsonl` — one JSON object per line, no inline comments. See `CLAUDE.md` for the schema.
> 2. **`CHANGELOG.md`** — every AI agent finishing a task **must** add an entry under `[Unreleased]` before reporting done. Human contributors are expected to do the same, but the rule is strictly enforced for agents.

---

## License

[MIT](./LICENSE) © Victor Vinci
