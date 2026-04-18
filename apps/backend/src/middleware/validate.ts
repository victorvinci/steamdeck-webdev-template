import { Request, Response, NextFunction } from 'express';
import { ZodSchema } from 'zod';

type Source = 'body' | 'query' | 'params';

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
        // req.query is read-only in Express 5; store parsed data on res.locals
        // so downstream handlers can access the coerced/defaulted values.
        if (source === 'query') {
            res.locals.validatedQuery = result.data;
        } else {
            Object.assign(req[source] as object, result.data);
        }
        next();
    };
}
