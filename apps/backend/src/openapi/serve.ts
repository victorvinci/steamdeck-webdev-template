/**
 * Mount the API documentation routes on an Express app:
 *
 *   GET /api/openapi.json — the raw OpenAPI 3.0.3 document. Useful for
 *                           code-gen tools (`openapi-typescript`, postman
 *                           import, etc.) and for checking the contract
 *                           without loading Swagger UI.
 *   GET /docs             — Swagger UI rendered against /api/openapi.json.
 *
 * Both routes are intentionally non-prod only (see the `if (!isProd)`
 * guard at the call site in `main.ts`). Reasons:
 *
 *   - Public Swagger UI on a fresh fork's first deploy would expose
 *     internal API contracts to anyone who finds the URL — many forks
 *     won't want that as the default.
 *   - swagger-ui-express bundles its own static assets (CSS, JS); shipping
 *     them in a production image bloats the container for no reason if
 *     the team isn't actively browsing /docs in prod.
 *
 * Forks that DO want public API docs flip a single line in `main.ts` —
 * remove the `!isProd` guard. Apply rate-limiting if exposing publicly.
 */

import type { Express } from 'express';
import swaggerUi from 'swagger-ui-express';
import { generateOpenApiDocument } from './registry';

export function mountDocs(app: Express): void {
    // Generate once at mount time — the document is static for the lifetime
    // of the process. If hot-reloading schemas in dev, restart `nx serve`.
    const document = generateOpenApiDocument();

    app.get('/api/openapi.json', (_req, res) => {
        res.json(document);
    });

    app.use('/docs', swaggerUi.serve, swaggerUi.setup(document));
}
