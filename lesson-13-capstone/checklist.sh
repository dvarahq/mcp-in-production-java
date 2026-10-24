#!/usr/bin/env bash
# Production checklist: checks every control from lessons 6-12 against the running stack.
# Run ./dvara/start.sh first. Exit code 1 if any check fails.
# Each run uses up most of two agents' rate limit: wait a minute between runs.
set -uo pipefail
cd "$(dirname "$0")"
source dvara/.env

GATEWAY=http://localhost:8080
failed=0
pass() { printf '  \033[32mPASS\033[0m  %-58s (lesson %s)\n' "$1" "$2"; }
fail() { printf '  \033[31mFAIL\033[0m  %-58s (lesson %s)\n' "$1" "$2"; failed=1; }
check() { if eval "$3"; then pass "$1" "$2"; else fail "$1" "$2"; fi; }

token() { # client-id, scopes
  curl -s -u "$1:$1-secret" -d grant_type=client_credentials -d "scope=$2" http://localhost:9000/oauth2/token \
    | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4
}
rpc() { # credential, method, params-json, [session]
  curl -s "$GATEWAY/mcp" ${1:+-H "Authorization: Bearer $1"} ${4:+-H "X-Session-Id: $4"} \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$2\",\"params\":$3}"
}
status() { # credential
  curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/mcp" ${1:+-H "Authorization: Bearer $1"} \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
}
sql() { (cd dvara && docker compose exec -T postgres psql -U dvara -d dvara -tAc "$1"); }

reader=$(token reporting-agent 'mcp:read')
support=$(token commerce-agent 'mcp:read mcp:call')
bot=$(token sales-bot 'mcp:read mcp:call')
run=$(openssl rand -hex 3)

echo "Gateway and identity"
tools=$(rpc "$reader" tools/list '{}')
check "Tools are reached through DVARA, named by server" 6 "grep -q 'commerce__check_stock' <<<\"\$tools\""
check "A call with no credential is refused" 7 "[[ \$(status '') == 401 ]]"
check "The shared workspace key is refused on /mcp" 7 "[[ \$(status \"\$DVARA_API_KEY\") == 401 ]]"
check "A client DVARA does not allow is refused" 7 "[[ \$(status \"\$(token unknown-agent 'mcp:read mcp:call')\") == 403 ]]"
r=$(rpc "$reader" tools/call '{"name":"commerce__check_stock","arguments":{"sku":"HUB-USBC-7"}}')
check "A read-only token cannot call tools" 7 "grep -q 'MCP_SCOPE_DENIED' <<<\"\$r\""

echo "Data"
r=$(rpc "$support" tools/call '{"name":"commerce__lookup_customer","arguments":{"customerId":"C-42"}}' "checklist-$run")
check "Personal data in a tool result is redacted" 9 "grep -q 'REDACTED_CREDIT_CARD' <<<\"\$r\" && ! grep -q '4111' <<<\"\$r\""

echo "Agents"
for i in 1 2 3 4 5; do
  r=$(rpc "$support" tools/call '{"name":"commerce__check_delivery","arguments":{"quoteId":"Q-1a2b3c4d"}}' "loop-$run")
done
check "An agent stuck in a loop is stopped" 10 "grep -q 'AGENT_LOOP_DETECTED' <<<\"\$r\""
refund=${tools#*'"name":"commerce__issue_refund"'}; refund=${refund%%'"name":"commerce__'*}
check "Refunds wait for a person (approval required)" 11 "grep -q 'approval_required\":true' <<<\"\$refund\""
limited=no
for i in $(seq 1 12); do
  r=$(rpc "$bot" tools/call '{"name":"commerce__check_stock","arguments":{"sku":"HUB-USBC-7"}}' "rate-$run-$i")
  grep -q 'rate_limit_exceeded' <<<"$r" && { limited=yes; break; }
done
check "One agent cannot flood the gateway (rate limit)" 12 "[[ $limited == yes ]]"
r=$(rpc "$support" tools/call '{"name":"commerce__check_stock","arguments":{"sku":"HUB-USBC-7"}}' "checklist-$run")
check "Other agents keep working meanwhile" 12 "grep -q 'available' <<<\"\$r\""

echo "Evidence (records can take a minute to arrive)"
found=0
for _ in $(seq 1 24); do
  found=$(sql "select count(*) from dvara_main.audit_events where event_type='MCP_TOOL_INTENT'
               and payload->>'client_id'='commerce-agent' and payload->>'tool_name'='lookup_customer'
               and payload->>'session_id'='checklist-$run'")
  [[ ${found:-0} -gt 0 ]] && break
  sleep 5
done
check "Every tool call is audited with the agent's identity" 8 "[[ \${found:-0} -gt 0 ]]"
broken=$(cd dvara && docker compose logs dvara-flightdeck 2>&1 | grep -c 'Audit-chain verification FAILED' || true)
check "The audit chain has never failed verification" 8 "[[ \${broken:-0} == 0 ]]"

echo
if [[ $failed == 0 ]]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $failed
