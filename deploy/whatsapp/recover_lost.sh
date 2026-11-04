#!/bin/bash
# MyDesk: bring WhatsApp Web messages that reached the gateway while the platform was down into their conversations.
#   deploy/whatsapp/recover_lost.sh          # last 3 days
#   DAYS=7 DRY_RUN=1 deploy/whatsapp/recover_lost.sh
# Reads the gateway's own database (messages it never handed over), then runs recover_lost.rb on the platform.
# Nothing is sent to WhatsApp. Media is not copied: a voice note shows as a line asking to open it on the phone.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.."
days="${DAYS:-3}"
[[ "$days" =~ ^[0-9]+$ ]] || { echo "DAYS must be a number" >&2; exit 1; }

docker compose exec -T postgres psql -U postgres -d evolution -tA -v ON_ERROR_STOP=1 >tmp/whatsapp_lost.json <<SQL
SELECT coalesce(json_agg(x), '[]') FROM (
  SELECT i.name AS instance, m.key->>'remoteJid' AS jid, m.key->>'remoteJidAlt' AS alt,
         (m.key->>'fromMe')::boolean AS from_me, m.key->>'id' AS wid, m."pushName" AS push_name,
         m."messageType" AS type, m."messageTimestamp" AS ts,
         coalesce(m.message->>'conversation', m.message#>>'{extendedTextMessage,text}') AS text
  FROM "Message" m JOIN "Instance" i ON i.id = m."instanceId"
  WHERE m."chatwootMessageId" IS NULL AND (m.key->>'remoteJid') NOT LIKE '%@g.us'
    AND to_timestamp(m."messageTimestamp") > now() - interval '$days days'
) x
SQL

docker compose exec -T -e DRY_RUN="${DRY_RUN:-}" rails bundle exec rails runner deploy/whatsapp/recover_lost.rb
rm -f tmp/whatsapp_lost.json
