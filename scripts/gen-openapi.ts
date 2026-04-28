/**
 * Regenerates `apps/backend/openapi.json` from the Zod schemas registered
 * in `apps/backend/src/openapi/registry.ts`.
 *
 * Usage:
 *   npm run gen:openapi          # write the file
 *   npm run gen:openapi:check    # write then `git diff --exit-code`
 *
 * The committed snapshot lets reviewers see API-shape changes in the PR
 * diff (so e.g. removing a field is visible alongside the schema edit
 * that caused it). The drift-check CI job (`openapi-drift` in ci.yml)
 * runs the regen path and fails the build if the working tree diverges
 * from the committed file — catches "edited the schema but forgot to
 * regenerate".
 *
 * Output is sorted-keys + 4-space-indented JSON with a trailing newline.
 * Stable formatting matters so re-running this script on an unchanged
 * source tree produces a byte-identical file.
 */

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateOpenApiDocument } from '../apps/backend/src/openapi/registry';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const OUT_PATH = join(ROOT, 'apps', 'backend', 'openapi.json');

function stableStringify(value: unknown, indent: number): string {
    // Sort object keys alphabetically at every level so the output is
    // deterministic regardless of insertion order. Arrays preserve their
    // order (semantic). zod-to-openapi already produces stable output for
    // the same input, but the registration-order dependency is fragile —
    // sorting here pins it.
    const seen = new WeakSet<object>();
    const replacer = (_key: string, val: unknown): unknown => {
        if (val && typeof val === 'object' && !Array.isArray(val)) {
            if (seen.has(val as object)) {
                throw new Error('Cycle detected while serialising OpenAPI document.');
            }
            seen.add(val as object);
            const sorted: Record<string, unknown> = {};
            for (const k of Object.keys(val as Record<string, unknown>).sort()) {
                sorted[k] = (val as Record<string, unknown>)[k];
            }
            return sorted;
        }
        return val;
    };
    return JSON.stringify(value, replacer, indent);
}

function main() {
    const document = generateOpenApiDocument();
    const json = stableStringify(document, 4);
    writeFileSync(OUT_PATH, json + '\n', 'utf8');
    console.log(`Wrote ${OUT_PATH}`);
}

main();
