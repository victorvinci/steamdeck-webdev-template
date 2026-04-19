-- Bootstrap script for first-time database init.
--
-- Docker-compose mounts this at /docker-entrypoint-initdb.d/ so MySQL
-- runs it on first startup. CI also loads it via `mysql < db/schema.sql`.
--
-- This file aggregates the numbered migration files in db/migrations/ so
-- the schema stays in one place. When you add a new migration, SOURCE it
-- here too (MySQL's SOURCE is not available in all contexts, so we inline
-- the SQL instead — keep this file in sync with db/migrations/).
--
-- For subsequent schema changes after first init, use the migration runner:
--   npm run migrate

-- ---------- schema_migrations tracking table ----------

CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) NOT NULL PRIMARY KEY,
    applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- 001_initial.sql ----------

CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO users (id, name, email) VALUES
    (1, 'Ada Lovelace',   'ada@example.com'),
    (2, 'Alan Turing',    'alan@example.com'),
    (3, 'Grace Hopper',   'grace@example.com');

-- Mark migrations as applied so `npm run migrate` doesn't re-run them.
INSERT IGNORE INTO schema_migrations (version) VALUES ('001_initial.sql');
