# SemVer policy

This repo follows [Semantic Versioning](https://semver.org/). Because it's a **template** (downstream users fork rather than depend on a published package), the SemVer contract applies to **patterns and shapes a fork might rely on**, not to every exported symbol. This doc draws the line.

## Versioning scope

- **v0.x** — pre-stable. Breaking changes can land in minors without ceremony. That phase ended with v0.2.0.
- **v1.0.0 onward** — this policy kicks in. Breaking changes require a major bump and a migration note in `CHANGELOG.md`.

## What's public (SemVer-committed)

These are the things a fork is allowed to depend on. Breaking any of them requires a major bump.

### API response envelope (`libs/types`)

- Shape of `ApiSuccess<T>` (`{ data: T }`)
- Shape of `ApiError` (`{ error: string, issues?: Array<{ path, message }> }`)
- Discriminated union `ApiResponse<T>`
- Signature of `isApiError<T>(res): res is ApiError`

Why: every route follows this envelope and forks likely build error-handling on top of it. Flipping the keys (e.g. `data` → `payload`) would silently break all downstream code.

### Utility signatures (`libs/utils`)

- `formatError(err: unknown): string`
- `isDefined<T>(value: T | null | undefined): value is T`

Why: trivial, but widely called. Signature changes would ripple.

### Node engine range

The `engines.node` field in `package.json`. Bumping the **minimum major** (e.g. `>=24` → `>=26`) is a breaking change — forks on older Node would stop working.

### The two-commit AI attribution flow + schema

Documented in `CLAUDE.md`. The JSONL schema (`date`, `model`, `scope`, `description`, `files`) is frozen. New fields can be added (minor); renaming or removing existing ones is a major.

### The release workflow contract

Documented in `docs/RELEASE.md`. The branch model (`feature → develop (squash) → main (rebase) → tag`) is a contract forks are expected to mirror. Changing the branch model or the merge methods is a major.

## What's internal (free to evolve in minors/patches)

These can change without a major bump. Forks that tweak these own the merge burden.

- **Backend route implementations and URL shapes.** `/users`, `/health`, query param names, etc. The envelope is public; the specific endpoints are examples. A fork replacing `/users` with its own domain routes is expected behavior.
- **Frontend components, routes, and styling.** The template demonstrates patterns (TanStack Router, Storybook-per-component) but specific components in `apps/frontend/src/components/` aren't API.
- **Specific domain types** like `User`, `ListUsersQuery`, `ListUsersResponse`. The **pattern** of Zod-as-source-of-truth is public (see above); the specific types are examples.
- **DB schema and migrations.** Forks own their schema. The migration runner's CLI interface (`npm run migrate`) is public; the initial `db/schema.sql` is not.
- **CI workflow internals.** Job names, step ordering, action SHAs. The required status check contexts (`ci pass`) are part of the ruleset contract and therefore public.
- **ESLint / Prettier / TypeScript configs.** Tuning is ongoing; forks that rely on exact rule sets should vendor the config.
- **Script implementations in `scripts/`.** The `npm run <script>` surface in `package.json` is the public contract; the internals of each script are not.

## Major version triggers (explicit list)

Bump the major version when any of these happen:

1. Envelope shape change (`data` → something else, `error` format change).
2. `libs/utils` function signatures change (add/remove/rename params, narrow return type).
3. `engines.node` minimum major increases.
4. AI attribution schema loses or renames an existing field.
5. Release workflow branch model changes (e.g. switching from `develop → main` to trunk-based).
6. A ruleset change that alters the required status check contexts that consumers CI-integrate against.

## Non-triggers (minor or patch is fine)

- Adding new exports to `libs/types` or `libs/utils`.
- Adding new optional fields to envelopes or the attribution schema.
- New backend routes, new frontend components, new Storybook stories.
- Dependency bumps (unless they change a public signature).
- DB schema changes — forks own their schema.
- Replacing or removing **example** content (the demo `/users` route, the demo home page).

## How this interacts with `CHANGELOG.md`

Every release lists changes under Keep-a-Changelog sections. For a major bump, the `[X.0.0]` section must include a **Migration** subsection explaining:

- What changed in the public contract.
- The minimal code diff a fork needs to apply to adapt.
- Any automated tooling (codemod, migration script) if provided.

## When in doubt

If a change is ambiguous (is this pattern public or not?), err on the side of **calling it a major** and documenting the migration. It's cheaper to over-communicate a breaking change than to quietly ship one.
