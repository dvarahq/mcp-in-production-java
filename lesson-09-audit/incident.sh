#!/usr/bin/env bash
# Replays Sunday night: three agents use the commerce tools through DVARA. Run ./dvara/start.sh first.
set -euo pipefail
cd "$(dirname "$0")"

token() { # client-id
  curl -s -u "$1:$1-secret" -d grant_type=client_credentials -d 'scope=mcp:read mcp:call' \
    http://localhost:9000/oauth2/token | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4
}
call() { # token, tool, arguments-json
  curl -s http://localhost:8080/mcp -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"commerce__$2\",\"arguments\":$3}}"
}
quote_id() { grep -oE 'Q-[0-9a-f]{8}' | head -1; }

echo "Sunday night..."
support=$(token commerce-agent)
call "$support" search_products '{"query":"usb-c cable"}' >/dev/null
call "$support" check_stock '{"sku":"CBL-USBC-1M"}' >/dev/null
call "$support" create_quote '{"sku":"CBL-USBC-1M","quantity":3}' >/dev/null
call "$support" create_quote '{"sku":"HUB-USBC-7","quantity":2}' >/dev/null

sales=$(token sales-bot)
call "$sales" search_products '{"query":"hub"}' >/dev/null
bad=$(call "$sales" create_quote '{"sku":"HUB-USBC-7","quantity":500}' | quote_id)
for _ in 1 2 3 4; do call "$sales" create_quote '{"sku":"HUB-USBC-7","quantity":500}' >/dev/null; done

stranger=$(token unknown-agent)
for _ in 1 2 3; do call "$stranger" create_quote '{"sku":"HUB-USBC-7","quantity":1}' >/dev/null; done

cat <<EOF
...done.

Monday, 9:00. A customer writes in:
  "We received quote $bad for 500 USB-C hubs, \$24,500. Nobody here asked for it."

Which agent made $bad, and what else did it do? See README.md, "Investigate".
EOF
