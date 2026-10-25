#!/usr/bin/env bash
# sales-bot fires 15 calls as fast as it can; commerce-agent makes one call in the middle of it.
# Each agent may make 10 calls a minute (dvara/docker-compose.yml). Run ./dvara/start.sh first.
set -euo pipefail
cd "$(dirname "$0")"
source dvara/.env

token() { # client-id
  curl -s -u "$1:$1-secret" -d grant_type=client_credentials -d 'scope=mcp:read mcp:call' \
    http://localhost:9000/oauth2/token | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4
}
call() { # token
  local r
  r=$(curl -s http://localhost:8080/mcp -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"commerce__check_stock","arguments":{"sku":"HUB-USBC-7"}}}')
  if [[ $r == *'"error":{'* ]]; then
    echo "refused ($(grep -oE '"http_status":[0-9]+' <<<"$r" | cut -d: -f2) $(grep -oE '"dvara_code":"[^"]+"' <<<"$r" | cut -d'"' -f4))"
  else
    echo "ok"
  fi
}
denied() {
  curl -s http://localhost:8080/actuator/prometheus -H "Authorization: Bearer $DVARA_ACTUATOR_METRICS_API_KEY" \
    | { grep -E '^gateway_rate_limit_denied_total\{reason="request"\}' || true; } | awk '{print int($2)}'
}

sales=$(token sales-bot)
support=$(token commerce-agent)
before=$(denied); before=${before:-0}

for i in $(seq 1 15); do
  printf '  sales-bot      call %2d: %s\n' "$i" "$(call "$sales")"
  [[ $i == 12 ]] && printf '  commerce-agent call  1: %s\n' "$(call "$support")"
done

after=$(denied); after=${after:-0}
echo
echo "Refused by the rate limit during this run: $((after - before))  (gateway_rate_limit_denied_total)"
echo "The bucket refills at 10 a minute: one more sales-bot call is allowed every 6 seconds."
