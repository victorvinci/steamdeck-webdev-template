-- Initial database schema. Loaded automatically by docker-compose on first startup.
-- Replace these placeholder tables with your real schema when you fork the boilerplate.

CREATE TABLE IF NOT EXISTS schema_version (
    version INT UNSIGNED NOT NULL PRIMARY KEY,
    applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO schema_version (version) VALUES (1);

-- Seed a couple of rows so the boilerplate's example route returns real data on first boot.
INSERT IGNORE INTO users (id, name, email) VALUES
    (1, 'Ada Lovelace',   'ada@example.com'),
    (2, 'Alan Turing',    'alan@example.com'),
    (3, 'Grace Hopper',   'grace@example.com');
