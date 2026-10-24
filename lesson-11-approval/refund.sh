#!/usr/bin/env bash
# Asks for a refund through DVARA. The call waits until a person approves or denies it.
#   ./refund.sh 49.00            refund for quote Q-1a2b3c4d
#   ./refund.sh 24500.00 Q-5425b0d2
set -euo pipefail
cd "$(dirname "$0")"
amount=${1:-49.00}
quote=${2:-Q-1a2b3c4d}

token=$(curl -s -u commerce-agent:commerce-agent-secret -d grant_type=client_credentials \
  -d 'scope=mcp:read mcp:call' http://localhost:9000/oauth2/token | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4)

echo "Asking for a refund of $amount on $quote."
echo "It is waiting for you: http://localhost:8090 -> Governance -> Approvals (2 minutes, then denied)"
start=$(date +%s)
r=$(curl -s -m 200 http://localhost:8080/mcp -H "Authorization: Bearer $token" -H "X-Session-Id: refund-$(openssl rand -hex 3)" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"commerce__issue_refund\",\"arguments\":{\"quoteId\":\"$quote\",\"amount\":$amount}}}")
waited=$(( $(date +%s) - start ))
if [[ $r == *'"error":{'* ]]; then
  echo "Refused after ${waited}s ($(grep -oE '"dvara_code":"[^"]+"' <<<"$r" | cut -d'"' -f4)): $(grep -oE '"message":"[^"]+"' <<<"$r" | cut -d'"' -f4)"
else
  echo "Done after ${waited}s: $(grep -oE '"text":"[^"]+"' <<<"$r" | cut -d'"' -f4)"
fi
