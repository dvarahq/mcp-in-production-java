#!/usr/bin/env bash
# Plays an agent stuck polling check_delivery, all in one session. Run ./dvara/start.sh first.
#   ./runaway.sh              start a new session and poll 7 times
#   ./runaway.sh <session>    make one call on an existing session (after you kill it)
set -euo pipefail
cd "$(dirname "$0")"

token=$(curl -s -u commerce-agent:commerce-agent-secret -d grant_type=client_credentials \
  -d 'scope=mcp:read mcp:call' http://localhost:9000/oauth2/token | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4)
call() { # session
  curl -s http://localhost:8080/mcp -H "Authorization: Bearer $token" -H "X-Session-Id: $1" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"commerce__check_delivery","arguments":{"quoteId":"Q-1a2b3c4d"}}}'
}
show() {
  local r; r=$(cat)
  if [[ $r == *'"error":{'* ]]; then
    echo "refused ($(grep -oE '"dvara_code":"[^"]+"' <<<"$r" | cut -d'"' -f4)): $(grep -oE '"message":"[^"]+"' <<<"$r" | cut -d'"' -f4)"
  else
    echo "reached the server: $(grep -oE 'still being booked' <<<"$r")"
  fi
}

if [[ $# -eq 1 ]]; then
  echo "session $1: $(call "$1" | show)"
  exit 0
fi

session="runaway-$(openssl rand -hex 3)"
echo "session $session"
for i in 1 2 3 4 5 6 7; do
  echo "  call $i: $(call "$session" | show)"
done
cat <<EOF

DVARA refused the fifth identical call in a row. The agent can still start over in this
session with a different tool. To stop it, kill the session:

  Flightdeck -> MCP -> Sessions -> $session -> Kill session
  (it can take a minute to appear; "Kill a session by id" at the top works right away)

then check:  ./runaway.sh $session
EOF
