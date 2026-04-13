# Steamdeck Webdev Template

A full-stack Nx monorepo boilerplate with a React frontend, an Express backend, and MySQL — ready to fork for new projects.

See [CHANGELOG.md](./CHANGELOG.md) for release history.

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
| Backend       | Node.js 20+, Express 4, TypeScript                          |
| Database      | MySQL 8 (via `mysql2`)                                      |
| Validation    | [Zod](https://zod.dev)                                      |
| Security mw   | helmet, cors, express-rate-limit                            |
| Testing       | Vitest / Jest (unit), Playwright (e2e)                      |
| Component dev | Storybook                                                   |
| Linting       | ESLint + Prettier                                           |

---

## Project Structure

```
steamdeck-webdev-template/
├── apps/
│   ├── frontend/               # React + Vite + TanStack Router
│   │   ├── src/
│   │   │   ├── lib/api.ts      # Axios client (reads VITE_API_URL)
│   │   │   ├── routes/         # File-based routing
│   │   │   └── main.tsx        # Entry
│   │   └── .storybook/
│   ├── frontend-e2e/           # Playwright
│   ├── backend/                # Express REST API
│   │   └── src/
│   │       ├── config/env.ts   # Zod-validated env
│   │       ├── config/db.ts    # MySQL pool
│   │       ├── middleware/     # errorHandler, notFound, validate
│   │       ├── routes/         # /api/health, ...
│   │       └── main.ts         # Entry (helmet, CORS, rate-limit, body limits)
│   └── backend-e2e/            # Backend integration tests
├── libs/
│   ├── types/                  # @mcb/types — shared Zod schemas + inferred types
│   └── utils/                  # @mcb/utils — small dependency-free helpers
├── db/
│   └── schema.sql              # Initial DB schema (auto-loaded by docker-compose)
├── docker-compose.yml          # Local MySQL
├── scripts/dev-setup.sh        # Idempotent dev bootstrap
├── .env.example                # Template — copy to .env
├── nx.json                     # Nx workspace config
└── eslint.config.mjs
```

---

## Prerequisites

- **Node.js** ≥ 20.12.0
- **npm** ≥ 10.0.0
- **Docker** with the Compose plugin (for local MySQL). If you'd rather run MySQL natively, see [Manual Setup](#manual-setup).

---

## Quick Start

```bash
git clone git@github.com:victorvinci/steamdeck-webdev-template.git
cd steamdeck-webdev-template

# 1. Install JS dependencies
npm install

# 2. Bootstrap dev environment (creates .env, starts MySQL via docker compose,
#    waits for the DB to become healthy, and loads db/schema.sql).
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

If you don't want to use Docker:

1. **Install MySQL 8** locally and start it.
2. **Create a database and user:**

    ```sql
    CREATE DATABASE my_db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER 'my_user'@'localhost' IDENTIFIED BY 'change-me';
    GRANT ALL PRIVILEGES ON my_db_name.* TO 'my_user'@'localhost';
    FLUSH PRIVILEGES;
    ```

3. **Load the schema:**

    ```bash
    mysql -u my_user -p my_db_name < db/schema.sql
    ```

4. **Create your env file** and update credentials:

    ```bash
    cp .env.example .env
    ```

5. **Install and run:**

    ```bash
    npm install
    npm run dev
    ```

---

## Daily Development

All commands are defined in `package.json` — prefer them over raw `nx` invocations.

| Command                        | What it does                                  |
| ------------------------------ | --------------------------------------------- |
| `npm run dev`                  | Setup + run frontend and backend in parallel  |
| `npm run fe`                   | Frontend only (`http://localhost:4200`)       |
| `npm run be`                   | Backend only (`http://localhost:3000`)        |
| `npm run storybook`            | Storybook for the frontend                    |
| `npm run lint`                 | Lint every project                            |
| `npm run lint:fix`             | Lint + autofix                                |
| `npm run format`               | Prettier write                                |
| `npm run format:check`         | Prettier check (CI-friendly)                  |
| `npm run typecheck`            | `tsc --noEmit` across every project           |
| `npm test`                     | All unit tests                                |
| `npm run test:fe`              | Frontend tests                                |
| `npm run test:be`              | Backend tests                                 |
| `npm run check`                | Format check + lint + typecheck + all tests   |
| `npm run check:affected`       | Same, but only on Nx-affected projects        |
| `npm run build`                | Run `check`, then build every project         |
| `npx nx graph`                 | Visualize the project dependency graph        |
| `npx nx affected -t lint test` | Run only on projects affected by your changes |

---

## Testing

- **Unit tests** live next to source as `*.spec.ts(x)` — Vitest in the frontend / `libs/types`, Jest in the backend / `libs/utils`.
- **E2E tests** live in `apps/frontend-e2e` and `apps/backend-e2e` (Playwright).
- **Storybook stories** are mandatory for every new frontend component (`*.stories.tsx`, co-located).

```bash
npm test                       # all unit tests
npx nx e2e frontend-e2e        # frontend e2e
npx nx e2e backend-e2e         # backend e2e
```

---

## CI / CD

GitHub Actions is wired up in `.github/workflows/ci.yml`. On every pull request:

- `check` runs `format:check` + `nx affected -t lint typecheck test`
- `build` runs `nx affected -t build` and uploads `dist/` as an artifact
- `storybook-build` ensures every story still compiles
- `e2e` runs Playwright on the official Microsoft image
- `lighthouse` runs LHCI against the built frontend (see `lighthouserc.json`)
- `commitlint` enforces Conventional Commits on the PR title (squash-merge makes the title the final commit)
- `npm-audit` surfaces high-severity advisories (non-blocking)
- `attribution-guard` fails the PR if `apps/` or `libs/` changed without a `CHANGELOG.md` update
- **CodeQL** (`.github/workflows/codeql.yml`) runs GitHub's SAST on JS/TS, weekly + on every push and PR
- **Secret Scanning** and **Dependabot Alerts** are enabled at the repo level (no workflow file needed)

Pushes to `main` / `develop` run the non-affected (full) variants.

Renovate is configured in `renovate.json` — enable it by installing the **Renovate GitHub App** on the repo. Dependency updates arrive grouped by ecosystem so you don't drown in PRs.

**One-time setup**: add `NX_CLOUD_ACCESS_TOKEN` as an Actions secret (Settings → Secrets and variables → Actions) so Nx Cloud's remote cache works in pipelines. The token comes from your Nx Cloud workspace — `nxCloudId` in `nx.json` points to it.

---

## Database

- **Schema lives in `db/schema.sql`.** It's loaded automatically by `docker compose up mysql` on the **first** run (because it mounts into `/docker-entrypoint-initdb.d/`). On subsequent runs the volume is reused — re-running won't re-apply the schema.
- **To reset the local database** (destroys data):

    ```bash
    docker compose down -v
    npm run setup
    ```

- **No migration tool is bundled.** When you outgrow `schema.sql`, plug in [`db-migrate`](https://github.com/db-migrate/node-db-migrate), [`Knex migrations`](https://knexjs.org/guide/migrations.html), [`Prisma`](https://www.prisma.io/), or your tool of choice.
- **Queries must use parameter placeholders** (`?` or `:named`). Never interpolate user input into SQL strings — `mysql2` is configured with `namedPlaceholders: true`.

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

7. **Run database migrations** as part of your deploy pipeline (see [Database](#database)).

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

If you discover a vulnerability in this boilerplate, please open a **confidential** issue rather than a public one.

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
