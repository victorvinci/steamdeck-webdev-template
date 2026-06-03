// MUST be the first import in the entire backend bundle. Adds .openapi() to
// Zod's prototype before any schema is constructed elsewhere. Zod 4 schemas
// lock their prototype chain at construction time — schemas built before
// `extendZodWithOpenApi(z)` runs do NOT pick up the method retroactively
// (a behaviour change vs. Zod 3). `usersRouter` below imports `@mcb/types`,
// which evaluates the schema definitions, so the extension has to run first.
// Putting the side-effect import inside `openapi/registry.ts` is enough for
// `scripts/gen-openapi.ts` (which imports only registry.ts) but NOT for the
// runtime backend, because there `@mcb/types` is already loaded via
// `routes/users.ts` long before `openapi/serve.ts` is reached.
import './openapi/zod-extension';

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
import { mountDocs } from './openapi/serve';

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

// API documentation routes (Swagger UI + raw OpenAPI JSON). Non-prod only —
// see openapi/serve.ts for the rationale. Mounted BEFORE healthRouter and
// usersRouter so the /api/openapi.json route doesn't collide with the
// catch-all 404 handler, and AFTER cors() so the browser can fetch the
// JSON cross-origin from a Swagger UI hosted elsewhere.
if (!isProd) {
    mountDocs(app);
}

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

// HTTP timeout hardening. Node's default `keepAliveTimeout` (5s) is SHORTER
// than the idle timeout of most load balancers (AWS ALB defaults to 60s),
// which causes intermittent 502s: the LB reuses a keep-alive socket in the
// brief window after Node has independently decided to close it. The fix is
// to keep Node's socket open longer than the LB's idle timeout, and to make
// `headersTimeout` larger than `keepAliveTimeout` so a slow client can't
// outlast the keep-alive window. 65s/66s clears the common 60s LB default —
// raise both if your load balancer's idle timeout is higher.
server.keepAliveTimeout = 65_000;
server.headersTimeout = 66_000;

/**
 * Graceful shutdown: stop accepting new connections, drain in-flight
 * requests, close the MySQL pool, then exit. Triggered by SIGTERM/SIGINT
 * (normal orchestrator stop) and by the fatal-error handlers below. Give the
 * platform 10s before forcing termination so a hung request can't block a
 * deploy forever. The `shuttingDown` guard makes this idempotent — a second
 * signal, or a fatal error racing a signal, won't double-close the server.
 */
let shuttingDown = false;
const shutdown = async (reason: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info({ reason }, 'shutdown: draining');
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

// Last-resort handlers for errors that escape request scope. Express 5
// already forwards errors thrown (or rejected) inside route handlers to
// `errorHandler`, so these catch the things it can't: a rejected promise with
// no `.catch`, or a synchronous throw in a timer/event callback. Without
// them, Node prints a bare V8 stack trace and exits, bypassing pino and the
// MySQL pool cleanup. An uncaught exception leaves the process in an
// undefined state, so this is a structured log + graceful drain + exit — NOT
// a "keep serving" recovery (which would risk acting on corrupt state).
process.on('unhandledRejection', (reason) => {
    logger.fatal({ err: reason }, 'unhandledRejection — shutting down');
    void shutdown('unhandledRejection');
});
process.on('uncaughtException', (err) => {
    logger.fatal({ err }, 'uncaughtException — shutting down');
    void shutdown('uncaughtException');
});
