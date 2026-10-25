#!/usr/bin/env bash
# The production gap: the full commerce server with nothing in front of it.
# Start the server first: jbang CommerceServer.java | tee server.log
set -euo pipefail
cd "$(dirname "$0")"
URL=${1:-http://localhost:8070/mcp}

# In a terminal, wait for Enter before each gap after the first, so you can look at one at a time.
# Piped or redirected, or with NO_PAUSE=1, it runs straight through.
first=1
step() {
  if [[ -z $first && -t 0 && -t 1 && -z ${NO_PAUSE:-} ]]; then read -rs; fi
  first=
  printf '\n\033[1;31m%s\033[0m\n' "$*"
}
post() { # body, [session] -> the JSON answer, whether plain or an event stream
  curl -s "$URL" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    ${2:+-H "Mcp-Session-Id: $2"} -d "$1" | sed 's/^data://' | grep '^{' || true
}
session=$(curl -s -D - -o /dev/null "$URL" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"anyone","version":"1.0"}}}' \
  | grep -i '^mcp-session-id:' | cut -d' ' -f2 | tr -d '\r')
post '{"jsonrpc":"2.0","method":"notifications/initialized"}' "$session" >/dev/null
call() { # tool, arguments-json
  post "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}" "$session" \
    | grep -oE '"text":"[^"]*(\\"[^"]*)*"' | head -1 | cut -c9- | tr -d '\\' | sed 's/"$//'
}

step "1. Who are you? Nobody asks."
echo "   This script sent no credential at all. The server answered: $(call check_stock '{"sku":"HUB-USBC-7"}')"

step "2. Personal data goes straight to the agent (and to the model behind it)."
echo "   $(call lookup_customer '{"customerId":"C-42"}')"

step "3. A stuck agent can loop for ever."
ok=0; for i in $(seq 1 20); do [[ $(call check_delivery '{"quoteId":"Q-1a2b3c4d"}') == *"still being booked"* ]] && ok=$((ok+1)); done
echo "   20 identical check_delivery calls in a row: $ok of 20 reached the server."

step "4. Money moves on the agent's word alone."
echo "   $(call issue_refund '{"quoteId":"Q-5425b0d2","amount":24500.00}')"

step "5. Nothing stops a flood."
start=$(date +%s)
ok=0; for i in $(seq 1 50); do [[ $(call check_stock '{"sku":"HUB-USBC-7"}') == *available* ]] && ok=$((ok+1)); done
echo "   50 calls in $(( $(date +%s) - start ))s: $ok of 50 answered."

step "6. Afterwards: who did it?"
if [[ -f server.log ]]; then
  echo "   The server's own record of the refund:"
  grep 'REFUND EXECUTED' server.log | tail -1 | grep -oE 'REFUND EXECUTED.*' | sed 's/^/   /'
  echo "   An amount and a quote. No caller, no agent, no session: the server never knew."
else
  echo "   (start the server with: jbang CommerceServer.java | tee server.log)"
fi

cat <<'EOF'

The rest of the course closes each gap:
   1 -> lesson 8  (OAuth: every agent signs in)      4 -> lesson 12 (a person approves)
   2 -> lesson 10 (PII redacted both ways)           5 -> lesson 13 (rate limit per agent)
   3 -> lesson 11 (loop detection, kill a session)   6 -> lesson 9  (signed audit with the agent's identity)
EOF
