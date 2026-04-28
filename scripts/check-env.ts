/**
 * Verifies the local `.env` against `.env.example`.
 *
 * Fails fast with a friendly message when a key is required by `.env.example`
 * (uncommented `KEY=...` line) but is missing or empty in `.env`. Caught at
 * `npm run dev` time instead of as a confusing "undefined.foo" runtime error
 * on the first request.
 *
 * Usage:
 *   npx tsx scripts/check-env.ts
 *
 * Exit codes:
 *   0  all required keys present
 *   1  one or more required keys missing or empty in .env
 *   2  .env file does not exist (run `npm run setup`)
 */

import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const ENV_PATH = join(ROOT, '.env');
const EXAMPLE_PATH = join(ROOT, '.env.example');

type EnvMap = Map<string, string>;

function parseEnv(content: string, includeCommented: boolean): EnvMap {
    const map: EnvMap = new Map();
    for (const rawLine of content.split('\n')) {
        const line = rawLine.trim();
        if (!line) continue;
        const isComment = line.startsWith('#');
        if (isComment && !includeCommented) continue;
        const body = isComment ? line.replace(/^#\s*/, '') : line;
        const eq = body.indexOf('=');
        if (eq === -1) continue;
        const key = body.slice(0, eq).trim();
        if (!/^[A-Z_][A-Z0-9_]*$/i.test(key)) continue;
        const value = body.slice(eq + 1).trim();
        map.set(key, value);
    }
    return map;
}

function main(): number {
    if (!existsSync(EXAMPLE_PATH)) {
        console.error('check-env: .env.example not found — repo is in an unexpected state.');
        return 2;
    }

    if (!existsSync(ENV_PATH)) {
        console.error('check-env: .env does not exist.');
        console.error('  Run `npm run setup` to bootstrap one from .env.example.');
        return 2;
    }

    const exampleRequired = parseEnv(readFileSync(EXAMPLE_PATH, 'utf8'), false);
    const env = parseEnv(readFileSync(ENV_PATH, 'utf8'), false);

    const missing: string[] = [];
    const empty: string[] = [];
    for (const key of exampleRequired.keys()) {
        if (!env.has(key)) {
            missing.push(key);
        } else if (env.get(key) === '') {
            empty.push(key);
        }
    }

    if (missing.length === 0 && empty.length === 0) {
        return 0;
    }

    console.error(
        'check-env: .env is missing one or more required keys (defined in .env.example):'
    );
    for (const key of missing) console.error(`  - ${key}  (not present)`);
    for (const key of empty) console.error(`  - ${key}  (present but empty)`);
    console.error('');
    console.error(
        'Fix: copy the missing lines from .env.example into .env and fill in real values.'
    );
    console.error('     A clean reset is `cp .env.example .env` (then re-fill secrets).');
    return 1;
}

process.exit(main());
