# @mcb/utils

Small, dependency-free helper functions shared between `apps/frontend` and `apps/backend`. Imported as `@mcb/utils`.

## What's exported

- **`formatError(err: unknown): string`** — runtime-safe error serializer. Accepts anything thrown (`Error`, `string`, unknown object, `null`) and returns a human-readable message without leaking internals.
- **`isDefined<T>(v: T | null | undefined): v is T`** — type guard for `.filter(isDefined)`. Narrows `(T | null | undefined)[]` to `T[]`.

## What does **not** belong here

- Anything with framework dependencies (React, Express, etc.) — keep those in the relevant app or feature-specific lib.
- Anything that loads environment variables — config lives in the app that needs it, not a shared lib.
- Anything specific to the API domain — those belong in `@mcb/types`.

If a helper you're adding pulls in a dep or leaks an app-specific concern, it's a sign that it should live closer to the code that uses it.

## Running tests

```bash
npm run test:utils
```
