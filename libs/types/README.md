# @mcb/types

Shared TypeScript types and Zod schemas for the monorepo. Imported from both `apps/frontend` and `apps/backend` as `@mcb/types`.

## Why this lib exists

This is the single source of truth for every API contract in the project. The pattern is:

1. Define a Zod schema here (e.g. `UserSchema`, `ListUsersQuerySchema`).
2. Infer a TypeScript type from it with `z.infer<typeof Schema>`.
3. The backend uses the schema to **validate** incoming requests (via the `validate` middleware).
4. The frontend uses the inferred type for **fetch responses and form state**.

Because runtime validation and compile-time types come from the same definition, the two can never drift. Rename a field in the schema and both sides get a type error until they're updated.

## What's exported

- **`UserSchema` / `User`** — a single application user. Example of a domain entity.
- **`ListUsersQuerySchema` / `ListUsersQuery`** — query params for `GET /api/users`. Example of a coerced numeric query (strings in, numbers out).
- **`ListUsersResponseSchema` / `ListUsersResponse`** — the paginated list envelope.
- **`ApiResponse<T>`** — discriminated union of `ApiSuccess<T>` and `ApiError`. Every backend route should return one of these.
- **`isApiError`** — type guard for narrowing `ApiResponse<T>`.

## Adding a new type

1. Create or edit a file under `src/lib/`.
2. Export a Zod schema and its inferred type.
3. Re-export from `src/index.ts`.
4. Import from either app as `import { YourType } from '@mcb/types'`.

## Running tests

```bash
npm run test:types
```
