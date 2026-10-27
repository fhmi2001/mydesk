#!/bin/bash
# MyDesk: stop the gateway adding "Agent name:" on top of replies, for every existing number.
# Re-saves each number's Chatwoot settings with signMsg=false; nothing else changes and no inbox is created.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
api_key="$(grep -E '^AUTHENTICATION_API_KEY=' "$here/.env" | cut -d= -f2-)"
gateway="http://localhost:8080"

names="$(curl -s "$gateway/instance/fetchInstances" -H "apikey: $api_key" |
  python3 -c 'import json,sys; print(" ".join(i["name"] for i in json.load(sys.stdin)))')"

for name in $names; do
  settings="$(curl -s "$gateway/chatwoot/find/$name" -H "apikey: $api_key")"
  payload="$(SETTINGS="$settings" python3 -c '
import json, os
s = json.loads(os.environ["SETTINGS"]) or {}
s.pop("webhook_url", None)
s.update(signMsg=False, autoCreate=False)
print(json.dumps(s))')"
  result="$(curl -s -X POST "$gateway/chatwoot/set/$name" -H "apikey: $api_key" \
    -H 'Content-Type: application/json' -d "$payload")"
  RESULT="$result" python3 -c '
import json, os, sys
r = json.loads(os.environ["RESULT"]) or {}
c = r.get("chatwoot", r)
print(sys.argv[1], "signMsg =", c.get("signMsg"), "| error:", r.get("response") or r.get("error") or "-")' "$name"
done
