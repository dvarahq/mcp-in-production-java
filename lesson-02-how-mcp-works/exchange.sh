#!/usr/bin/env bash
# One MCP conversation, as raw HTTP: initialize, initialized, tools/list, tools/call.
# Start the server first: jbang CommerceServer.java
set -euo pipefail
URL=${1:-http://localhost:8070/mcp}

pretty() { # prints the JSON answer; says when the server answered as an event stream
  local body; body=$(cat)
  if grep -qi '^content-type: text/event-stream' /tmp/mcp-headers.$$; then
    echo "(answered as an event stream: id:, event: and data: lines. The JSON is on the data: line)"
    body=$(sed -n 's/^data://p' <<<"$body")
  fi
  if command -v jq >/dev/null; then jq . <<<"$body"; else echo "$body"; fi
}
step() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
show() { printf '\033[2m--> %s\033[0m\n' "$1"; }

post() { # body, [session]
  curl -s -D /tmp/mcp-headers.$$ "$URL" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    ${2:+-H "Mcp-Session-Id: $2"} -d "$1"
}

step "1. initialize: the client says hello, the server says what it can do"
body='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}}}'
show "$body"
post "$body" | pretty
session=$(grep -i '^mcp-session-id:' /tmp/mcp-headers.$$ | cut -d' ' -f2 | tr -d '\r')
echo "Mcp-Session-Id: $session   <- the server's session; every later request carries it"

step "2. notifications/initialized: the client is ready (a notification has no id and no answer)"
body='{"jsonrpc":"2.0","method":"notifications/initialized"}'
show "$body"
post "$body" "$session" >/dev/null
echo "HTTP $(head -1 /tmp/mcp-headers.$$ | cut -d' ' -f2)"

step "3. tools/list: what can I call? Names, descriptions and input schemas"
body='{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
show "$body"
post "$body" "$session" | pretty

step "4. tools/call: call one tool with arguments"
body='{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"check_stock","arguments":{"sku":"CBL-USBC-1M"}}}'
show "$body"
post "$body" "$session" | pretty

rm -f /tmp/mcp-headers.$$
