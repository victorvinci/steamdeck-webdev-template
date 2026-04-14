#!/usr/bin/env bash
set -euo pipefail

# Native MySQL bootstrap — used when Docker isn't available (e.g. SteamOS, sandboxed hosts).
# Provisions the database and application user against a locally-running mysqld, then loads
# db/schema.sql. Idempotent: safe to re-run.
#
# Requires:
#   - mysql client + a running mysqld reachable on localhost:${DB_PORT:-3306}
#   - sudo access to connect to MySQL as root via the unix socket
#     (auth_socket plugin — the default on Debian/Ubuntu mysql-server packages).
#
# For the Docker-based flow see scripts/dev-setup.sh, which delegates here when docker is missing.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f .env ]; then
    echo "Creating .env from .env.example — review and edit before running the app."
    cp .env.example .env
fi

if ! command -v mysql >/dev/null 2>&1; then
    echo "mysql client not found. Install the mysql-client package, then re-run." >&2
    exit 1
fi

# shellcheck disable=SC1091
set -a; . ./.env; set +a

: "${DB_NAME:?DB_NAME missing from .env}"
: "${DB_USER:?DB_USER missing from .env}"
: "${DB_PASSWORD:?DB_PASSWORD missing from .env}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"

if ! (ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${DB_PORT}$"); then
    echo "No process listening on ${DB_HOST}:${DB_PORT}. Start mysqld first (e.g. 'service mysql start')." >&2
    exit 1
fi

if [[ "$DB_PASSWORD" == *"'"* ]]; then
    echo "DB_PASSWORD contains a single quote — not supported by this script. Pick a password without quotes." >&2
    exit 1
fi

echo "Provisioning MySQL database '${DB_NAME}' and user '${DB_USER}'@'localhost' via sudo..."
sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "Loading db/schema.sql into '${DB_NAME}'..."
MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" < db/schema.sql

echo "Native MySQL setup complete."
