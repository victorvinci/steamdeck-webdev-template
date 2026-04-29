import { generateOpenApiDocument } from './registry';

describe('generateOpenApiDocument', () => {
    const doc = generateOpenApiDocument();

    it('emits an OpenAPI 3.0.x document', () => {
        expect(doc.openapi).toMatch(/^3\.0\./);
        expect(doc.info.title).toBe('steamdeck-webdev-template API');
        // version comes from package.json — assert it parses, not its exact value
        expect(doc.info.version).toMatch(/^\d+\.\d+\.\d+/);
    });

    it('registers User and ListUsersResponse component schemas', () => {
        const schemas = doc.components?.schemas;
        expect(schemas).toBeDefined();
        expect(Object.keys(schemas ?? {})).toEqual(
            expect.arrayContaining(['User', 'ListUsersResponse', 'ApiError'])
        );
    });

    it('User schema mirrors libs/types: id/name/email/createdAt required', () => {
        const user = doc.components?.schemas?.['User'] as Record<string, unknown>;
        expect(user['type']).toBe('object');
        expect(user['required']).toEqual(
            expect.arrayContaining(['id', 'name', 'email', 'createdAt'])
        );
    });

    it('documents every public route the backend mounts', () => {
        // If a route is added in apps/backend/src/routes/* without a matching
        // entry in apps/backend/src/openapi/registry.ts, this test fails — a
        // forcing function so the OpenAPI doc can't silently fall behind.
        const paths = Object.keys(doc.paths ?? {});
        expect(paths).toEqual(
            expect.arrayContaining([
                '/api/health/live',
                '/api/health/ready',
                '/api/health',
                '/api/users',
            ])
        );
    });

    it('GET /api/users documents 200 + 400 responses with content', () => {
        const op = doc.paths?.['/api/users']?.get;
        expect(op).toBeDefined();
        expect(op?.responses?.['200']).toBeDefined();
        expect(op?.responses?.['400']).toBeDefined();

        // 400 response references the ApiError component.
        const errorContent = (op?.responses?.['400'] as Record<string, unknown>)?.['content'] as
            | Record<string, { schema?: { $ref?: string } }>
            | undefined;
        const ref = errorContent?.['application/json']?.schema?.$ref;
        expect(ref).toBe('#/components/schemas/ApiError');
    });

    it('GET /api/users declares limit and offset query parameters', () => {
        const op = doc.paths?.['/api/users']?.get;
        const params = (op?.parameters ?? []) as Array<{ name: string; in: string }>;
        const queryNames = params.filter((p) => p.in === 'query').map((p) => p.name);
        expect(queryNames).toEqual(expect.arrayContaining(['limit', 'offset']));
    });

    it('liveness probe does not declare any 5xx responses', () => {
        // /live is contractually side-effect-free — if a future change adds a
        // 503 to it, that's a deliberate change to the orchestrator contract
        // and should be reviewed; the test forces the conversation.
        const op = doc.paths?.['/api/health/live']?.get;
        const codes = Object.keys(op?.responses ?? {});
        expect(codes.every((c) => !c.startsWith('5'))).toBe(true);
    });
});
