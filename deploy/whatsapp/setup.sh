#!/bin/bash
# MyDesk: one-time setup of the WhatsApp (QR) gateway next to a running Chatwoot.
#  - writes deploy/whatsapp/.env from .env.example (random API key, Chatwoot's Postgres/Redis passwords)
#  - creates the `evolution` database on Chatwoot's Postgres
#  - starts the gateway as its own Docker project
# Safe to re-run: an existing .env and database are kept.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
cd "$root"

env_value() { grep -E "^$1=" .env | tail -1 | cut -d= -f2- | tr -d '"' || true; }
urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

if [ ! -f "$here/.env" ]; then
  pg_pass="$(urlencode "$(env_value POSTGRES_PASSWORD)")"
  redis_pass="$(urlencode "$(env_value REDIS_PASSWORD)")"
  api_key="$(openssl rand -hex 24)"
  sed -e "s|^AUTHENTICATION_API_KEY=.*|AUTHENTICATION_API_KEY=$api_key|" \
      -e "s|postgresql://postgres:@postgres|postgresql://postgres:$pg_pass@postgres|" \
      -e "s|redis://:@redis|redis://:$redis_pass@redis|" \
      "$here/.env.example" > "$here/.env"
  chmod 600 "$here/.env"
  echo "Wrote deploy/whatsapp/.env (API key generated, not printed)"
fi

if ! docker compose exec -T postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='evolution'" | grep -q 1; then
  docker compose exec -T postgres psql -U postgres -qc 'CREATE DATABASE evolution'
  echo "Created database: evolution"
fi

docker compose -f "$here/docker-compose.yaml" up -d
echo "Gateway starting: http://localhost:8080/manager"
