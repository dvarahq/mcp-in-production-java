#!/usr/bin/env bash
# Someone with database access tries to cover sales-bot's tracks: every audit record that names
# sales-bot is rewritten to name commerce-agent. Then we wait for DVARA's chain check.
# Run ./incident.sh first. Undo with ./dvara/stop.sh --reset (it deletes all lesson data).
set -euo pipefail
cd "$(dirname "$0")/dvara"

sql() { docker compose exec -T postgres psql -U dvara -d dvara -tAc "$1"; }

# The gateway delivers audit records in batches; wait until the night's records have arrived.
for _ in $(seq 1 24); do
  [[ $(sql "select count(*) from dvara_main.audit_events where payload->>'client_id' = 'sales-bot'") -gt 0 ]] && break
  sleep 5
done

echo "Rewriting the audit records: sales-bot -> commerce-agent"
sql "update dvara_main.audit_events
     set payload = payload || '{\"client_id\":\"commerce-agent\",\"user_id\":\"commerce-agent\"}'
     where payload->>'client_id' = 'sales-bot'" | sed 's/^/  rows changed: /'

echo "Waiting for DVARA's audit chain check (every 15 seconds in this lesson)..."
for _ in $(seq 1 12); do
  found=$(docker compose logs --since 1m dvara-flightdeck 2>&1 \
    | grep -oE 'Audit-chain verification FAILED[^"]*' | tail -1 || true)
  if [[ -n $found ]]; then
    echo "  $found"
    exit 0
  fi
  sleep 5
done
echo "  No report yet. Check: docker compose logs dvara-flightdeck | grep Audit-chain"
