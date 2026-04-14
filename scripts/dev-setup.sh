#!/usr/bin/env bash
set -euo pipefail

# One-shot local dev bootstrap. Idempotent — safe to run repeatedly.
# Requires: docker (with compose plugin), node >= 20.12, npm >= 10.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f .env ]; then
    echo "Creating .env from .env.example — review and edit before running the app."
    cp .env.example .env
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found — falling back to native MySQL bootstrap (scripts/dev-setup-native.sh)."
    echo "(Install Docker if you'd prefer the containerized flow this script normally uses.)"
    exec bash "$ROOT/scripts/dev-setup-native.sh"
fi

echo "Starting MySQL via docker compose..."
docker compose up -d mysql

echo "Waiting for MySQL to become healthy..."
for i in {1..30}; do
    status="$(docker inspect -f '{{.State.Health.Status}}' mcb-mysql 2>/dev/null || echo starting)"
    if [ "$status" = "healthy" ]; then
        echo "MySQL is healthy."
        exit 0
    fi
    sleep 1
done

echo "MySQL did not become healthy in time. Check 'docker compose logs mysql'." >&2
exit 1
