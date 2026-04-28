/**
 * OpenAPI 3.0.3 spec generator.
 *
 * Source of truth for the API contract is `libs/types` (Zod schemas). This
 * module wraps those schemas with OpenAPI metadata via
 * `@asteasolutions/zod-to-openapi` and emits a single OpenAPI document that
 * is:
 *
 *   1. Served at `/api/openapi.json` and `/docs` (non-prod only — see
 *      `mountDocs()` in `./serve.ts`).
 *   2. Snapshotted at `apps/backend/openapi.json` and verified in CI by
 *      `npm run gen:openapi:check`. Reviewers see schema diffs in the PR.
 *
 * Why annotations live HERE rather than in `libs/types`:
 *
 *   The `.openapi()` extension method requires `extendZodWithOpenApi(z)` to
 *   have been called first. Calling it inside `libs/types/index.ts` would
 *   force every consumer of the lib (including the React frontend) to ship
 *   `@asteasolutions/zod-to-openapi` in its bundle. Instead we extend Zod
 *   exactly once, at the top of this file, and apply per-schema metadata
 *   at registration time via `.openapi(name, { … })`. `libs/types` stays
 *   lean and frontend-only consumers never load the converter.
 *
 * Why we don't use `default` on Zod schemas to document defaults:
 *
 *   `ListUsersQuerySchema` uses `.coerce.number().default(20)` — the
 *   default is applied at parse time, not advertised by the type. The
 *   converter does emit it as `default: 20` in the output, but only for
 *   explicit `.default()` calls; if you change a default in the schema,
 *   regenerate the spec (`npm run gen:openapi`) to keep it in sync.
 */

// MUST be the first import: extends Zod with `.openapi()` before any schema
// is constructed elsewhere. See `./zod-extension.ts` for the rationale.
import './zod-extension';
import { OpenApiGeneratorV3, OpenAPIRegistry } from '@asteasolutions/zod-to-openapi';
import { z } from 'zod';
import { ListUsersQuerySchema, ListUsersResponseSchema, UserSchema } from '@mcb/types';

export const registry = new OpenAPIRegistry();

// ---------- shared component schemas ----------

// Re-declare the response envelope as a Zod schema so it can be referenced
// by name in path operations. `libs/types` exposes `ApiSuccess<T>` /
// `ApiError` as TypeScript types only; OpenAPI components need runtime
// schemas, so we mirror them here. The shapes must stay in lock-step —
// covered by `apps/backend/src/middleware/validate.spec.ts` and the
// integration tests in `apps/backend-e2e`.
const ApiErrorSchema = z
    .object({
        error: z.string().openapi({ example: 'Validation failed' }),
        issues: z
            .array(
                z.object({
                    path: z.string(),
                    message: z.string(),
                })
            )
            .optional(),
    })
    .openapi('ApiError', {
        description: 'Error envelope returned by every non-2xx response.',
    });

/**
 * Helper to wrap a payload schema in the standard `{ data: T }` envelope,
 * inline (so each path's response body is a fresh schema object rather
 * than a recursive component). zod-to-openapi has experimental support for
 * generic components but the inline form generates cleaner Swagger UI
 * output for a small surface like this.
 */
function apiSuccess<T extends z.ZodTypeAny>(data: T) {
    return z.object({ data });
}

// Register the data schemas with OpenAPI component names so paths can
// reference them. The `.openapi(name, …)` call here just attaches metadata;
// the registration side-effect is what creates the `#/components/schemas/<name>`
// entry in the final document.
registry.register(
    'User',
    UserSchema.openapi('User', {
        description: 'A user record as returned by the public API.',
        example: {
            id: 1,
            name: 'Ada Lovelace',
            email: 'ada@example.com',
            createdAt: '2026-04-12T00:00:00.000Z',
        },
    })
);

registry.register(
    'ListUsersResponse',
    ListUsersResponseSchema.openapi('ListUsersResponse', {
        description: 'Paginated user list payload (the `data` of GET /api/users).',
    })
);

// ---------- paths ----------

registry.registerPath({
    method: 'get',
    path: '/api/health/live',
    summary: 'Liveness probe',
    description:
        'Returns 200 without touching any dependency. Suitable for a Kubernetes-style liveness probe — a failure means the process is wedged and should be restarted.',
    tags: ['health'],
    responses: {
        200: {
            description: 'Process is alive.',
            content: {
                'application/json': {
                    schema: apiSuccess(z.object({ status: z.literal('ok') })),
                },
            },
        },
    },
});

registry.registerPath({
    method: 'get',
    path: '/api/health/ready',
    summary: 'Readiness probe',
    description:
        'Pings the database pool. Returns 200 when ready to serve traffic, 503 when the DB is unreachable. Suitable for a Kubernetes-style readiness probe — a failure means the orchestrator should stop routing traffic without restarting the pod.',
    tags: ['health'],
    responses: {
        200: {
            description: 'Database is reachable.',
            content: {
                'application/json': {
                    schema: apiSuccess(
                        z.object({
                            status: z.literal('ok'),
                            db: z.literal('connected'),
                        })
                    ),
                },
            },
        },
        503: {
            description: 'Database is unreachable.',
            content: {
                'application/json': {
                    schema: z.object({ error: z.string() }).openapi({
                        example: { error: 'Database unavailable' },
                    }),
                },
            },
        },
    },
});

registry.registerPath({
    method: 'get',
    path: '/api/health',
    summary: 'Readiness probe (back-compat alias)',
    description:
        "Alias of `/api/health/ready`. Kept so existing platform probes (and this repo's own Playwright `webServer` wait) keep working — prefer `/live` or `/ready` in new code.",
    tags: ['health'],
    responses: {
        200: {
            description: 'Database is reachable.',
            content: {
                'application/json': {
                    schema: apiSuccess(
                        z.object({
                            status: z.literal('ok'),
                            db: z.literal('connected'),
                        })
                    ),
                },
            },
        },
        503: {
            description: 'Database is unreachable.',
            content: {
                'application/json': {
                    schema: z.object({ error: z.string() }),
                },
            },
        },
    },
});

registry.registerPath({
    method: 'get',
    path: '/api/users',
    summary: 'List users',
    description:
        'Returns a paginated list of users. Query params are coerced from strings (Zod `.coerce.number()`) and validated; out-of-range values respond 400 with an `ApiError` describing each failure.',
    tags: ['users'],
    request: {
        query: ListUsersQuerySchema,
    },
    responses: {
        200: {
            description: 'Paginated user list.',
            content: {
                'application/json': {
                    schema: apiSuccess(ListUsersResponseSchema),
                },
            },
        },
        400: {
            description: 'Validation failure on `limit` or `offset`.',
            content: {
                'application/json': {
                    schema: ApiErrorSchema,
                },
            },
        },
    },
});

// ---------- generation ----------

/**
 * The OpenAPI document version is a contract version — it can (and usually
 * does) evolve independently of the npm package version. Hardcoding it as
 * a constant here keeps the document deterministic and bundler-friendly
 * (no runtime fs / require tricks to read package.json from the build
 * output). Forks should bump this whenever they make a breaking API change.
 */
const API_VERSION = '0.3.0';

export function generateOpenApiDocument() {
    const generator = new OpenApiGeneratorV3(registry.definitions);
    return generator.generateDocument({
        openapi: '3.0.3',
        info: {
            title: 'steamdeck-webdev-template API',
            version: API_VERSION,
            description:
                'Public HTTP API for the steamdeck-webdev-template demo backend. Generated from the Zod schemas in `libs/types` — see `apps/backend/src/openapi/registry.ts`.',
        },
        servers: [{ url: 'http://localhost:3000', description: 'Local dev' }],
        tags: [
            { name: 'health', description: 'Liveness / readiness probes for orchestrators.' },
            { name: 'users', description: 'User records.' },
        ],
    });
}
