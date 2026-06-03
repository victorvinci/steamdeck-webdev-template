---
name: add-migration
description: Create a new numbered database migration the runner and linter accept. USE WHEN the user says "add a migration", "new migration", "change the schema", "add a table/column", "alter the database", or needs a DB schema change. Handles the numbered-file convention, the lint rules, the runner, and verifying a from-scratch migrate.
---

# Add a database migration

Migrations are numbered SQL files under `db/migrations/`, applied in order by a
lightweight transaction-wrapped runner. `db/schema.sql` aggregates them for a
fresh bootstrap.

## Current migrations

- !`ls db/migrations/ 2>/dev/null | tail -5`
- Applied vs pending: run `npm run migrate:status`.

## User instructions

$ARGUMENTS

## Steps

1. **Name the file.** Next zero-padded sequence number + a short slug, e.g.
   `db/migrations/004_add_orders_table.sql`. Numbers must be contiguous and
   unique — check the existing files first (above). The runner applies files in
   lexical order, so zero-pad consistently.
2. **Write forward-only SQL.** This runner has **no down/rollback** — write
   additive, idempotent-where-possible DDL. Wrap multi-statement logic so a
   partial apply can't leave a half-migrated table (the runner wraps each file
   in a transaction; keep statements compatible with that).
3. **Follow the lint rules.** `scripts/lint-migrations.sh` runs in pre-commit
   and CI — it is the authority on what's allowed (naming, dangerous-statement
   guards, etc.). Run it locally: `bash scripts/lint-migrations.sh` (or just
   `git add` and let the pre-commit hook fire). Fix what it flags rather than
   bypassing.
4. **Keep `db/schema.sql` consistent.** It's the bootstrap aggregator used for a
   fresh init (and the Docker MySQL `initdb` mount). If the project's convention
   is to regenerate/extend it alongside migrations, update it so a brand-new DB
   ends up identical to a fully-migrated one.
5. **Apply + verify.** `npm run migrate` (applies pending), then
   `npm run migrate:status` to confirm. To prove the from-scratch path works,
   `npm run db:reset` (drops all tables → re-applies every migration → loads
   `db/seed.sql`); it refuses to run when `NODE_ENV=production`.
6. **Seed if relevant.** If the change needs dev data, update `db/seed.sql`
   (local-only; loaded by `db:reset`).
7. **Finish.** Update `CHANGELOG.md` under `[Unreleased]` and append the
   `.ai-attribution.jsonl` line. If the schema change affects a route, also run
   the `add-api-route` flow.

## Gotchas

- Never edit an already-applied migration to "fix" it — the runner only applies
  **pending** files, so re-editing an applied one is a silent no-op on existing
  databases. Add a new migration instead (or use `db:reset` locally).
- Identifiers in scripts come from the system catalog, not user input, and are
  backtick-wrapped — keep that pattern for any dynamic SQL you add.
