import mysql from 'mysql2/promise';
import { env } from './env';
import { logger } from './logger';

export const db = mysql.createPool({
    host: env.DB_HOST,
    port: env.DB_PORT,
    database: env.DB_NAME,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    connectionLimit: env.DB_CONNECTION_LIMIT,
    waitForConnections: true,
    namedPlaceholders: true,
});

db.pool.on('error', (err) => {
    logger.error({ err }, 'database pool error');
});
