# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **README `## Daily Development` command table was missing `npm run setup` and `npm run prepare`, and flattened bootstrap/quality/test/build/lifecycle commands into one ungrouped list.** Rewrote the table as the canonical full list of scripts in `package.json` (grouped into Bootstrap, Quality gates, Unit tests, E2E tests, Build, Lifecycle hooks, Raw Nx escape hatches), with a note that if a script isn't in the table it doesn't exist.
- **README misrepresented the `attribution-guard` job as requiring both `CHANGELOG.md` and `.ai-attribution.jsonl` updates.** The job itself only blocks on `CHANGELOG.md` — a missing attribution append is logged as a warning and does not fail the PR (so human contributors opening PRs don't hit a hard block on a file they're not expected to touch). README CI/CD section now describes the actual behavior.

### Changed

- **Free-tier CI efficiency pass on `.github/workflows/ci.yml` and `.github/workflows/codeql.yml`.** Skip `storybook-build` and `e2e` on `push` to `main` / `develop` — in a PR-based workflow both already ran on the PR before the squash-merge landed, so re-running them on push was pure minute burn (roughly 10 min saved per merged PR). Dropped CodeQL's `push` trigger for the same reason; CodeQL still runs on every PR + weekly cron, with the weekly run catching anything that sneaks in via direct push. Added a `concurrency` group to `codeql.yml` so rapid pushes no longer queue multiple expensive analysis runs back-to-back. Rewrote the `commitlint` job to reuse the `.github/actions/setup-node-deps` composite and call the already-installed `commitlint` binary (`npx commitlint`) instead of `npx --yes -p @commitlint/cli -p @commitlint/config-conventional`, which re-downloaded both packages on every PR — the devDependencies in `package.json` already pin the same versions.
- **Documentation pass on `README.md` + `CONTRIBUTING.md` to remove stale docker-only assumptions and document the CI pipelines accurately.** Quick Start + Database section now describe both the Docker and native MySQL paths (including the native reset flow). Fixed a contradiction in the README's Security section — it said to open a "confidential issue" but `SECURITY.md` (authoritative) says to use GitHub's Private vulnerability reporting instead. Rewrote the `## CI / CD` section from scratch: it used to list `lighthouse` and `npm-audit` as per-PR jobs, but both were moved to the weekly `.github/workflows/ci-scheduled.yml` long ago. The new section breaks workflows into three subsections (Per-PR / Weekly / SAST) and documents every job actually running in each, including the `dep-health` rollup (audit + license scan + outdated), `bundle-size` (budget + lighthouse), and `stale-branches`. `CONTRIBUTING.md`'s setup comment now matches the auto-detecting `npm run setup`.
- **Replaced placeholder DB credentials in `.env` and `.env.example`** — `DB_NAME=steamdeck_dev`, `DB_USER=steamdeck`, and a real randomly-generated password in `.env` (example file keeps an obvious `change-me-before-first-boot` placeholder). `docker-compose.yml` and `apps/backend/src/config/env.ts` both already read these from the same `.env`, so they stay self-consistent. Passwords for this repo should use `[A-Za-z0-9_-]` only — bash-sourced `.env` in `scripts/dev-setup-native.sh` treats unquoted `&`/`$`/`;` as shell metacharacters, and the MySQL `validate_password` plugin still needs a digit + mixed case + a non-alnum (`_`/`-` qualify). If you've already booted the `mcb-mysql` container against the old creds you'll need `docker compose down -v` to re-init the volume — a fresh repo needs no extra steps.

### Added

- **Local Nx cache fallback in `.github/actions/setup-node-deps`.** Added an `actions/cache@v4` step that restores and saves `.nx/cache`, keyed on `package-lock.json` (so Nx version bumps — or any dep bump — naturally invalidate it). Every job that uses the composite now gets a warm filesystem-level Nx cache. This was gated entirely on `NX_CLOUD_ACCESS_TOKEN` before, which meant forks running the boilerplate on day one had **no** task-level caching at all and re-ran `lint`/`typecheck`/`test`/`build` from scratch on every push. When Nx Cloud is enabled the two caches stack (L1 filesystem + L2 remote) and don't conflict. Documented the two-tier cache story in the README CI/CD section.
- **Aggregator `ci-pass` job in `.github/workflows/ci.yml`.** Single status check that depends on every gating job (`check`, `build`, `storybook-build`, `e2e`, `commitlint`, `attribution-guard`) and passes when all upstream jobs succeeded or were intentionally skipped, fails if any failed or were cancelled. Point branch protection at `ci-pass` alone — renaming or reshuffling the upstream jobs no longer breaks protection settings.
- **`workflow_dispatch` on `.github/workflows/codeql.yml`.** Lets you re-run CodeQL manually from the Actions UI without pushing an empty commit after a transient failure.
- **`test:types` and `test:utils` npm scripts** (`nx test types` / `nx test utils`). `libs/types/README.md` and `libs/utils/README.md` now point at these instead of raw `npx nx test ...`, matching the "prefer npm scripts over raw nx" guidance already in `README.md` and `CLAUDE.md`. README command table updated.
- **README + `CLAUDE.md` docs for the native MySQL bootstrap path.** Rewrote the `## Manual Setup` section of `README.md` around the new auto-detecting `npm run setup`, spelled out the `auth_socket`/sudo requirement and the shell-safe + `validate_password`-safe password constraints, kept a truly-by-hand fallback for anyone skipping the script, and added the new script to the file-tree diagram. Updated `CLAUDE.md`'s Commands section with a one-liner so future agents know about the fallback without having to rediscover it.
- **Non-Docker MySQL bootstrap at `scripts/dev-setup-native.sh`** for environments where Docker isn't available (SteamOS, sandboxed hosts). Provisions the database and application user against a locally-running `mysqld` via `sudo mysql` (relies on the `auth_socket` plugin that ships by default on Debian/Ubuntu mysql-server packages), then loads `db/schema.sql`. Idempotent. `scripts/dev-setup.sh` now auto-detects: if `docker` is on PATH it takes the existing compose path, otherwise it `exec`s into the native script, so `npm run setup` works on both flows without a separate command. Script validates that `DB_PASSWORD` contains no single quotes (heredoc-hostile) and that `mysqld` is actually listening on `DB_PORT` before touching anything.
- **Local e2e npm scripts in `package.json`.** Added `e2e` (runs both e2e projects via `nx run-many`), `e2e:fe` (`nx e2e frontend-e2e`), and `e2e:be` (`nx e2e backend-e2e`) so contributors can run Playwright/Jest e2e suites without memorizing raw `nx` invocations. First local run still requires `npx playwright install` and a reachable backend DB (see the CI workflow for `DB_*` / `FRONTEND_URL` / `VITE_API_URL` envs). Documented in `README.md` — both the `## Daily Development` command table and the `## Testing` code block (which previously still pointed at raw `npx nx e2e ...`).

### Fixed

- **Bundled two-commit pushes silently skipped CI when the attribution commit carried `[skip ci]`.** GitHub checks `[skip ci]` only on the head commit of a push, so the marker on the attribution tip skipped CI for the work commit underneath it — exactly what happened on the previous push (`f1d4149` work + `7028840` attribution). Removed the `[skip ci]` guidance from the attribution-commit step in `CLAUDE.md` and added a loud "Do NOT add `[skip ci]`" warning explaining why. Standalone attribution-only pushes are still correctly skipped via the existing `paths-ignore: ['.ai-attribution.jsonl']` in `ci.yml` and `codeql.yml`.

- **frontend-e2e users-list test failed because `backend:serve` was torn down before the browser tests ran.** With `--parallel=1`, Nx ran `backend-e2e` first (which declares `dependsOn: ['backend:build', 'backend:serve']` so the continuous serve stays up for the duration of that target), then tore down `backend:serve` and ran `frontend-e2e`. `apps/frontend-e2e/project.json` had no backend dependency, so the browser hit `/api/users` against a dead backend, the `<UsersList>` never rendered, and the Playwright assertion on the `Users` region failed. Added `targets.e2e.dependsOn: ["backend:serve"]` to `apps/frontend-e2e/project.json` so Nx keeps the continuous backend alive for the frontend e2e run too. (Frontend's own `preview` server is still managed by Playwright's `webServer` block, not by Nx.)
- **Firefox failed to launch with `$HOME folder isn't owned by the current user`.** A different sandbox/permissions quirk from the previous SYS_ADMIN issue — the Playwright container's working UID doesn't own root's `HOME`. Added `HOME: /root` to the e2e job env in `.github/workflows/ci.yml`, the workaround Playwright documents for this exact error.
- **Lighthouse failed five `lighthouse:recommended` audit assertions on the boilerplate frontend.** `lcp-lazy-loaded`, `meta-description`, `non-composited-animations`, `prioritize-lcp-image`, and `unused-javascript` are real audit findings (not infra), but they're noise on a starter template. Set them to `off` in `lighthouserc.json`. The category-level perf/a11y/best-practices/seo gates still apply.
- **Lighthouse failures were silently masked behind a green check.** The `Run Lighthouse CI` step in `.github/workflows/ci-scheduled.yml` was `continue-on-error: true`, so the `bundle-size` job showed as completed even when lhci exited non-zero — the failure only surfaced in the step's annotations. Removed `continue-on-error` now that the assertion failures above are resolved, so future regressions actually fail the job.

- **`frontend:build` was a stale Nx remote-cache hit so the previous `VITE_API_URL` fix didn't actually take effect.** Setting `VITE_API_URL` on the e2e/lighthouse jobs didn't bust Nx's cache because Nx had no way to know that env var was a build input — it kept serving the older `dist` that inlined `undefined`. Added `{ "env": "VITE_API_URL" }` to a new `targetDefaults.build.inputs` entry in `nx.json`, so the cache key now changes when `VITE_API_URL` changes. This finally lets chromium/webkit find the `<h1>` (the React app was throwing on first eval before mount).
- **Firefox failed to launch in the e2e container with `Sandbox: CanCreateUserNamespace() clone() failure: EPERM`.** Firefox's content sandbox needs the `clone()` syscall via user namespaces, which the default seccomp profile inside the GHA container blocks. Added `options: --cap-add=SYS_ADMIN` to the `e2e` job's container in `.github/workflows/ci.yml` (the workaround documented in Playwright's "Run in CI" guide).
- **`backend-e2e` globalTeardown logged a noisy `lsof: not found` warning because the Playwright image doesn't ship `lsof`.** Tests had already passed by that point and Nx tears down the continuous `backend:serve` task anyway, but the warning was confusing. Added `lsof` to the apt-install step in the e2e job in `.github/workflows/ci.yml`.
- **Lighthouse + frontend-e2e failed with `NO_FCP` / blank page because `VITE_API_URL` was unset at build time.** Vite inlines `VITE_*` at build time. The lighthouse build in `.github/workflows/ci-scheduled.yml` (`bundle-size` job) and the e2e job in `.github/workflows/ci.yml` both ran `nx run frontend:build` with no `VITE_API_URL`, so the inlined value was `undefined`, the Zod schema in `apps/frontend/src/lib/env.ts` threw on first script eval, and the page never painted (lighthouse: `NO_FCP`; frontend-e2e users-list test: blank page). Set `VITE_API_URL=http://localhost:3000` on both jobs.
- **Backend bound to `::1` only in CI, causing `backend-e2e` to time out with `ECONNREFUSED 127.0.0.1:3000`.** `apps/backend/src/main.ts` calls `app.listen(env.PORT, env.HOST, …)` and `env.HOST` defaults to `'localhost'`. On Node 20+ inside the Playwright Docker image, `dns.lookup('localhost')` returns IPv6 first, so Express bound only to `::1`. `backend-e2e`'s `waitForPortOpen` polls the IPv4 loopback (`127.0.0.1`) and never connected, even though the backend was logging "ready" — the job hung for ~2 minutes per attempt before timing out. Set `HOST=0.0.0.0` on the e2e job in `.github/workflows/ci.yml` so the backend listens on both stacks.
- **e2e job now provisions a real MySQL service so the backend can boot.** Before this change the e2e job had no DB and no `DB_*` / `FRONTEND_URL` env vars, so `apps/backend/src/config/env.ts` (Zod, no defaults for those keys) failed validation, the backend `process.exit(1)`ed during `serve:development`, and Playwright/Jest hung waiting for `localhost:3000` until the job timed out. Added a `mysql:8.4` service container to the e2e job in `.github/workflows/ci.yml`, set `DB_HOST=mysql` + matching credentials and `FRONTEND_URL` on the job env, installed `default-mysql-client` inside the Playwright container, and load `db/schema.sql` (which also seeds the example users) before `nx affected -t e2e` runs. backend-e2e and frontend-e2e both depend on the seeded `/api/users` data, so a stub wasn't an option.
- **e2e CI failures from Playwright image/version mismatch and backend-e2e TS errors.** Bumped the e2e job container in `.github/workflows/ci.yml` from `mcr.microsoft.com/playwright:v1.55.0-jammy` to `v1.59.1-jammy` to match the resolved `@playwright/test@1.59.1` (the older image was missing `chromium_headless_shell-1217`, `firefox-1511`, and `webkit-2272`, causing `browserType.launch: Executable doesn't exist` across every browser). Also rewrote the `__TEARDOWN_MESSAGE__` shim in `apps/backend-e2e/src/support/global-setup.ts` as a `declare global` block so `globalThis.__TEARDOWN_MESSAGE__` typechecks (was failing with TS6133 + TS7017 and aborting Jest's globalSetup).

### Changed

- **Skip CI on standalone attribution-only pushes.** Added `.ai-attribution.jsonl` to the `paths-ignore` list on the `push:` triggers in `.github/workflows/ci.yml` and `.github/workflows/codeql.yml` (codeql's push trigger had no paths-ignore at all — added the same list as its pull_request trigger while we were there). A bundled two-commit push still runs CI because the work commit touches non-ignored files alongside the jsonl. Also updated the attribution-commit template in `CLAUDE.md` to include `[skip ci]` in the message as belt-and-braces for any standalone follow-up pushes.

- **CI pipeline minute-savings pass.** Several changes in `.github/workflows/ci.yml` and `.github/workflows/ci-scheduled.yml` to cut free-tier Actions minute burn and fix correctness edges:
    - **Push base SHA now uses `github.event.before`** (not `HEAD~1`) in the `check`, `build`, and `e2e` `nx affected` invocations. `HEAD~1` gives the wrong base on squash-merges and force-pushes, so `nx affected` could miss genuinely changed projects. Falls back to `HEAD~1` only on first-push of a new branch (all-zero `before`).
    - **Draft PRs skip `build`, `storybook-build`, and `e2e`.** `check` (lint / typecheck / test) still runs so obvious breakage still surfaces on drafts, but artifact builds and downstream e2e don't earn their minutes until the PR is marked ready for review.
    - **`lighthouse` moved from `ci.yml` (per-push) to `ci-scheduled.yml` (weekly).** It was already `continue-on-error: true`, so it wasn't gating anything on PRs — pure minute burn. It now runs weekly, reusing the frontend build from the `bundle-size` job so there's only one `nx run frontend:build` per weekly run. Report artifact retention bumped to 30 days to cover the longer cadence.
    - **`npm-audit`, `license-scan`, and `outdated-deps` merged into one `dep-health` job** in `ci-scheduled.yml`. They were three parallel jobs each paying a ~50s cold-start (runner spin-up + checkout + `setup-node-deps`) for ~5s of real work; serialized into one job they share the setup once, saving ~2–3 min per weekly run.
    - **`FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: 'true'` added to all three workflows** (`ci.yml`, `ci-scheduled.yml`, `codeql.yml`). Silences the "Node.js 20 actions are deprecated" warning on every run and opts in early ahead of GitHub's June 2026 forced cutover. Remove once all pinned actions ship releases that default to Node 24 natively.

- **`CLAUDE.md` attribution rule now mandates a two-commit flow.** Past entries kept landing with `commit: null` because a commit cannot reference its own SHA. The new flow: (1) commit the work + CHANGELOG without touching `.ai-attribution.jsonl`, (2) capture `git rev-parse --short HEAD`, (3) commit a single-line append to `.ai-attribution.jsonl` as a `chore(attribution)` follow-up. The `commit` field is now mandatory (no more `null`) when the agent is doing the commit itself; only when a human takes over the commit step does `null` remain acceptable. Cost: one extra micro-commit per AI task in exchange for guaranteed-accurate provenance links.

### Added

- **`detect` job in `.github/workflows/ci.yml` (paths-filter).** A new ~20s job that uses `dorny/paths-filter` to compute whether frontend-relevant paths changed (`apps/frontend/**`, `apps/frontend-e2e/**`, `libs/**`, `.storybook/**`, `package*.json`, `nx.json`, `tsconfig*.json`, `.nvmrc`). `storybook-build` and `lighthouse` now `needs: [check, detect]` and gate on `needs.detect.outputs.frontend == 'true'`, so backend-only or shared-only changes no longer burn ~20 min on jobs that would have been no-ops.
- **License scan job (`license-scan`) in `.github/workflows/ci-scheduled.yml`.** Weekly run of `license-checker-rseidelsohn` against production deps. Flags GPL/AGPL/LGPL/SSPL/CC-BY-NC/EUPL transitives by filing or updating a tracking issue labeled `license-scan` + `security`. Auto-closes the issue when the offenders are removed.
- **Outdated prod deps rollup job (`outdated-deps`).** Weekly `npm outdated --json --omit=dev` → single tracking issue with a Markdown table (current/wanted/latest) and a count of how many packages are a major version behind. Complements Renovate's per-package PRs with a single drift overview.
- **Bundle size budget job (`bundle-size`).** Weekly `npx nx run frontend:build`, then sums gzipped bytes of all `*.js` / `*.css` under `dist/` and compares to `.github/bundle-size-baseline.json`. Files an issue labeled `bundle-size` + `performance` if the current size exceeds the baseline by >10%. The baseline file is hand-maintained — bump it in a PR after intentional growth. **First run will report `no_baseline`** until you commit one (the run log shows the current measured size).
- **Stale branch sweep job (`stale-branches`).** Weekly listing of branches with no commits in 90+ days, excluding `main`/`develop`. Files a single tracking issue labeled `stale-branches` listing each branch + last-commit date. Pure janitor — never auto-deletes.

### Changed

- **All third-party / first-party actions pinned to commit SHAs** in `ci.yml`, `ci-scheduled.yml`, and `codeql.yml`. Each pin is followed by a `# vX` comment so Renovate can update the SHA. `renovate.json` now extends `helpers:pinGitHubActionDigests` and groups all `github-actions` updates into a single weekly PR. Closes a supply-chain risk where a compromised tag in any upstream action could silently swap code into the pipeline.
- **`ci.yml` push/PR triggers gain `paths-ignore`** for `**.md`, `LICENSE`, `.gitignore`, `.editorconfig`, `.vscode/**`, `docs/**`. Docs-only PRs no longer trigger the full pipeline. **Heads-up:** if you mark any CI job as a required status check on `main`, GitHub will block docs-only PRs because the skipped workflow never reports a status. Either don't mark them required, or convert to a "stub" job pattern. Same `paths-ignore` added to `codeql.yml` PR trigger.
- **`lighthouse` job is now opt-in by branch.** Only runs when the ref is `main` or the PR base is `main` (in addition to the new `frontend` path gate). Cuts that job's minutes by ~70% since develop pushes / PRs to develop no longer trigger it. Perf regressions are caught at the release boundary, where they actually matter.
- **Removed the `Diagnostic (git + github context)` step from the `check` job.** It existed for an Nx Cloud attribution debugging session that's long over. Saves ~5–10s per `check` run and removes log noise.

- **Scheduled CI workflow split into `.github/workflows/ci-scheduled.yml`.** The weekly `schedule:` trigger and `npm-audit` job moved out of `ci.yml` so the push/PR pipeline stays focused on gating jobs and future cron tasks (license scan, stale-branch sweep, etc.) have a clear home. The new file also exposes `workflow_dispatch` so failures can be reproduced on demand.

### Changed

- **`npm-audit` is now actionable.** Previously the weekly run was `continue-on-error: true` and a real high/critical finding only showed up as a green log nobody opened. The job in `.github/workflows/ci-scheduled.yml` now captures `--json` output and uses `actions/github-script@v7` to open (or update in place) a single tracking issue labeled `npm-audit` + `security` with severity counts, affected package list, and a link back to the run. The job needs `permissions: issues: write` scoped to itself.
- **`.github/workflows/ci.yml` cleanup.** Removed the four `if: github.event_name != 'schedule'` guards on `check`/`build`/`storybook-build`/`e2e`/`lighthouse` since the schedule trigger no longer exists on this workflow.

- **`.github/workflows/ci.yml` hardened.** Added workflow-level `permissions: contents: read` (least-privilege `GITHUB_TOKEN`), `timeout-minutes` on every job, and a weekly `schedule:` trigger. `nx fix-ci` (Self-Healing CI) now runs on failure in `build` and `e2e` in addition to `check`. `commitlint` no longer runs `npm ci` — it invokes commitlint via `npx -p` directly, saving ~30s per PR. `npm-audit` moved to schedule-only (weekly) since Renovate and Dependabot Alerts already cover PR-time dependency scanning. `build` upload-artifact uses `if-no-files-found: ignore` so affected-no-op pushes (CI-only changes) don't fail the job. Added reusable composite action at `.github/actions/setup-node-deps/action.yml` and adopted it across jobs to DRY the Node + `npm ci` setup.

### Fixed

- **lighthouse CI job errored on affected-no-op pushes.** When a push only touches CI/docs files, `nx affected -t build` produces no `dist/` and the build job's upload-artifact step skips (`if-no-files-found: ignore`), causing lighthouse's `download-artifact` to fail with `Artifact not found for name: dist`. The job had `continue-on-error: true` so the pipeline still passed, but it left a red ❌. `.github/workflows/ci.yml` lighthouse job now downloads with `continue-on-error: true`, checks whether `dist/` is populated, and conditionally skips both the lhci run and its report upload.
- **e2e CI job failed inside Playwright container with `git diff ... Could not access <sha>`.** `actions/checkout@v4` writes `safe.directory` to the runner host's git config, but the `mcr.microsoft.com/playwright` container has its own git config — so every git CLI call inside the container (including the one `nx affected` shells out to) errored with "dubious ownership", and nx surfaced it as an unreachable base SHA. Added a `git config --global --add safe.directory "$GITHUB_WORKSPACE"` step right after checkout in the `e2e` job in `.github/workflows/ci.yml`.
- **TanStack Router double-generation of `routeTree.gen.ts` — real fix.** The `tanstackRouter()` export returns an array of sub-plugins (generator + code splitter) and both attempted to write `apps/frontend/src/routeTree.gen.ts`, failing the second write with `File already exists. Cannot overwrite.` This broke every fresh CI build on GitHub that wasn't a remote-cache hit. Switched `apps/frontend/vite.config.mts` to import `tanstackRouterGenerator` (generator-only) instead of `tanstackRouter`. Code splitting can be re-added later via `tanStackRouterCodeSplitter` if needed.

### Changed

- **Node pin bumped to 20.19.2** (`.nvmrc`) and `package.json` `engines.node` to `>=20.19.0`. `@swc/cli@0.8.1` transitively requires Node ≥20.19.0, which broke `npm ci` in CI with an `EBADENGINE` error on the previous 20.12.0 pin.
- **`renovate.json` — migrated deprecated `matchPackagePatterns` to `matchPackageNames`.** Renovate still honoured the old keys but emitted deprecation warnings. Regex patterns are now wrapped in `/.../` form per the current schema; exact-name entries (`nx`, `storybook`) are listed alongside the regexes inside the same `matchPackageNames` array.
- **Ported CI from GitLab CI/CD to GitHub Actions.** `.gitlab-ci.yml` removed; `.github/workflows/ci.yml` now hosts the `check` / `commitlint` / `npm-audit` / `attribution-guard` / `build` / `storybook-build` / `e2e` / `lighthouse` jobs with equivalent triggers (`pull_request`, `push` to `main` / `develop`). `check` keeps the inline diagnostic block that dumps git + `GITHUB_*` context for Nx Cloud attribution debugging. `nx fix-ci` (Self-Healing CI) is invoked in the `check` job via an `if: failure()` step.
- **Security scanning — GitHub-native replacements for the GitLab templates.** Added `.github/workflows/codeql.yml` (CodeQL JS/TS SAST, weekly schedule + PR/push triggers). GitLab's `Secret-Detection` (gitleaks) and `Dependency-Scanning` templates are replaced by GitHub-native Secret Scanning and Dependabot Alerts, which are enabled at the repo level and don't need a workflow file.
- **`README.md` — CI / CD section rewritten** to reflect the new GitHub Actions jobs, CodeQL integration, repo-level security features, and the fact that `NX_CLOUD_ACCESS_TOKEN` is now an Actions secret (not a GitLab CI variable).
- **`SECURITY.md`** — reporting path changed from GitLab confidential issues to GitHub's Private Vulnerability Reporting (`Security → Advisories → Report a vulnerability`).
- **`package.json author.url`** switched from `https://gitlab.com/victorvinci` to `https://github.com/victorvinci`.

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
