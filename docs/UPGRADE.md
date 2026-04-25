# Pulling template improvements into your fork

This template ships fixes and improvements on its own cadence after you've forked. This doc explains how to pull those in without losing the divergence your fork has already accumulated.

`docs/FORK.md` covers the one-time onboarding (rename, settings, rulesets). This doc is the long tail: what you do six months later when the template ships a security patch, a CI pattern you want, or a refactor you wish you had.

> **Heads up.** Once `scripts/rename-template.sh` runs, your fork's tree diverges from the template's at every file the rename touched (project name, GitHub owner, npm scope, maintainer email). A blanket `git merge upstream/main` will produce a wall of rename conflicts on day one. The patterns below are ordered by how aggressively they avoid that.

---

## Pick a pattern

| Pattern                                                    | When to use                                                                                     | Cost                     |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ------------------------ |
| [A. Cherry-pick by SHA](#a-cherry-pick-by-sha)             | You want one or two specific upstream commits (security fix, CI patch, single bug fix).         | Low                      |
| [B. Replay from CHANGELOG](#b-replay-from-changelog)       | Your fork has diverged substantially. You want the _ideas_ from upstream, not the diff.         | Medium                   |
| [C. Upstream remote + merge](#c-upstream-remote-and-merge) | Your fork is still close to template (early days, minimal divergence). You want everything new. | High at first, low after |

**Default to A.** Most cross-fork pickups are surgical — one fix, not a flood. The CHANGELOG is the source of truth for what's available; it lists exactly which files each entry touched, so you can decide whether a pickup is one cherry-pick or a manual replay.

---

## A. Cherry-pick by SHA

Use this when you've read a CHANGELOG entry on the upstream template and want exactly that change.

### One-time setup

```bash
git remote add template git@github.com:victorvinci/steamdeck-webdev-template.git
git fetch template
```

Replace the URL with whichever upstream the template lives at. The remote name `template` is a convention — pick whatever you'll remember. `origin` stays pointed at your fork.

### Pickup workflow

1. Read the upstream CHANGELOG entry. Each entry names the files it touched inline (CHANGELOG rule in `CLAUDE.md`).
2. Find the SHA. The commit message will mention the change directly, or you can grep the upstream history:

    ```bash
    git fetch template
    git log template/main --oneline --grep='<keyword from changelog>'
    ```

3. Branch off your `develop` and cherry-pick:

    ```bash
    git checkout -b chore/pickup-<short-slug> develop
    git cherry-pick <sha>
    ```

4. Resolve conflicts. Most will be in files the rename script touched — `package.json`, `README.md`, `CLAUDE.md`, etc. The conflict marker will show your fork's project name on one side and the template's on the other; keep your fork's name. Source files that don't carry the project name usually merge cleanly.

5. Run gates and commit:

    ```bash
    npm run check
    git commit  # cherry-pick already staged the resolution
    ```

6. Open a PR against your fork's `develop`. Note the upstream SHA in the PR body so future you can cross-reference (`Cherry-picked from upstream <short-sha>`).

### Multi-commit pickups

For a feature spanning multiple commits, list the SHAs in chronological order:

```bash
git cherry-pick <sha1> <sha2> <sha3>
```

If conflicts get hairy mid-way, `git cherry-pick --abort` rolls back to the start of the run. `git cherry-pick --continue` resumes after you've staged the resolution.

---

## B. Replay from CHANGELOG

Use this when the upstream commit is too entangled with rename-touched files, or when your fork has diverged enough that a literal diff would be more conflict than content.

The CHANGELOG entry tells you _what_ changed and _why_. You re-implement the same change against your fork's current shape. No git plumbing — just a normal feature branch.

This is also the right move when the upstream change is small (one regex tweak, one config flag) and reading it is faster than fighting cherry-pick conflicts.

Worked example: upstream lands `### Security — Fixed L4 from SECURITY-AUDIT-v1.0.0.md` describing `x-request-id` validation in `apps/backend/src/main.ts`. You read that one file, see the regex pattern, write the same validation into your fork's now-renamed equivalent, and ship a regular PR. No cherry-pick, no rename conflicts.

Note the upstream entry source in your own CHANGELOG so the audit trail stays intact:

```markdown
- **Fixed** request-id log injection (replayed from upstream template's v1.0.0 SECURITY-AUDIT L4 — see `docs/SECURITY-AUDIT-v1.0.0.md` in upstream for context).
```

---

## C. Upstream remote and merge

Use this only when your fork is still essentially the template — early days, minimal divergence, the rename + a few of your own commits. After that, the rename-introduced divergence makes this approach more painful than A or B.

```bash
git remote add template git@github.com:victorvinci/steamdeck-webdev-template.git
git fetch template
git checkout -b chore/pull-upstream develop
git merge template/develop
```

Expect to resolve every file the rename script touched. Keep _your fork's_ values (project name, owner, scope, email) on every conflict. After the merge, `npm run check` and ship as a single PR.

Even early on, this is rarely worth it: cherry-picking the handful of useful commits is usually less work than wrestling with the merge.

---

## Files that always conflict

These three will conflict on _any_ cross-fork merge. Resolution patterns:

### `.ai-attribution.jsonl`

The attribution log is append-only and shared between both repos by file path, but the entries are entirely independent — your fork's history is yours, the template's history is theirs.

**Resolution:** keep both sides. Open the file, remove the conflict markers, leave all lines. The file is one-JSON-object-per-line and order doesn't matter; the merge marker is the only thing breaking JSONL.

```bash
# After git reports the conflict:
git checkout --theirs .ai-attribution.jsonl    # take template's lines
# Then re-add your fork's lines from the conflict marker manually,
# or use a merge tool that can produce a union.
```

The append-only rule (`CLAUDE.md`) explicitly says "when multiple branches each append one line and hit a merge conflict, resolve by keeping both lines." Same applies cross-fork.

### `CHANGELOG.md`

The upstream `[Unreleased]` section is the upstream's notes; your fork's `[Unreleased]` is yours. They are not the same thing.

**Resolution:** keep your fork's `[Unreleased]` content. If you've cherry-picked an upstream change, write your own one-line entry for it under your fork's `[Unreleased]`, citing the upstream entry as context (see [Pattern B's note](#b-replay-from-changelog)). Don't paste the upstream entry verbatim — your CHANGELOG describes _your_ release surface.

### Rename-touched files

`package.json`, `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `tsconfig.base.json`, the `apps/backend` and `apps/frontend` source files in the rename script's allowlist (see `docs/FORK.md` Step 2 table for the full list).

**Resolution:** keep your fork's identifier values (project name, GitHub owner, npm scope, maintainer email) on every conflict. The non-identifier content of the upstream change is the part you actually want.

---

## TypeScript strictness changes

Upstream's `tsconfig.base.json` is stricter than the TypeScript defaults — `strict: true` plus `noUnusedLocals`, `noUnusedParameters`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, and `noUncheckedIndexedAccess`. When upstream enables a new strictness flag, your fork inherits it on the next pickup. Most of these are inert on existing code, but two patterns trip up forks regularly:

- **`noUncheckedIndexedAccess`.** `arr[0]` and `record["key"]` resolve to `T | undefined`. The most common point of friction is that `if (arr.length > 0) { arr[0] }` does **not** narrow — TypeScript doesn't track length-based narrowing. Fix with `arr[0] ?? fallback`, optional chaining, or destructuring (`const [head] = arr; if (head !== undefined) ...`). Tuples, dot-access, and `.find()` / `.at()` / `Map.get()` (already `T | undefined`) are unaffected.
- **`exactOptionalPropertyTypes`** (not currently enabled, but a likely future flip). Distinguishes `{ x?: T }` from `{ x: T | undefined }` — assigning `undefined` to an optional becomes an error. Watch for this in a future pickup.

If a strictness flip lands a wave of new TypeScript errors in your fork, that's the flag working as intended on code the upstream template never had to typecheck. Fix the call sites rather than reverting the flag — reverting drifts your fork further from the template and forfeits the bug-prevention the flag exists for.

---

## What this doc is not

- **Not a guide to contributing back to upstream.** That's `CONTRIBUTING.md` in the upstream repo. Forks are independent projects under the MIT license; you're not obligated to upstream anything.
- **Not a replacement for reading CHANGELOG entries.** Cherry-picking blind is how subtle behaviour changes slip in. The CHANGELOG entry tells you the _why_ — read it before deciding to pull.
- **Not for migrating between major template versions.** If upstream cuts a breaking v2 (Node engine bump, `attribution-guard` schema change, etc.), the v2 release notes will spell out the migration steps. This doc covers the steady-state pickup case.
