# Forking this template

This template markets itself as fork-friendly. That means more than "the code compiles" — it means a new fork can get from `Use this template` → green CI → first real commit without reverse-engineering undocumented manual steps. This document walks through exactly what a fresh fork needs.

`scripts/rename-template.sh` mechanizes the file-level rename (the boring sed sweep). Everything else — repo settings, external services, branch rulesets — has to happen in the GitHub UI or third-party dashboards; those are listed below with links.

Expect the first walk-through to take 30-60 minutes. Subsequent forks should be faster once you know which external services you personally use.

---

## Step 1 — Create the fork

Click **Use this template** on GitHub (not `Fork`). A template-derived repo is a fresh project with no upstream link, which is what you want. `Fork` creates a real fork that tracks upstream and inherits issues/PRs/stars, which you don't want for a new project.

Clone it locally:

```bash
git clone git@github.com:<your-handle>/<your-repo>.git
cd <your-repo>
npm install
```

The `npm install` step is needed so `npm run check` (called at the end of the rename script) has its dependencies.

---

## Step 2 — Run the rename script

```bash
./scripts/rename-template.sh \
    --project-name     <your-repo-name> \
    --github-owner     <your-gh-handle> \
    --npm-scope        <your-npm-scope> \
    --maintainer-email <your-email>
```

The script rewrites four categories across an explicit allowlist of files:

| Category         | Example                      | Files touched                                                                                               |
| ---------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Project name     | `steamdeck-webdev-template`  | `package.json`, `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `docs/RELEASE.md`, `.github/workflows/ci*.yml` |
| GitHub owner     | `victorvinci`                | `package.json`, `.github/CODEOWNERS.txt`, `README.md`, `CONTRIBUTING.md`                                    |
| npm scope        | `@mcb/types`, `@mcb/utils`   | `tsconfig.base.json` + 7 source files importing `@mcb/*`                                                    |
| Maintainer email | `victorvinci@protonmail.com` | `CODE_OF_CONDUCT.md`                                                                                        |

Historical records (`CHANGELOG.md`, `.ai-attribution.jsonl`, `docs/SECURITY-AUDIT-v1.0.0*.md`) are **not** rewritten — they're point-in-time records and should keep the original names for audit traceability.

The script runs `npm run format` and `npm run check` at the end; both must pass before you commit. If check fails, fix by hand or re-run with corrected arguments.

```bash
git diff
git add -A && git commit -m 'chore: rename template'
```

---

## Step 3 — Manual file cleanups the script can't mechanize

### `.github/CODEOWNERS.txt`

The script rewrites `@victorvinci` to `@<github-owner>`. If your fork has multiple reviewers, edit the file to list them. If you don't want CODEOWNERS enforcement at all, delete the file — see the `main` ruleset note in Step 5 before doing so.

### `README.md` Steam Deck preamble

The top-of-README notice about Distrobox and Steam Deck host helpers is specific to the maintainer's setup. If you're not on a Steam Deck, delete the block bounded by `> **Built on a Steam Deck`...`> Both scripts have their own changelog`. The scripts themselves live in `scripts/steamdeck/` and are opt-in — either strip the directory or leave it as dead code.

### Live-demo links

`README.md` points at `https://<github-owner>.github.io/<project-name>/` for the demo site. After the rename this points at your fork — but the site won't exist until you enable Pages (Step 5). If you're not using Pages, remove the **Live demo** line.

### Sample Users domain

The repo ships a worked `/users` example across `apps/backend/src/{services,routes}/users.*`, `apps/frontend/src/{routes,lib/api}/users.*`, `apps/frontend/src/components/UsersList.*`, and `db/schema.sql`. Keep it as reference while you learn the patterns, then strip it when you start your own domain. Grep for `users` under `apps/` + `db/` to find everything.

### Contributor Covenant contact

`CODE_OF_CONDUCT.md` adopts Covenant 2.1 by reference. After the rename, double-check the maintainer-email line reads correctly — Covenant reports land in whatever inbox you set.

---

## Step 4 — Repository settings (GitHub UI)

### Enable GitHub Pages (if you want the live demo + Storybook)

1. `Settings → Pages`
2. Source: **GitHub Actions**
3. First push to `main` triggers `.github/workflows/pages.yml`, which deploys both the frontend app and Storybook.

If you don't want Pages, either disable the `pages.yml` workflow (`Settings → Actions → Disable actions` on just that workflow) or delete the file.

### Enable Private Vulnerability Reporting

`Settings → Code security → Private vulnerability reporting → Enable`. `SECURITY.md` points at this; without it enabled the "Report a vulnerability" flow in the Security tab is unavailable.

### Package publishing permission

The `playwright-image` job in `.github/workflows/ci.yml` pushes a Playwright base image to `ghcr.io/<owner>/playwright-e2e` to speed up e2e runs. GitHub Actions needs package-write permission for this:

`Settings → Actions → General → Workflow permissions → Read and write permissions` (plus allow GitHub Actions to create packages under `Settings → Actions → General`).

First successful push makes the package visible under `<owner>/packages`; mark it public or leave private based on your preference.

---

## Step 5 — Branch rulesets

The release workflow (`docs/RELEASE.md`) depends on specific rulesets on `develop`, `main`, and the `v*` tag namespace. Rulesets are stored server-side at the GitHub org/repo level — they're **not** in any file in this repo, so a fresh fork has zero rulesets until you recreate them.

Full table with the ruleset names and their required bypass lists is in [`docs/RELEASE.md`](./RELEASE.md#branch-rulesets). The short version:

| Ruleset        | Protects         | Key rules                                                                                          |
| -------------- | ---------------- | -------------------------------------------------------------------------------------------------- |
| `develop`      | `develop` branch | Require PR, required linear history, required status checks (`ci-pass`), require signed commits    |
| `main`         | `main` branch    | Require PR, required linear history, required status checks (`ci-pass`), require code-owner review |
| `release-tags` | Tag names `v*`   | Tag creation restricted to maintainers (so random contributors can't cut releases)                 |

Set these up via `Settings → Rules → Rulesets → New ruleset` for each. If you delete `CODEOWNERS.txt` (Step 3), drop the code-owner-review rule from the `main` ruleset.

---

## Step 6 — External services (optional but wired in)

### Nx Cloud (remote cache + self-healing CI)

Already documented in [`README.md` → "Nx Cloud configuration"](../README.md#nx-cloud-configuration). Short version:

1. Create an Nx Cloud workspace at [cloud.nx.app](https://cloud.nx.app), grab its access token.
2. Update `nxCloudId` in `nx.json` to match your workspace — the value currently there points at this template's workspace and your runs will fail until you change it.
3. Add `NX_CLOUD_ACCESS_TOKEN` as an Actions **secret** (`Settings → Secrets and variables → Actions → New repository secret`).
4. Add `NX_CLOUD_ENABLED` as an Actions **variable** (same screen, "Variables" tab) with value `true`.

Until you do this, CI falls back to the filesystem `.nx/cache`, which is correct but loses cross-PR cache hits and the self-healing step.

### Renovate (dependency PRs)

`renovate.json` is in the repo, but Renovate is a GitHub App that must be installed separately:

1. Install the [Renovate GitHub App](https://github.com/apps/renovate) on your new repo.
2. Renovate auto-detects `renovate.json` on first scan and opens an "onboarding" PR. Merge it to activate.

Without this step, `renovate.json` is inert — dependency updates will stagnate.

### Dependabot

Dependabot is native to GitHub and respects `.github/dependabot.yml` if present. This template currently does not ship a `dependabot.yml` (Renovate is the primary). If you'd rather use Dependabot, write one and delete `renovate.json`.

---

## Step 7 — Signed commits

`docs/RELEASE.md` and `CONTRIBUTING.md` assume commits are signed (both the `develop` and `main` rulesets in Step 5 enforce this). If you haven't already:

1. Configure an SSH or GPG signing key. GitHub's [Telling Git about your signing key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key) is the canonical walkthrough.
2. Upload the public half to `Settings → SSH and GPG keys`.
3. Verify locally: `git commit -m 'test' --allow-empty` → `git log --show-signature -1` should report `Good signature`.

If you skip this, the rename commit from Step 2 will be rejected when you push against a `develop` ruleset that requires signed commits.

---

## Step 8 — First CI run

Push the rename commit:

```bash
git push -u origin main
```

Expected behavior on first push:

- `.github/workflows/ci.yml` runs all gating jobs (lint, typecheck, test, e2e, build, attribution-guard, pr-size, etc.)
- `ci-pass` aggregates them into a single check, which is what you should wire into your branch protection as the required check
- `.github/workflows/pages.yml` runs if Pages is enabled (Step 4)
- `.github/workflows/release.yml` does NOT run — it's tag-triggered

If CI is red on first push: the `Self-Healing CI` step (visible inside each job's logs) will propose fixes for recoverable failures. For non-recoverable failures, open the job logs; the common first-run failures are:

- **Nx Cloud 401**: `nxCloudId` in `nx.json` still points at the template's workspace. Update it (Step 6) or blank it.
- **attribution-guard red**: the rename commit has no `Co-Authored-By:` trailer, so no JSONL entry is expected, and the guard should pass. If it's red, check whether your signing key ended up adding a `Co-Authored-By:` trailer.
- **e2e red on missing MySQL service**: the e2e job uses MySQL as a GitHub Actions service. If you've customized the job, make sure the service is still declared.

---

## Step 9 — Strip what you don't need

After the walk-through, some boilerplate will be dead weight for your project. A conservative pruning list:

- `scripts/steamdeck/` — Steam Deck host helpers, unrelated to the web template
- The Steam Deck preamble in `README.md` (Step 3)
- The sample `/users` domain (Step 3) once you've copied the pattern for your own resource
- `.github/workflows/pages.yml` if you're not using GitHub Pages
- `docs/SECURITY-AUDIT-v1.0.0*.md` — template's pre-release audit, not yours; keep or archive as you prefer, but it's not load-bearing for your fork's security story

Leave `CLAUDE.md` alone until you've read it — it codifies the AI-attribution and CHANGELOG rules that `attribution-guard` enforces. If you're not using AI coding assistants, you can simplify it, but the CHANGELOG rule on its own is still worth keeping.

---

## Step 10 — Real first commit

Once CI is green on the rename:

1. Make a trivial real change (e.g. bump the README with your project description).
2. Run `npm run check` locally.
3. Commit with a `Co-Authored-By: <your-model-id>` trailer if an AI assistant helped, then append a line to `.ai-attribution.jsonl` per the schema in `CLAUDE.md`.
4. Push. Green CI on this commit means the template is wired up end-to-end for your fork.

You're off the template and onto your project.

---

## Troubleshooting

### The rename script says "Refusing to run with uncommitted changes"

Commit or stash your work first. If you're iterating on the script itself (not the usual case for a fresh fork), pass `--force-dirty` to bypass the guard.

### `npm run check` fails after the rename

Most common cause: you chose an `--npm-scope` that conflicts with an existing published package name (e.g. `@types`, `@nx`). Check `tsconfig.base.json` — the aliases must resolve to `./libs/types/src/index.ts` and `./libs/utils/src/index.ts`. If the aliases look right but TypeScript can't resolve them, clear `node_modules/.cache` and the Nx cache:

```bash
rm -rf node_modules/.cache .nx/cache
npm run check
```

### CI is red on the first push with a cryptic Nx Cloud error

See Step 8's `nxCloudId` note. The fastest fix is blanking `nxCloudId` in `nx.json` entirely and not using Nx Cloud until Step 6 is done.

### I want to re-run the rename with different values

The script is idempotent only for the **same** input. If you ran it once and the values are wrong: `git reset --hard HEAD~1` (if you haven't pushed yet) or `git revert` the rename commit, then re-run with corrected args.
