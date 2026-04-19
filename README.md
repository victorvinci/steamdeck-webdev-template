# Steamdeck Webdev Template

A full-stack Nx monorepo boilerplate with a React frontend, an Express backend, and MySQL — ready to fork for new projects.

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

---

## Table of Contents

- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Setup](#manual-setup)
- [Daily Development](#daily-development)
- [Testing](#testing)
- [Database](#database)
- [Environment Variables](#environment-variables)
- [Production Deployment](#production-deployment)
- [Security](#security)
- [Contributing](./CONTRIBUTING.md)
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

## Project Structure

```
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
│   │   └── src/
│   │       ├── config/         # env.ts (Zod-validated), db.ts (MySQL pool), logger.ts (Pino)
│   │       ├── errors/         # AppError base class + HTTP subclasses
│   │       ├── middleware/     # errorHandler, notFound, validate (Zod)
│   │       ├── routes/         # /api/health, /api/users, …
│   │       ├── services/       # Data access layer (SQL queries)
│   │       └── main.ts         # Entry (helmet, CORS, rate-limit, graceful shutdown)
│   └── backend-e2e/            # Backend integration tests (Jest)
├── libs/
│   ├── types/                  # @mcb/types — shared Zod schemas + inferred TS types
│   └── utils/                  # @mcb/utils — small dependency-free helpers
├── db/
│   ├── migrations/             # Numbered SQL migration files (001_initial.sql, …)
│   └── schema.sql              # Bootstrap script — aggregates migrations for first init
├── scripts/
│   ├── dev-setup.sh            # Idempotent dev bootstrap (auto-detects docker vs native mysqld)
│   ├── dev-setup-native.sh     # Native MySQL fallback used when docker is unavailable
│   └── migrate.ts              # Lightweight DB migration runner (reads db/migrations/)
├── .github/
│   ├── ISSUE_TEMPLATE/         # Bug report and feature request issue forms
│   ├── pull_request_template.md
│   ├── actions/                # Reusable composite actions (setup-node-deps, resolve-nx-base)
│   └── workflows/              # CI (ci.yml), scheduled checks (ci-scheduled.yml),
│                               #   CodeQL SAST (codeql.yml), auto-draft PRs (force-draft.yml),
│                               #   GitHub Pages deploy (pages.yml)
├── docker-compose.yml          # Local MySQL service
├── nx.json                     # Nx workspace config (plugins, namedInputs, targetDefaults)
├── tsconfig.base.json          # Root TypeScript config (path aliases: @mcb/types, @mcb/utils)
├── eslint.config.mjs           # ESLint flat config (module boundary enforcement)
├── renovate.json               # Renovate dependency automation (grouped by ecosystem)
├── lighthouserc.json           # Lighthouse CI assertions (weekly scheduled run)
├── commitlint.config.js        # Conventional Commits enforcement
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

- **Frontend** → http://localhost:4200
- **Backend** → http://localhost:3000
- **Health check** → http://localhost:3000/api/health (returns `{ status: "ok", db: "connected" }`)

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
| `npm run format`               | Prettier write across the whole repo                                                                                                          |
| `npm run format:check`         | Prettier check (CI-friendly, non-mutating)                                                                                                    |
| `npm run typecheck`            | `tsc --noEmit` across every project                                                                                                           |
| `npm run check`                | `format:check` + `lint` + `typecheck` + `test` in sequence — run this before every PR                                                         |
| `npm run check:affected`       | Same as `check`, but only on Nx-affected projects                                                                                             |
| **Unit tests**                 |                                                                                                                                               |
| `npm test`                     | All unit tests (all projects)                                                                                                                 |
| `npm run test:fe`              | Frontend tests (Vitest)                                                                                                                       |
| `npm run test:be`              | Backend tests (Jest)                                                                                                                          |
| `npm run test:types`           | `libs/types` tests                                                                                                                            |
| `npm run test:utils`           | `libs/utils` tests                                                                                                                            |
| **E2E tests**                  |                                                                                                                                               |
| `npm run e2e`                  | All e2e suites (`frontend-e2e` + `backend-e2e`)                                                                                               |
| `npm run e2e:fe`               | Frontend e2e only (Playwright)                                                                                                                |
| `npm run e2e:be`               | Backend e2e only (Jest)                                                                                                                       |
| **Database**                   |                                                                                                                                               |
| `npm run migrate`              | Apply pending database migrations from `db/migrations/`                                                                                       |
| `npm run migrate:status`       | Show which migrations are applied vs pending                                                                                                  |
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

```bash
npm test             # all unit tests
npm run e2e          # all e2e suites (frontend + backend)
npm run e2e:fe       # frontend e2e only (Playwright)
npm run e2e:be       # backend e2e only (Jest)
```

> First local e2e run: `npx playwright install` to fetch browser binaries. The e2e targets depend on `backend:serve` via Nx, so you don't need to start the backend yourself — but make sure your `.env` / MySQL are provisioned first (`npm run setup`).

---

## CI / CD

Three GitHub Actions workflows ship with the repo. Together they form a gating pipeline on every PR, a scheduled dependency/perf/housekeeping pipeline, and a SAST pipeline.

### Per-PR (`.github/workflows/ci.yml`)

Runs on every pull request (and on push to `main` / `develop` as the non-affected full variant). These jobs **gate** merges — a red check blocks the PR.

- `detect` — path-filter job that outputs `code` (any app/lib/config change) and `frontend` (frontend-specific change). Gates all heavy jobs — docs-only PRs pay only ~1 min (detect + ci-pass) while branch protection stays unblocked
- `check` — `format:check` + `nx affected -t lint typecheck test` + `nx affected -t build`, wrapped in an Nx Cloud CI run for distributed cache + self-healing. Uploads `dist/` as an artifact. Quality gates and build are merged into one job to avoid a redundant checkout + `npm ci` on a second runner
- `storybook-build` — ensures every story still compiles (skipped on backend-only changes via the `frontend` path filter)
- `e2e` — Playwright (frontend) + Jest (backend) against a real `mysql:8.4` service container, seeded from `db/schema.sql`
- `commitlint` — enforces Conventional Commits on the PR title (squash-merge makes the title the final commit)
- `attribution-guard` — fails the PR if `apps/` or `libs/` changed without a `CHANGELOG.md` entry. A missing `.ai-attribution.jsonl` append is logged as a warning but does **not** block the PR — human contributors aren't required to append, the log only tracks AI-authored changes
- `ci-pass` — aggregator status check. Point branch protection at this single job instead of listing every job by name. It passes when every upstream job succeeded or was intentionally skipped (e.g. `storybook-build` on a backend-only PR), and fails if any upstream job failed or was cancelled.

`storybook-build` and `e2e` only run on `pull_request` events — on `push` to `main` / `develop` they're skipped, because the PR that just squash-merged already ran them. `check` + `build` + CodeQL still run on push as belt-and-braces. Pushes whose only diff is `.ai-attribution.jsonl` skip CI entirely via `paths-ignore`; bundled two-commit pushes (work + attribution) still trigger CI because the work commit touches non-ignored files.

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

### GitHub Pages (`.github/workflows/pages.yml`)

Deploys the frontend app and Storybook as a static site on every push to `main`:

| Path          | Content                                          |
| ------------- | ------------------------------------------------ |
| `/`           | Frontend app (Vite build with `--base=/<repo>/`) |
| `/storybook/` | Storybook component library                      |

**Setup (one-time):** Go to repo `Settings → Pages → Source` and select **GitHub Actions**. The first push to `main` after that provisions the `github-pages` environment automatically.

> **Note:** The frontend is a static export — API calls won't work on GitHub Pages. The `VITE_API_URL` is set to a placeholder at build time to satisfy the Zod env validation.

### Repo-level security features

- **Secret Scanning** and **Dependabot Alerts** are enabled at the repo level — no workflow file needed.
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

Destroys all data:

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

| Variable              | Required | Default       | Notes                                   |
| --------------------- | -------- | ------------- | --------------------------------------- |
| `NODE_ENV`            | no       | `development` | `development` \| `test` \| `production` |
| `HOST`                | no       | `localhost`   | Backend bind host                       |
| `PORT`                | no       | `3000`        | Backend bind port                       |
| `DB_HOST`             | **yes**  | —             |                                         |
| `DB_PORT`             | no       | `3306`        |                                         |
| `DB_NAME`             | **yes**  | —             |                                         |
| `DB_USER`             | **yes**  | —             |                                         |
| `DB_PASSWORD`         | **yes**  | —             | Use a strong value in any non-local env |
| `DB_CONNECTION_LIMIT` | no       | `10`          |                                         |
| `FRONTEND_URL`        | **yes**  | —             | Exact CORS origin — no wildcards        |
| `VITE_API_URL`        | **yes**  | —             | Read by the frontend at build time      |

> **`VITE_*` vars are public.** Anything in a `VITE_` variable is bundled into the frontend and visible to every user. Never put secrets there.

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

6. **Serve the frontend as static files** behind a CDN (Cloudflare, CloudFront, Fastly). The frontend is a pure SPA — no Node runtime needed for the FE.

7. **Run database migrations** as part of your deploy pipeline: `npm run migrate` (see [Database](#database)).

8. **Monitor:** wire `/api/health` to your platform's health check.

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
- [ ] Never commit `.env`. It is gitignored — keep it that way.

If you discover a vulnerability in this boilerplate, please **do not** open a public issue — report it privately per [`SECURITY.md`](./SECURITY.md) (GitHub's Private vulnerability reporting, under `Security → Advisories → Report a vulnerability`).

---

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the full guide — branches, commits, testing expectations, and the Storybook / CHANGELOG / shared-types rules.

Security issues should be reported privately per [`SECURITY.md`](./SECURITY.md), **not** as public issues.

> **AI-generated code:** this repo tracks AI-written changes in two places:
>
> 1. An append-only log at `.ai-attribution.jsonl` — one JSON object per line, no inline comments. See `CLAUDE.md` for the schema.
> 2. **`CHANGELOG.md`** — every AI agent finishing a task **must** add an entry under `[Unreleased]` before reporting done. Human contributors are expected to do the same, but the rule is strictly enforced for agents.

---

## License

[MIT](./LICENSE) © Victor Vinci
