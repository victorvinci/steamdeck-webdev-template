# Troubleshooting

Common issues that show up when running the template locally or after forking. Each entry is **Symptom → Cause → Fix**. If you hit something not covered here, please open an issue so the next person doesn't.

---

## `EADDRINUSE: address already in use :::3000` (or `:::4200`)

**Symptom.** `npm run dev` exits immediately with `EADDRINUSE`.

**Cause.** Another process (a stale dev server, Docker container, or unrelated app) is already bound to the backend port `3000` or the frontend port `4200`.

**Fix.** Find and kill the holder, or move ports:

```bash
# Find the process
lsof -iTCP:3000 -sTCP:LISTEN          # macOS / Linux
ss -ltnp 'sport = :3000'               # Linux

# Kill it (replace <pid>)
kill <pid>

# Or shift the backend off 3000 by editing .env
echo "PORT=3001" >> .env
# and update VITE_API_URL on the frontend side to match
```

The defaults live in `apps/backend/src/config/env.ts` (`PORT` defaults to `3000`) and `apps/frontend/vite.config.ts` (`server.port` is `4200`).

---

## `dev-setup-native.sh`: "ERROR 1698 (28000): Access denied for user 'root'@'localhost'"

**Symptom.** Running `npm run setup` on a host without Docker falls through to `scripts/dev-setup-native.sh`, which fails on the `sudo mysql` step.

**Cause.** `dev-setup-native.sh` connects to MySQL as `root` via the unix socket, which only works when the local `mysqld` was installed with the `auth_socket` plugin (the default on Debian/Ubuntu's `mysql-server` package). On RHEL/Fedora, macOS Homebrew, and most other distros, `root@localhost` uses `caching_sha2_password` instead, and the unix-socket auth fails.

**Fix.** Either:

1. **Use Docker instead** (`scripts/dev-setup.sh` will pick it up automatically once `docker` is on `PATH`). Easiest if you have it.
2. **Set a root password and run the SQL by hand** — paste the `CREATE DATABASE` / `CREATE USER` block from `dev-setup-native.sh` into `mysql -u root -p` directly. Then load the schema with the line at the bottom of the script.
3. **Switch your local `root` to `auth_socket`** if you have full control of the MySQL install: `ALTER USER 'root'@'localhost' IDENTIFIED WITH auth_socket;`. Don't do this on a shared dev box.

---

## CI: `attribution-guard` job fails with "no JSONL line added"

**Symptom.** PR is red on the `attribution-guard` check with a message about a missing line in `.ai-attribution.jsonl`.

**Cause.** An AI agent (Claude Code, Cursor, Copilot, etc.) wrote or edited code in the PR but didn't append the required JSONL line per `CLAUDE.md` → `## AI attribution rule`. The guard counts net-added lines and validates each as JSON.

**Fix.** Append one JSON line to `.ai-attribution.jsonl` matching the schema in `CLAUDE.md` (date, model, scope, description, files), then push. The work commit + attribution commit two-commit flow described in `CLAUDE.md` is the standard pattern; for a quick fix you can also amend the existing commit, but prefer a new attribution-only follow-up commit so reviewers see the JSONL touch separately from the code diff.

---

## `git push` rejected: "commits must be signed"

**Symptom.** Pushing a branch returns an error about unsigned commits, or a PR shows red `Verified` indicators and refuses to merge.

**Cause.** The `develop` and `main` branch rulesets require every commit to be signed. Forks that copied the rulesets but haven't configured commit signing locally hit this on the first push.

**Fix.** Set up commit signing once, then re-sign your existing commits:

```bash
# SSH key (simplest if you already push over SSH)
git config --global commit.gpgsign true
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
# Upload the same key under GitHub Settings → SSH and GPG keys with type "Signing Key"

# Re-sign the unsigned commits on the current branch:
git rebase -i --exec 'git commit --amend --no-edit -S' main
git push --force-with-lease
```

`CONTRIBUTING.md` → `Signing your commits` has the GPG variant if you don't use SSH keys.

---

## CI is fully red: "This Nx Cloud organization has been disabled due to exceeding the FREE plan"

**Symptom.** Every PR fails at the first `nx-cloud start-ci-run` step with the quota-exhausted error. No way to merge anything.

**Cause.** Nx Cloud's free plan has a monthly task budget. When it's exhausted the org is disabled until quota resets (or you upgrade), and CI is fully stuck.

**Fix.** Flip the kill switch — no code change needed:

1. Go to **Settings → Secrets and variables → Actions → Variables** on the GitHub repo.
2. Set `NX_CLOUD_ENABLED` to `false`.
3. Re-run the failed workflow. CI now uses the local filesystem cache only.

When quota resets, flip back to `true`. See README → `Nx Cloud configuration` for the full mechanism (why blanking the token alone isn't enough).

---

## After running `scripts/rename-template.sh` the lockfile is dirty

**Symptom.** `git status` shows `package-lock.json` modified after the rename script runs, and you're not sure if the change is safe to commit.

**Cause.** `package-lock.json` carries the project name at two positions (the root `name` field and the empty-key workspace entry). The rename script is intentionally rewriting both — this is correct behaviour. Committing `package.json` and ignoring the lockfile would land a `name` mismatch and CI would complain on the next `npm ci`.

**Fix.** Stage and commit the lockfile change along with the rest of the rename — `docs/FORK.md` Step 2 covers this. If the diff shows changes to entries other than the two `name` fields, something else touched the lockfile; bisect by re-running the script on a clean checkout.

---

## TypeScript: "Object is possibly 'undefined'" on `arr[0]` after a template pickup

**Symptom.** A formerly-clean fork starts showing `TS2532` errors on array index access (`arr[0]`, `record["key"]`) after picking up upstream template changes.

**Cause.** Upstream enabled `noUncheckedIndexedAccess: true` in `tsconfig.base.json`. The flag re-types `arr[0]` from `T` to `T | undefined`, surfacing latent bounds-check gaps that previously compiled silently. The most common point of friction is that `if (arr.length > 0)` does **not** narrow `arr[0]`.

**Fix.** Acknowledge the gap rather than reverting the flag (reverting drifts your fork further from the template):

```ts
// Before:
const head = arr[0];
console.log(head.toUpperCase()); // TS2532: Object is possibly 'undefined'.

// After (pick whichever fits the call site):
const head = arr[0];
if (head !== undefined) console.log(head.toUpperCase());
console.log(arr[0]?.toUpperCase() ?? '');
const [head] = arr;
if (head) console.log(head.toUpperCase());
```

`docs/UPGRADE.md` → `TypeScript strictness changes` has the full callout including which APIs are unaffected.

---

## Playwright e2e flake: "browserContext.newPage: Target page, context or browser has been closed"

**Symptom.** `nx e2e frontend-e2e` passes locally most of the time but fails intermittently in CI.

**Cause.** Either (a) the `webServer` in `apps/frontend-e2e/playwright.config.ts` is racing with the test runner and tests hit a not-yet-listening server, or (b) the test relies on timing the seeded backend is too slow to satisfy.

**Fix.** First look at the `webServer.timeout` in `playwright.config.ts` — if you increased the seed size or added migrations, bump the timeout. For genuinely flaky tests, prefer `expect.poll(...)` or `page.waitForResponse(...)` over `page.waitForTimeout(...)`. The `apps/frontend-e2e/src/users.failure.spec.ts` Retry test is a good template for explicitly counting fetch attempts so the assertion isn't time-dependent.

---

## Got something not on this list?

Open an issue with the symptom, your platform, and the failing command's full output. If you find the fix yourself, a PR appending an entry here is even better — the format is **Symptom → Cause → Fix**, no fluff.
