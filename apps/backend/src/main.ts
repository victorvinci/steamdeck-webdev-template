import { env, isProd } from './config/env';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import pinoHttp from 'pino-http';
import { randomUUID } from 'node:crypto';
import { logger } from './config/logger';
import { db } from './config/db';
import healthRouter from './routes/health';
import usersRouter from './routes/users';
import { notFound } from './middleware/notFound';
import { errorHandler } from './middleware/errorHandler';

const app = express();

app.disable('x-powered-by');
app.set('trust proxy', isProd ? 1 : false);

// Client-supplied x-request-id is forwarded into logs and echoed in the
// response header, so bound its shape: short, ASCII-alnum-plus-dash. Anything
// else gets a fresh UUID — blocks log-injection (newlines), storage bloat
// (long strings), and header-smuggling attempts.
const REQUEST_ID_RE = /^[a-zA-Z0-9-]{1,64}$/;

app.use(
    pinoHttp({
        logger,
        genReqId: (req, res) => {
            const incoming = req.headers['x-request-id'];
            const id =
                typeof incoming === 'string' && REQUEST_ID_RE.test(incoming)
                    ? incoming
                    : randomUUID();
            res.setHeader('x-request-id', id);
            return id;
        },
        customLogLevel: (_req, res, err) => {
            if (err || res.statusCode >= 500) return 'error';
            if (res.statusCode >= 400) return 'warn';
            return 'info';
        },
    })
);

app.use(
    helmet({
        contentSecurityPolicy: {
            useDefaults: true,
            directives: {
                'default-src': ["'self'"],
                'script-src': ["'self'"],
                'object-src': ["'none'"],
                'frame-ancestors': ["'none'"],
            },
        },
        crossOriginResourcePolicy: { policy: 'same-site' },
        referrerPolicy: { policy: 'no-referrer' },
    })
);

app.use(
    cors({
        origin: env.FRONTEND_URL,
        credentials: true,
        exposedHeaders: ['x-request-id'],
    })
);

app.use(express.json({ limit: '100kb' }));
app.use(express.urlencoded({ extended: false, limit: '100kb' }));

app.use(
    rateLimit({
        windowMs: 60_000,
        limit: 100,
        standardHeaders: 'draft-7',
        legacyHeaders: false,
        // Orchestrator probes (Kubernetes liveness/readiness, load
        // balancers) hit /api/health/* on every interval and would
        // otherwise burn the per-IP budget during rolling deploys.
        skip: (req) => req.path.startsWith('/api/health'),
    })
);

app.use('/api', healthRouter);
app.use('/api', usersRouter);

app.use(notFound);
app.use(errorHandler);

const server = app.listen(env.PORT, env.HOST, (err?: Error) => {
    if (err) {
        logger.fatal({ err }, 'failed to start server');
        process.exit(1);
    }
    logger.info(`ready on http://${env.HOST}:${env.PORT}`);
});

/**
 * Graceful shutdown: on SIGTERM/SIGINT, stop accepting new connections,
 * drain in-flight requests, close the MySQL pool, then exit. Give the
 * platform 10s before forcing termination so a hung request can't block a
 * deploy forever.
 */
const shutdown = async (signal: string) => {
    logger.info({ signal }, 'shutdown: draining');
    const forceExit = setTimeout(() => {
        logger.error('shutdown: force exit after 10s');
        process.exit(1);
    }, 10_000).unref();

    server.close(async (err) => {
        if (err) logger.error({ err }, 'shutdown: server close error');
        try {
            await db.end();
            logger.info('shutdown: clean');
        } catch (poolErr) {
            logger.error({ err: poolErr }, 'shutdown: db pool close error');
        } finally {
            clearTimeout(forceExit);
            process.exit(err ? 1 : 0);
        }
    });
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
