---
name: add-api-route
description: Add a new REST endpoint end-to-end (Zod schema → service → route → OpenAPI → React Query hook → component → Storybook story → tests). USE WHEN the user says "add an endpoint", "add an API route", "new route", "add a backend route", "wire up an endpoint", or wants a full vertical slice from DB to UI. Mirrors the demo `/api/users` slice so the typed contract never drifts.
---

# Add an API route (vertical slice)

This template's signature pattern: a single Zod schema in `libs/types` is the
source of truth for the backend handler, the OpenAPI document, and the frontend
client. Build a new endpoint by mirroring the demo `/api/users` slice rather
than inventing a new shape.

## User instructions

$ARGUMENTS

Identify the resource/route, its request (query/body) shape, and its response
shape before touching files.

## Reference implementation

Read these first — copy their structure:

- `libs/types/src/lib/api.ts` — Zod schemas + inferred types, the `ApiSuccess<T>`
  / `ApiError` envelope, and `isApiError`.
- `apps/backend/src/{routes,services,middleware}/` — `routes/users.ts` (handler),
  `services/` (mysql2 data access), `middleware/validate` (Zod request validation).
- `apps/frontend/src/lib/` + `apps/frontend/src/components/` — the React Query
  hook and the component that consumes it.

## Steps

1. **Schema first (`libs/types`).** Add request/response Zod schemas to
   `libs/types/src/lib/api.ts` and export the inferred types. Every response
   wraps in the `{ data: T }` success envelope; errors use the `ApiError` shape.
   Add `.openapi(...)` metadata so the schema documents itself.
2. **Service layer (`apps/backend/src/services/`).** Data access with `mysql2`
   and **named placeholders** — never string-interpolate SQL (see the Security
   checklist in `README.md`). Keep SQL out of the route handler.
3. **Route (`apps/backend/src/routes/`).** Thin handler: validate input with the
   `validate` middleware against the Zod schema, call the service, return the
   enveloped result. Mount it in `apps/backend/src/main.ts` under `/api`.
4. **Register for OpenAPI + regenerate.** Add the route to
   `apps/backend/src/openapi/registry.ts`, then run **`npm run gen:openapi`** to
   refresh `apps/backend/openapi.json`. The `openapi-drift` CI job fails if you
   edit a schema and forget this — always regen and commit the snapshot.
5. **Frontend hook + component.** Add a TanStack Query hook in
   `apps/frontend/src/lib/`, import the shared types from `@mcb/types` (do not
   re-declare them), and a component in `apps/frontend/src/components/`.
6. **Storybook story (MANDATORY).** Every new frontend component ships a
   co-located `*.stories.tsx` covering at least the default state plus meaningful
   variants (loading / error / empty). No story = the component is not done
   (CLAUDE.md). The `storybook-test` CI job renders every story headlessly.
7. **Tests.** Backend: a Jest integration test in `apps/backend-e2e` (or unit
   test in the service). Frontend: a Playwright spec in `apps/frontend-e2e` and
   Vitest where configured. Match each project's existing test runner.
8. **Verify.** `npm run check` (format/lint/typecheck/test) and, if you can run a
   DB, `npm run preflight` for the e2e + Storybook build. Update `CHANGELOG.md`
   under `[Unreleased]` and append the `.ai-attribution.jsonl` line.

## Gotchas

- Coerce-and-validate query params (`z.coerce.number()...`) like
  `ListUsersQuery` — query strings arrive as strings.
- `/docs` Swagger UI is non-prod only; don't rely on it in production paths.
- Backend route URL shapes are **internal** per `docs/SEMVER.md` — fine to
  evolve; the **envelope** is the public contract, so don't change `{ data }` /
  `ApiError`.
