import { Request, Response, NextFunction } from 'express';
import { ZodSchema } from 'zod';

type Source = 'body' | 'query' | 'params';

/**
 * Validate `req[source]` against a Zod schema. On success, expose the parsed
 * data on `res.locals.validated{Body,Query,Params}` and call `next()`. Handlers
 * must read from `res.locals.*`, not `req.*` — `req.body` / `req.params` still
 * hold the caller's original (unvalidated) payload, including any extras Zod
 * stripped. Not mutating `req` also avoids a latent prototype-pollution surface
 * if a schema ever lets `__proto__` through.
 */
export function validate(schema: ZodSchema, source: Source = 'body') {
    return (req: Request, res: Response, next: NextFunction) => {
        const result = schema.safeParse(req[source]);
        if (!result.success) {
            res.status(400).json({
                error: 'Validation failed',
                issues: result.error.issues.map((i) => ({
                    path: i.path.join('.'),
                    message: i.message,
                })),
            });
            return;
        }
        if (source === 'body') res.locals.validatedBody = result.data;
        else if (source === 'query') res.locals.validatedQuery = result.data;
        else res.locals.validatedParams = result.data;
        next();
    };
}
