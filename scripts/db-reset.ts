/**
 * Local-only database reset.
 *
 * Wipes every table in the configured database, re-applies all
 * `db/migrations/*.sql` from scratch, then loads `db/seed.sql` for a
 * predictable dev dataset. Useful when:
 *
 *   - A migration was edited (the runner only applies pending files,
 *     so re-editing an already-applied migration is otherwise a no-op).
 *   - Dev data drifted into a confusing state and you'd rather start over.
 *   - You want to verify a fresh migrate path before opening a PR.
 *
 * Usage:
 *   npm run db:reset
 *
 * Refuses to run when `NODE_ENV=production`. The check is paranoid by
 * design — destroying data on the wrong machine is worse than a false
 * negative on a misconfigured laptop.
 *
 * Reads DB credentials from the same `.env` the backend uses.
 */

import 'dotenv/config';
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const SEED_PATH = join(ROOT, 'db', 'seed.sql');
const MIGRATE_SCRIPT = join(ROOT, 'scripts', 'migrate.ts');

function refuseInProduction(): void {
    const env = process.env['NODE_ENV'];
    if (env === 'production') {
        console.error('db:reset refuses to run when NODE_ENV=production.');
        console.error('  This script DROPs every table in the configured database.');
        console.error('  If you genuinely meant to wipe a non-prod DB, set NODE_ENV explicitly.');
        process.exit(2);
    }
}

async function getConnection() {
    return mysql.createConnection({
        host: process.env['DB_HOST'],
        port: Number(process.env['DB_PORT']) || 3306,
        database: process.env['DB_NAME'],
        user: process.env['DB_USER'],
        password: process.env['DB_PASSWORD'],
        multipleStatements: true,
    });
}

async function dropAllTables(conn: mysql.Connection, dbName: string): Promise<void> {
    const [rows] = await conn.query<mysql.RowDataPacket[]>(
        `SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_TYPE = 'BASE TABLE'`,
        [dbName]
    );
    const tables = rows.map((r) => r['TABLE_NAME'] as string);

    if (tables.length === 0) {
        console.log('  (database has no tables — nothing to drop)');
        return;
    }

    // Disable foreign-key checks for the duration so DROP order doesn't matter.
    // Each statement runs against the same connection so the SET sticks.
    await conn.query('SET FOREIGN_KEY_CHECKS = 0');
    for (const table of tables) {
        // Identifier is sourced from INFORMATION_SCHEMA on the same connection
        // — not user input — so the backtick-wrap is sufficient against the
        // possibility of an unusual table name. mysql2 has no parameter
        // placeholder for identifiers (`?` is for values only).
        const identifier = '`' + table.replace(/`/g, '``') + '`';
        await conn.query(`DROP TABLE IF EXISTS ${identifier}`);
        console.log(`  dropped: ${table}`);
    }
    await conn.query('SET FOREIGN_KEY_CHECKS = 1');
}

function runMigrations(): void {
    // Spawn the existing migration runner instead of re-implementing it here,
    // so a future change to migrate.ts (transaction handling, error reporting,
    // etc.) is automatically inherited. `inherit` for stdio so the child's
    // output appears interleaved with this script's progress prints.
    const result = spawnSync('npx', ['tsx', MIGRATE_SCRIPT], {
        cwd: ROOT,
        stdio: 'inherit',
        env: process.env,
    });
    if (result.status !== 0) {
        throw new Error(`migrate.ts exited with status ${result.status ?? 'null'}`);
    }
}

async function loadSeed(conn: mysql.Connection): Promise<void> {
    if (!existsSync(SEED_PATH)) {
        console.log('  (db/seed.sql not present — skipping seed step)');
        return;
    }
    const sql = readFileSync(SEED_PATH, 'utf8');
    await conn.query(sql);
    console.log('  loaded: db/seed.sql');
}

async function main(): Promise<void> {
    refuseInProduction();

    const dbName = process.env['DB_NAME'];
    if (!dbName) {
        console.error('db:reset: DB_NAME is required (read from .env).');
        process.exit(1);
    }

    console.log(`db:reset against database "${dbName}" on ${process.env['DB_HOST'] ?? '?'}\n`);

    let conn: mysql.Connection | undefined;
    try {
        conn = await getConnection();

        console.log('Step 1/3 — dropping existing tables');
        await dropAllTables(conn, dbName);

        // Close the connection before spawning migrate.ts so it doesn't
        // contend with our session for any locks. migrate.ts opens its own
        // pool against the same env.
        await conn.end();
        conn = undefined;

        console.log('\nStep 2/3 — applying migrations');
        runMigrations();

        console.log('\nStep 3/3 — loading seed data');
        conn = await getConnection();
        await loadSeed(conn);

        console.log('\nDone.');
    } finally {
        if (conn) await conn.end();
    }
}

main().catch((err) => {
    console.error('db:reset error:', err instanceof Error ? err.message : err);
    process.exit(1);
});
