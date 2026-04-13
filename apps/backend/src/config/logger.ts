import pino from 'pino';
import { env, isProd } from './env';

/**
 * App-wide structured logger. JSON in production (pipe to any log shipper),
 * pretty-printed in development. Use this instead of `console.*` so every log
 * line carries level, timestamp, and request context.
 */
export const logger = pino({
    level: isProd ? 'info' : 'debug',
    base: { env: env.NODE_ENV },
    redact: {
        paths: ['req.headers.authorization', 'req.headers.cookie', '*.password', '*.token'],
        censor: '[REDACTED]',
    },
    transport: isProd
        ? undefined
        : {
              target: 'pino-pretty',
              options: { colorize: true, translateTime: 'SYS:standard', ignore: 'pid,hostname' },
          },
});
