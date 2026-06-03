---
name: nx-upgrade
description: Safely bump the Nx toolchain (nx + all @nx/* packages) without breaking the lockfile. USE WHEN the user says "upgrade nx", "bump nx", "update the nx toolchain", "migrate nx", or a Dependabot/Renovate/security alert targets nx or an @nx/* package. Encodes the --legacy-peer-deps + transitive-bump + no-full-regen flow.
---

# Upgrade the Nx toolchain

Nx's internal packages pin each other with **exact** peer/dependency versions
that npm's strict resolver rejects, and `nx migrate` only bumps the `@nx/*`
packages listed **directly** in `package.json`. Get either wrong and `npm
install` aborts with `ERESOLVE`. The matching symptom/fix is documented in
`docs/TROUBLESHOOTING.md` ("`npm install` fails with `ERESOLVE` after bumping
Nx") — this skill is the executable version.

## Current versions

- !`node -e "const p=require('./package.json');const d={...p.dependencies,...p.devDependencies};console.log('nx', d.nx)"`

## User instructions

$ARGUMENTS

## Steps

1. **Migrate.** `npx nx migrate nx@<target>` (or `@latest`). This updates the
   direct `@nx/*` versions in `package.json` and writes `migrations.json` if
   there are code migrations. **Do not** run `npm install` yet.
2. **Bump the transitive `@nx/*` too.** `nx migrate` skips packages that aren't
   direct deps. Enumerate every `@nx/*`/`nx` entry in the lockfile and make sure
   the non-direct ones (`@nx/cypress`, `@nx/docker`, `@nx/module-federation`,
   `@nx/rollup`, `@nx/workspace`, plus the `@nx/nx-*` platform binaries) move to
   the same version. List them with:
    ```sh
    node -e "const l=require('./package-lock.json');const s=new Set();for(const[p,m]of Object.entries(l.packages)){const x=p.match(/node_modules\/((@nx\/[^/]+)|nx)\$/);if(x&&m.version)s.add(x[1]+' '+m.version)}console.log([...s].sort().join('\n'))"
    ```
3. **Install with `--legacy-peer-deps`.** With `package.json` already at the new
   versions, run `npm install --legacy-peer-deps` (no package args). This
   reconciles only the Nx subtree against the existing lockfile.
    - **Do NOT** delete `package-lock.json` and reinstall from scratch — a full
      regen surfaces an unrelated latent Storybook peer conflict
      (`@storybook/addon-a11y` vs the pinned `storybook` core) and turns a scoped
      bump into a large, risky change. Keep the lockfile; let the targeted install
      update only Nx.
    - `--legacy-peer-deps` only affects **lockfile generation**. CI's `npm ci`
      installs the lockfile without re-resolving peers, so it's unaffected.
4. **Run code migrations** if `migrations.json` exists:
   `npx nx migrate --run-migrations` (then delete `migrations.json`).
5. **Verify.** `npm ci` must exit 0 (proves CI will accept the lockfile), then
   `npm run check`. If you can run a DB, `npm run preflight` for e2e/Storybook.
6. **Record the audit delta.** Run `npm audit` before/after and note the change
   in `CHANGELOG.md` under `[Unreleased] → Security` (which advisories cleared,
   which remain and why). Append the `.ai-attribution.jsonl` line.

## Gotchas

- If an advisory's only `npm audit`-offered "fix" is a **downgrade** (e.g.
  `@nx/react@<older>`), it's not a real fix — leave it and note it as dev-only
  pending an upstream release; don't undo the bump.
- Keep the change Nx-scoped: the lockfile diff should be in-place `@nx/*` version
  bumps, not a sprawl into unrelated packages. If it sprawls, you full-regenned
  by mistake — start over from the committed lockfile.
