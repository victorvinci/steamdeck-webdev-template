# Security Audit — v1.0.0 Pre-Release

**Scope:** full codebase (`apps/`, `libs/`, `scripts/`, `db/`, `docker-compose.yml`, `.github/**`, env files).
**Date:** 2026-04-20
**Branch:** `chore/v1.0.0-prep`
**Commit at audit time:** `a8866f9`
**Auditor:** Claude Opus 4.7 (automated review, human-directed)

## Executive summary

**No critical or high-severity vulnerabilities. Two medium, five low, three informational findings.** The codebase has unusually good security hygiene for a template (SHA-pinned actions, least-privilege `GITHUB_TOKEN`, CSP, helmet, named-placeholder SQL, Zod-at-the-boundary on both ends, scoped CORS, private-vulnerability-reporting advice in `SECURITY.md`). The medium findings are _template defaults operators will inherit by fork_, not active vulnerabilities in the repo itself.

`npm audit`: **0** vulnerabilities across 1,896 deps.

---

## MEDIUM

### M1 — `docker-compose.yml` reuses the app password as the MySQL root password

**Location:** `docker-compose.yml:11`

```yaml
MYSQL_PASSWORD: ${DB_PASSWORD}
MYSQL_ROOT_PASSWORD: ${DB_PASSWORD} # same value
```

**Impact:** if the application DB user's credentials leak, the attacker gets MySQL root (cross-database, `GRANT`, plugin load, etc.) on the dev container — not just the app schema. For a template this is inherited by every fork.

**Recommendation:** split into `DB_ROOT_PASSWORD` in `.env.example`; default the root password to a distinct random string (or document using `MYSQL_RANDOM_ROOT_PASSWORD=yes`).

### M2 — MySQL port published on all interfaces

**Location:** `docker-compose.yml:13`

```yaml
ports:
    - '${DB_PORT:-3306}:3306'
```

**Impact:** Docker's `HOST:CONTAINER` bind shorthand binds `0.0.0.0:3306`, making the dev DB reachable from any network the host is attached to (coffee-shop wifi, corporate LAN, etc.). Combined with M1 this is a shared-network takeover path on the dev machine.

**Recommendation:** bind explicitly to loopback: `'127.0.0.1:${DB_PORT:-3306}:3306'`.

---

## LOW

### L1 — `extract-changelog-section.sh` interpolates version into an awk regex

**Location:** `scripts/extract-changelog-section.sh:32` — `-v ver="$VERSION"` then `$0 ~ "^## \\[" ver "\\]"`.

**Impact:** a tag name containing awk-regex metacharacters (`.`, `*`, `[`, etc.) can match unintended sections. Tags are maintainer-controlled so the blast radius is self-inflicted release notes, but it's a needless sharp edge in a release-path script.

**Recommendation:** escape `ver` before building the regex, or use a literal string comparison (`index($0, "## [" ver "]") == 1`).

### L2 — `scripts/dev-setup-native.sh` interpolates `DB_PASSWORD` into SQL HEREDOC

**Location:** `scripts/dev-setup-native.sh:48-54`. The script blocks single-quote passwords (line 42) but backslash and double-quote are allowed. MySQL's default `sql_mode` treats `\` as an escape inside `'…'`, so `\'` breaks the literal.

**Impact:** script runs as the machine owner via `sudo mysql`, so this is a "shoot yourself in the foot" class issue, not a remote vulnerability. Still worth cleaning up.

**Recommendation:** expand the rejected-character set to include `\` and `"`, or pass the password via `MYSQL_PWD` env var and use a non-interpolated HEREDOC with `<<'SQL'`.

### L3 — `validate.ts` leaves caller-extra body fields on `req.body`

**Location:** `apps/backend/src/middleware/validate.ts:24` — `Object.assign(req[source], result.data)` merges parsed fields onto the original request object rather than replacing it.

**Impact:** Zod strips unknown keys from `result.data`, but the _original_ extras remain on `req.body` / `req.params`. Handlers that read `res.locals.validatedQuery` (the convention this codebase uses for the query branch) are fine; any future handler that iterates or spreads `req.body` would see unvalidated input. Also the current `Object.assign` path is a latent prototype-pollution surface if a schema ever includes a `__proto__` key.

**Recommendation:** mirror the `query` branch — store parsed data on `res.locals` (e.g. `res.locals.validated`) and require handlers to read from there.

### L4 — Client-controlled `x-request-id` flows straight into logs and response headers

**Location:** `apps/backend/src/main.ts:23-27`

```ts
const id = (req.headers['x-request-id'] as string) ?? randomUUID();
res.setHeader('x-request-id', id);
```

**Impact:** a malicious client can set `x-request-id` to arbitrary content (very long strings → log pollution / storage bloat; newlines → log-injection risk in downstream pipelines that aren't strictly JSON-aware; header-reflection vector). pino emits JSON so in-process log injection is contained, but `setHeader` will accept and echo any string.

**Recommendation:** validate — only accept `/^[a-zA-Z0-9-]{1,64}$/`, else replace with a fresh UUID.

### L5 — `renovate-config-validator` invoked via `npx --yes` without a version pin

**Location:** `.github/workflows/ci.yml:340` — `npx --yes --package renovate -- renovate-config-validator --strict`. Every other npx invocation in the workflows is version-pinned (e.g. `license-checker-rseidelsohn@4.4.2`, `@lhci/cli@0.14.x`). This one fetches the latest `renovate` on every PR that touches `renovate.json`.

**Impact:** if the `renovate` npm package is ever compromised, it executes inside a job with `contents: read` + code checkout but no write tokens — limited blast radius, but on supply-chain day zero you'd still run the bad code.

**Recommendation:** pin to a version (Renovate itself can bump it via a customManager entry, as the in-file comment already suggests — just do the first pin now).

---

## INFORMATIONAL

### I1 — `force-draft.yml` uses `pull_request_target` + a PAT

**Location:** `.github/workflows/force-draft.yml`. Currently safe: the workflow never checks out PR head code, and the only `run:` is `gh pr ready "$PR_URL" --undo`, where `PR_URL` comes from GitHub metadata (not user-controlled). The file comment already captures the invariant.

**Why noted:** `pull_request_target` is the #1 GitHub Actions foot-gun. Any future commit that adds a step reading PR-controlled data (title, body, branch name, file contents) to this workflow turns it into an RCE against the base repo with `FORCE_DRAFT_PAT` exposed.

**Recommendation:** add a prominent "DO NOT add steps that read PR-controlled input" banner to the top of the file, so a future contributor (or future AI) doesn't silently weaken the invariant.

### I2 — `trust proxy` is a template default, not a deployment guarantee

**Location:** `apps/backend/src/main.ts:18` — `app.set('trust proxy', isProd ? 1 : false)`.

**Why noted:** `1` is correct only when there is _exactly one_ proxy between the client and Node. Operators deploying behind zero proxies (direct exposure — rare but possible) or multiple hops (e.g. Cloudflare + nginx) get broken `req.ip` and rate-limiting that can be bypassed via `X-Forwarded-For` spoofing. This isn't documented in the repo.

**Recommendation:** add a paragraph to `README.md` (deployment section) or `docs/` explaining what to change when deploying behind a different proxy topology.

### I3 — Attribution JSONL guard checks line count, not JSON validity

**Location:** `.github/workflows/ci.yml:284` — the `attribution-guard` counts _added lines_ to `.ai-attribution.jsonl` but never parses them. An AI could satisfy the check by appending `{}` or an invalid JSON fragment.

**Why noted:** not a traditional security issue, but it weakens the audit-log guarantee `CLAUDE.md` promises.

**Recommendation:** pipe the added lines through `jq -c . > /dev/null` in the guard step; fail on parse errors.

---

## What was explicitly verified clean

- `npm audit` — 0 vulnerabilities (prod + dev, 1,896 deps).
- `.env` has never been committed (`git log --all -- .env` returns nothing); `.env.example` is the only env file tracked.
- No inline SQL string concatenation — all queries use named or positional placeholders (`apps/backend/src/services/users.service.ts`, `scripts/migrate.ts:96`).
- No `dangerouslySetInnerHTML` / `innerHTML` / `eval` / `Function()` / `document.write` anywhere in `apps/` or `libs/`.
- Frontend validates response shape at the network boundary (`ListUsersResponseSchema.parse` at `apps/frontend/src/lib/api/users.ts:20`).
- CORS: single-origin via validated URL, `credentials: true` only with that single origin (no wildcard-with-credentials anti-pattern).
- Helmet with strict CSP (`default-src 'self'`, `object-src 'none'`, `frame-ancestors 'none'`), referrer `no-referrer`, `x-powered-by` disabled.
- JSON + urlencoded body limits: `100kb` (DoS hardening).
- pino redacts `authorization`, `cookie`, `*.password`, `*.token`.
- Express error handler never leaks internals in production (`errorHandler.ts:24`).
- All third-party GitHub Actions are SHA-pinned with `# vX` comments for Renovate.
- Default `permissions: contents: read` on every workflow; per-job escalation is minimal and annotated.
- CodeQL enabled with `security-and-quality` queries; `dependency-review-action` blocks high-severity deps on PR.
- Weekly `npm audit` cron files a tracking issue on findings.
- SBOM generated on every release tag (`release.yml`).
- `SECURITY.md` advertises private vulnerability reporting and has a scope section.

---

## Suggested remediation order before tagging v1.0.0

1. **M1 + M2 together** — one `docker-compose.yml` edit (split root password, bind to loopback) + `.env.example` update + a CHANGELOG entry.
2. **L4** — add `x-request-id` validation in `main.ts`.
3. **L5** — pin `renovate` version in `ci.yml`.
4. **L3** — refactor `validate.ts` to use `res.locals` consistently; update the two call-sites that read parsed data.
5. **L1, L2, I3** — small script-hardening pass.
6. **I1, I2** — documentation only.

None of these block v1.0.0 in an absolute sense, but M1 and M2 are the kind of template-default issues external reviewers will call out the day the template is published publicly.
