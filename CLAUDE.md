# steamdeck-webdev-template

Nx monorepo: React + Vite + TanStack Router frontend, Express backend, shared `types` and `utils` libs.

## Layout

- `apps/frontend` — React app (Vite, TanStack Router, Storybook in `.storybook/`)
- `apps/backend` — Express API (TypeScript, error classes in `errors/`, service layer in `services/`)
- `apps/frontend-e2e`, `apps/backend-e2e` — Playwright e2e
- `libs/types` — shared TS types & Zod schemas (Vitest)
- `libs/utils` — shared utilities (Jest)
- `db/` — `schema.sql` (bootstrap aggregator) + `migrations/` (numbered SQL files)
- `scripts/migrate.ts` — lightweight migration runner (`npm run migrate`)
- `.github/actions/` — composite GitHub Actions (e.g. `resolve-nx-base`)

## Commands

Always prefer the npm scripts in `package.json` over raw `nx` invocations — they are the source of truth and may evolve.

- Install + first-run setup: `npm run setup` (auto-detects Docker — falls back to `scripts/dev-setup-native.sh` on hosts without Docker, which provisions MySQL via `sudo mysql` auth_socket; see README → Manual Setup for password constraints)
- Run both apps: `npm run dev`
- Frontend only: `npm run fe` • Backend only: `npm run be`
- Storybook: `npm run storybook`
- Lint: `npm run lint` • Autofix: `npm run lint:fix`
- Format: `npm run format` • Check: `npm run format:check`
- Typecheck: `npm run typecheck`
- Test all: `npm test` • Frontend: `npm run test:fe` • Backend: `npm run test:be`
- All gates in one go: `npm run check` (format:check + lint + typecheck + test)
- Affected-only gates: `npm run check:affected`
- Build everything (runs `check` first): `npm run build`
- Clean build artifacts: `npm run clean`
- DB migrations: `npm run migrate` (apply pending) • `npm run migrate:status` (show applied vs pending)

Only drop to raw `npx nx ...` when no script covers what you need (e.g. `npx nx affected -t lint test` during iteration). If you find yourself reaching for raw nx repeatedly, propose adding a script instead.

## Conventions

- TypeScript everywhere; no `any` without justification.
- Shared code goes in `libs/`, not duplicated across apps.
- Frontend tests use Vitest where configured, backend uses Jest — match the project's existing setup.
- e2e changes go in the matching `*-e2e` app.
- **Storybook stories are mandatory for every new frontend component.** Each new component under `apps/frontend` must ship with a co-located `*.stories.tsx` covering at least the default state and any meaningful variants (loading, error, empty, disabled, etc.). No story = the component is not done. This applies to AI-generated and human-written components alike.

## AI attribution rule (IMPORTANT)

We track AI-generated code in an append-only JSONL log at `/.ai-attribution.jsonl` — **not** via inline comments. Inline markers were tried first and proved too noisy; the log keeps source files clean while preserving provenance.

**When to append an entry:** any time an AI assistant writes or substantively edits code in this repo. Rewording a comment or renaming a single variable does not count; adding/changing logic, configuration, or docs does.

**How to append:** add **exactly one line** to `/.ai-attribution.jsonl`. One JSON object per line, no pretty-printing. The file is in `.prettierignore` so formatters leave it alone — keep it that way.

**Schema:**

```json
{
    "date": "YYYY-MM-DD",
    "model": "claude-opus-4-6",
    "scope": "short-slug",
    "description": "one-sentence summary",
    "files": ["path/one.ts", "path/two.ts"],
    "commit": "abc1234"
}
```

- `date` — ISO date of the change.
- `model` — exact model ID (e.g. `claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5`). Check the runtime, do not guess.
- `scope` — short slug tying related changes together (e.g. `hardening-pass-0.1.0`, `add-auth`, `fix-health-route`).
- `description` — one sentence, what changed and why.
- `files` — every file the AI touched **in the work commit** (do NOT include `.ai-attribution.jsonl` itself — it lives in the follow-up commit).
- `commit` — short SHA (7+ chars) of the commit containing the actual work, filled in by the agent **after** the work commit lands. See the two-commit flow below.

**Two-commit flow (MANDATORY when committing):**

A commit cannot reference its own SHA, so the JSONL entry is appended in a separate follow-up commit immediately after the work commit. This guarantees the `commit` field always points to a real, existing SHA — no `null`s, no off-by-one drift from amends.

When the user asks you to commit your work:

1. **Work commit.** Stage and commit everything _except_ `.ai-attribution.jsonl`. The work commit must include `CHANGELOG.md` (per the CHANGELOG rule below) and use the standard `Co-Authored-By: <model-id>` trailer.
2. **Capture the SHA.** Run `git rev-parse --short HEAD` immediately after step 1. That short SHA is what goes in the `commit` field.
3. **Attribution commit.** Append the JSONL line with the SHA from step 2, then commit just `.ai-attribution.jsonl` with a short message like `chore(attribution): log <scope>`. Same `Co-Authored-By` trailer applies. **Do NOT add `[skip ci]` to this message** — GitHub checks `[skip ci]` only on the head commit of a push, so a `[skip ci]` marker on the attribution tip silently skips CI for the work commit underneath it in the bundled two-commit push. Standalone attribution-only pushes are already skipped via `paths-ignore: ['.ai-attribution.jsonl']` in `ci.yml` and `codeql.yml`, which correctly only skips when _every_ changed path matches — bundled pushes still trigger CI because the work commit touches non-ignored files.
4. **Push both together** (a single `git push` after step 3 sends both commits).

If the user is _not_ asking you to commit (e.g. you're just editing files on a feature branch they'll commit themselves), append the JSONL line with `"commit": null` and let the human fill it in when they commit, or fill it in yourself in a follow-up turn after they confirm the SHA.

**Rules:**

- Never reformat `.ai-attribution.jsonl`. One line = one entry. This is what makes it merge-safe across branches.
- Never delete entries. This is an audit log, not scratch space. Corrections go in a new entry.
- Do **not** add inline `// ai: …` comments in source files. The log is the single source of truth.
- When multiple branches each append one line and hit a merge conflict, resolve by keeping both lines — not by picking one.
- The attribution commit is intentionally tiny and outside the work commit. Do **not** try to amend the work commit to include the JSONL entry — amending changes the SHA and breaks the field you just wrote.

Human contributors can read the log to see exactly what an AI touched and when. `jq` works natively on JSONL: `jq -s '.' .ai-attribution.jsonl` reads the whole file as an array.

## CHANGELOG rule (MANDATORY for every agent)

**Every AI agent, on every task, must update `CHANGELOG.md` before reporting the task as done.** No exceptions — not even for "tiny" fixes, typo corrections, or one-line tweaks. If you touched the repo, you log it.

- Add entries under the `## [Unreleased]` section at the top. Create that section if it doesn't exist (put it above the most recent version).
- Use the Keep-a-Changelog subsection headings that apply: `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`.
- Each entry is one or two sentences. Mention the file(s) touched inline so reviewers can jump straight to them. Example: `- **Fixed** stale CORS origin fallback in \`apps/backend/src/main.ts\` — previously fell through to \`localhost:4200\` if \`FRONTEND_URL\` was unset.`
- When a release is cut, the human maintainer promotes `[Unreleased]` to a versioned section with a date. Do not do this yourself unless explicitly asked.
- This rule is **in addition** to the `.ai-attribution.jsonl` append rule above. You must update **both**: the JSONL log tracks provenance (who/when/what files), the CHANGELOG tracks user-facing impact (what changed and why it matters). They are not redundant.
- If you finish a task without updating CHANGELOG, you have not finished the task.

## Commit attribution rule (MANDATORY for every agent)

Every commit an AI agent creates **must** name the model in the commit message trailer. Use a `Co-Authored-By` line with the exact model ID:

```
Co-Authored-By: claude-opus-4-6
```

Use the actual model ID at runtime (`claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5`, …) — do not guess. This is in addition to (not a replacement for) the `.ai-attribution.jsonl` log and the CHANGELOG entry. Human reviewers should be able to tell from `git log` alone which commits were AI-authored and by which model.

<!-- nx configuration start-->
<!-- Leave the start & end comments to automatically receive updates. -->

## General Guidelines for working with Nx

- For navigating/exploring the workspace, invoke the `nx-workspace` skill first - it has patterns for querying projects, targets, and dependencies
- When running tasks (for example build, lint, test, e2e, etc.), always prefer running the task through `nx` (i.e. `nx run`, `nx run-many`, `nx affected`) instead of using the underlying tooling directly
- Prefix nx commands with the workspace's package manager (e.g., `pnpm nx build`, `npm exec nx test`) - avoids using globally installed CLI
- You have access to the Nx MCP server and its tools, use them to help the user
- For Nx plugin best practices, check `node_modules/@nx/<plugin>/PLUGIN.md`. Not all plugins have this file - proceed without it if unavailable.
- NEVER guess CLI flags - always check nx_docs or `--help` first when unsure

## Scaffolding & Generators

- For scaffolding tasks (creating apps, libs, project structure, setup), ALWAYS invoke the `nx-generate` skill FIRST before exploring or calling MCP tools

## When to use nx_docs

- USE for: advanced config options, unfamiliar flags, migration guides, plugin configuration, edge cases
- DON'T USE for: basic generator syntax (`nx g @nx/react:app`), standard commands, things you already know
- The `nx-generate` skill handles generator discovery internally - don't call nx_docs just to look up generator syntax

<!-- nx configuration end-->
