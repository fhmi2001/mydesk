#!/bin/bash
# MyDesk: create a WhatsApp (QR) number for a Chatwoot account. Evolution API creates the
# matching API-channel inbox in that account; scan the QR from the manager UI or the
# "EvolutionAPI" bot conversation inside the inbox.
#
#   deploy/whatsapp/create_instance.sh <instance-name> <account-id> <agent-email> [inbox-name]
#
# The agent's API token is read from Chatwoot and sent only to the local gateway; nothing is printed.
set -euo pipefail

name="${1:?instance name}"; account_id="${2:?account id}"; email="${3:?agent email}"
inbox_name="${4:-WhatsApp}"
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.."

api_key="$(grep -E '^AUTHENTICATION_API_KEY=' "$here/.env" | cut -d= -f2-)"
token="$(docker compose exec -T rails bundle exec rails runner \
  "print User.find_by!(email: ARGV[0]).access_token.token" "$email" 2>/dev/null | tail -1)"
[ -n "$token" ] || { echo "No Chatwoot user/token for $email"; exit 1; }

payload="$(python3 - "$name" "$account_id" "$token" "$inbox_name" <<'PY'
import json, sys
name, account_id, token, inbox = sys.argv[1:]
print(json.dumps({
    "instanceName": name,
    "integration": "WHATSAPP-BAILEYS",
    "qrcode": True,
    "groupsIgnore": True,
    "chatwootAccountId": account_id,
    "chatwootToken": token,
    "chatwootUrl": "http://rails:3000",
    "chatwootNameInbox": inbox,
    "chatwootSignMsg": False,
    "chatwootReopenConversation": True,
    "chatwootConversationPending": False,
    "chatwootImportContacts": False,
    "chatwootImportMessages": False,
    "chatwootMergeBrazilContacts": False,
    "chatwootOrganization": "MyDesk",
    "chatwootLogo": "",
    "autoCreate": True,
}))
PY
)"

curl -s -X POST http://localhost:8080/instance/create \
  -H "apikey: $api_key" -H 'Content-Type: application/json' -d "$payload" |
  python3 -c 'import json,sys; d=json.load(sys.stdin); i=d.get("instance",{}); print("status:", i.get("status") or d.get("status"), "| instance:", i.get("instanceName"), "| error:", d.get("response") or d.get("error") or "-")'
