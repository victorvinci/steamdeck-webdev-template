/**
 * Lightweight database migration runner.
 *
 * Reads numbered `.sql` files from `db/migrations/`, applies them in order,
 * and records each in a `schema_migrations` table so they're never re-run.
 *
 * Usage:
 *   npx tsx scripts/migrate.ts          # apply pending migrations
 *   npx tsx scripts/migrate.ts --status # show applied vs pending
 *
 * Reads DB credentials from the same `.env` the backend uses.
 */

import 'dotenv/config';
import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = join(__dirname, '..', 'db', 'migrations');

async function getPool() {
    return mysql.createPool({
        host: process.env['DB_HOST'],
        port: Number(process.env['DB_PORT']) || 3306,
        database: process.env['DB_NAME'],
        user: process.env['DB_USER'],
        password: process.env['DB_PASSWORD'],
        multipleStatements: true,
        waitForConnections: true,
        connectionLimit: 1,
    });
}

async function ensureMigrationsTable(pool: mysql.Pool) {
    await pool.execute(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version VARCHAR(255) NOT NULL PRIMARY KEY,
            applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
}

async function getApplied(pool: mysql.Pool): Promise<Set<string>> {
    const [rows] = await pool.execute('SELECT version FROM schema_migrations ORDER BY version');
    return new Set((rows as Array<{ version: string }>).map((r) => r.version));
}

function getMigrationFiles(): string[] {
    return readdirSync(MIGRATIONS_DIR)
        .filter((f) => f.endsWith('.sql'))
        .sort();
}

async function status() {
    const pool = await getPool();
    try {
        await ensureMigrationsTable(pool);
        const applied = await getApplied(pool);
        const files = getMigrationFiles();

        console.log('Migration status:\n');
        for (const file of files) {
            const mark = applied.has(file) ? 'applied' : 'pending';
            console.log(`  [${mark}]  ${file}`);
        }

        const pending = files.filter((f) => !applied.has(f));
        console.log(`\n  ${applied.size} applied, ${pending.length} pending.`);
    } finally {
        await pool.end();
    }
}

async function migrate() {
    const pool = await getPool();
    try {
        await ensureMigrationsTable(pool);
        const applied = await getApplied(pool);
        const files = getMigrationFiles();
        const pending = files.filter((f) => !applied.has(f));

        if (pending.length === 0) {
            console.log('All migrations already applied.');
            return;
        }

        for (const file of pending) {
            const sql = readFileSync(join(MIGRATIONS_DIR, file), 'utf8');
            console.log(`Applying: ${file}`);

            const conn = await pool.getConnection();
            try {
                await conn.query(sql);
                await conn.execute('INSERT INTO schema_migrations (version) VALUES (?)', [file]);
                console.log(`  Done: ${file}`);
            } catch (err) {
                console.error(`  FAILED: ${file}`);
                throw err;
            } finally {
                conn.release();
            }
        }

        console.log(`\n${pending.length} migration(s) applied.`);
    } finally {
        await pool.end();
    }
}

const isStatus = process.argv.includes('--status');
(isStatus ? status() : migrate()).catch((err) => {
    console.error('Migration error:', err instanceof Error ? err.message : err);
    process.exit(1);
});
