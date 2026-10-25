#!/usr/bin/env bash
# Four callers ask DVARA to run the same tool. Run ./dvara/start.sh first.
set -euo pipefail
cd "$(dirname "$0")"
source dvara/.env

token() { # client-id, scopes
  curl -s -u "$1:$1-secret" -d grant_type=client_credentials -d "scope=$2" http://localhost:9000/oauth2/token \
    | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4
}
call() { # bearer credential
  curl -s -w '\n%{http_code}' http://localhost:8080/mcp -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"commerce__check_stock","arguments":{"sku":"HUB-USBC-7"}}}'
}
show() {
  local out status body
  out=$(cat); status=${out##*$'\n'}; body=${out%$'\n'*}
  if [[ $body == *'"text":'* ]]; then
    echo "   allowed: $(grep -oE '\{\\"sku[^}]+\}' <<<"$body" | tr -d '\\')"
  else
    local code=$(grep -oE '"dvara_code":"[^"]+"' <<<"$body" | cut -d'"' -f4)
    local why=$(grep -oE '"(message|error_description)":"[^"]+"' <<<"$body" | head -1 | cut -d'"' -f4)
    echo "   refused (${code:-HTTP $status}): $why"
  fi
}

echo "1. commerce-agent, scopes mcp:read mcp:call"
call "$(token commerce-agent 'mcp:read mcp:call')" | show

echo "2. reporting-agent, scope mcp:read only"
call "$(token reporting-agent 'mcp:read')" | show

echo "3. unknown-agent, a valid token from a client DVARA does not allow"
call "$(token unknown-agent 'mcp:read mcp:call')" | show

echo "4. the workspace API key from lesson 7"
call "$DVARA_API_KEY" | show
