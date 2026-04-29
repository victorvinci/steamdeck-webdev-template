/**
 * Side-effect-only module that calls `extendZodWithOpenApi(z)` before any
 * schema is imported. Why this exists as its own file:
 *
 * Zod 4 schemas locked their prototype chain at construction time — the
 * `.openapi()` method that `@asteasolutions/zod-to-openapi` adds via
 * `z.ZodType.prototype.openapi = …` only resolves on schemas constructed
 * AFTER the patch runs. Schemas constructed before the patch do not pick
 * up the method retroactively (this is a Zod 4 behaviour change vs. Zod 3,
 * where prototype patching propagated to existing instances).
 *
 * `libs/types` constructs its schemas at module-evaluation time. If
 * `registry.ts` imports `@mcb/types` before this extension runs, the
 * resulting `UserSchema.openapi(…)` call throws "openapi is not a
 * function". By splitting the extension into its own side-effect module
 * and importing it FIRST in `registry.ts`, we guarantee ES-module
 * evaluation order: this file evaluates → extension applies → THEN
 * `@mcb/types` evaluates → schemas pick up the patched prototype.
 *
 * Keep this import at the very top of `registry.ts`. Putting it after a
 * `@mcb/types` import would defeat the purpose.
 *
 * `libs/types` does NOT take a `zod-to-openapi` dependency — keeping the
 * extension here means the React frontend (which also imports `@mcb/types`)
 * doesn't have to bundle the OpenAPI converter.
 */

import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';
import { z } from 'zod';

extendZodWithOpenApi(z);
