#!/bin/bash
# MyDesk: least-privilege database access for the gateway. After sending a reply, Evolution records the
# WhatsApp message id on the platform's message (UPDATE messages SET source_id, status, created_at,
# updated_at). This role can read `messages` and update only those columns; no other table.
# Writes CHATWOOT_IMPORT_DATABASE_CONNECTION_URI into deploy/whatsapp/.env. Safe to re-run.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.."

role=mydesk_evolution
database="$(grep -E '^POSTGRES_DATABASE=' .env | cut -d= -f2- || true)"
database="${database:-chatwoot_dev}"

if grep -q '^CHATWOOT_IMPORT_DATABASE_CONNECTION_URI=' "$here/.env"; then
  password="$(grep -E '^CHATWOOT_IMPORT_DATABASE_CONNECTION_URI=' "$here/.env" | sed -E 's|.*://[^:]+:([^@]+)@.*|\1|')"
else
  password="$(openssl rand -hex 24)"
  echo "CHATWOOT_IMPORT_DATABASE_CONNECTION_URI=postgresql://$role:$password@postgres:5432/$database?sslmode=disable" >> "$here/.env"
fi

docker compose exec -T postgres psql -U postgres -d "$database" -v ON_ERROR_STOP=1 -q \
  -v role="$role" -v password="$password" -v database="$database" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'role') WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'role', :'password') \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database', :'role') \gexec
SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'role') \gexec
SELECT format('GRANT SELECT ON messages TO %I', :'role') \gexec
SELECT format('GRANT UPDATE (source_id, status, created_at, updated_at) ON messages TO %I', :'role') \gexec
SQL
echo "Database access for $role on $database: read messages, update 4 columns"
