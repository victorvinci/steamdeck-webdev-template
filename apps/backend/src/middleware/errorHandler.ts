import { Request, Response, NextFunction } from 'express';
import { AppError } from '../errors/AppError';
import { logger } from '../config/logger';
import { isProd } from '../config/env';

/**
 * Express error handler. Classifies errors into two buckets:
 *
 *   1. `AppError` subclasses → expected, operational errors. Surface the
 *      statusCode and message to the client, log at `warn`.
 *   2. Anything else → bug. Log full error at `error`, return a generic 500
 *      so internals never leak to clients.
 */
export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction) {
    if (err instanceof AppError) {
        req.log?.warn({ err, statusCode: err.statusCode }, 'Operational error');
        res.status(err.statusCode).json({ error: err.message });
        return;
    }

    const log = req.log ?? logger;
    log.error({ err }, 'Unhandled error');
    res.status(500).json({
        error: isProd
            ? 'Internal server error'
            : ((err as Error)?.message ?? 'Internal server error'),
    });
}
