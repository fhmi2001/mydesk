#!/bin/bash
# MyDesk: ask the gateway for a fresh QR code for an instance. The QR is posted as an image to the
# bot conversation in the instance's inbox; with --html <file> it is also written to a local page.
#
#   deploy/whatsapp/connect.sh <instance-name> [--html /path/qr.html]
set -euo pipefail

name="${1:?instance name}"
here="$(cd "$(dirname "$0")" && pwd)"
api_key="$(grep -E '^AUTHENTICATION_API_KEY=' "$here/.env" | cut -d= -f2-)"

response="$(curl -s "http://localhost:8080/instance/connect/$name" -H "apikey: $api_key")"

if [ "${2:-}" = "--html" ] && [ -n "${3:-}" ]; then
  QR_RESPONSE="$response" python3 - "$3" "$name" <<'PY'
import json, os, sys
out, name = sys.argv[1], sys.argv[2]
data = json.loads(os.environ["QR_RESPONSE"])
image = data.get("base64")
if not image:
    print("no QR (state:", data.get("instance", {}).get("state", data), ")")
    sys.exit(0)
with open(out, "w", encoding="utf-8") as f:
    f.write(f"""<!doctype html><meta charset="utf-8"><title>WhatsApp QR</title>
<body style="margin:0;display:grid;place-items:center;min-height:100vh;background:#fff;font-family:sans-serif">
<div style="text-align:center"><img src="{image}" width="320" height="320" alt="WhatsApp QR">
<p>{name}: WhatsApp &gt; Linked devices &gt; Link a device</p></div></body>""")
print("QR written:", out)
PY
else
  python3 -c 'import json,sys; d=json.load(sys.stdin); print("QR ready" if d.get("base64") else d)' <<<"$response"
fi
