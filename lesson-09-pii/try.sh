#!/usr/bin/env bash
# Personal data in a tool's result and in its arguments, through DVARA. Run ./dvara/start.sh first.
set -euo pipefail
cd "$(dirname "$0")"

token=$(curl -s -u commerce-agent:commerce-agent-secret -d grant_type=client_credentials \
  -d 'scope=mcp:read mcp:call' http://localhost:9000/oauth2/token | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4)
call() { # tool, arguments-json
  curl -s http://localhost:8080/mcp -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"commerce__$1\",\"arguments\":$2}}" \
    | grep -oE '"text":"[^}]*}?' | head -1 | cut -c9- | tr -d '\\'
}

echo "1. lookup_customer C-42. The server returns email, phone and card. The agent receives:"
echo "   $(call lookup_customer '{"customerId":"C-42"}')"
echo

note='Leave at the back door. Charge card 4111 1111 1111 1111, receipt to jane.doe@example.com'
echo "2. add_order_note. The agent sends:"
echo "   $note"
call add_order_note "{\"quoteId\":\"Q-1a2b3c4d\",\"note\":\"$note\"}" >/dev/null
echo "   The server receives (its log):"
if [[ -f server.log ]]; then
  for _ in 1 2 3 4 5; do grep -q 'note on' server.log && break; sleep 1; done
  grep 'note on' server.log | tail -1 | grep -oE 'received: .*' | sed 's/ trace=.*//; s/^/   /'
else
  echo "   (start the server with: jbang CommerceServer.java | tee server.log)"
fi
