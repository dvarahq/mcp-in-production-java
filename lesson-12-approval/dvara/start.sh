#!/usr/bin/env bash
# Starts DVARA for lesson 12 and registers the commerce MCP server. MCP clients sign in with OAuth.
# Start CommerceServer.java and AuthServer.java first. Needs Docker with Compose v2, curl, openssl.
set -euo pipefail
cd "$(dirname "$0")"

FLIGHTDECK=http://localhost:8090
GATEWAY=http://localhost:8080
SERVER_ID=3f7cef93-79cc-4648-b060-8b93930d4c93
STATE=.state
mkdir -p "$STATE"

say()  { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

for cmd in docker curl openssl; do command -v "$cmd" >/dev/null || fail "$cmd is not installed."; done
curl -s -o /dev/null -X POST http://localhost:8070/mcp || fail "Start the commerce server first: jbang CommerceServer.java"
curl -sf -o /dev/null http://localhost:9000/oauth2/jwks || fail "Start the authorization server first: jbang AuthServer.java"
if curl -s -o /dev/null http://localhost:8080 && [[ -z $(docker compose ps -q dvara-gateway 2>/dev/null) ]]; then
  fail "Port 8080 is in use. Stop the previous lesson's DVARA first, e.g. ../lesson-11-runaway/dvara/stop.sh"
fi

# 1. Secrets, generated once.
if [[ ! -f .env ]]; then
  say "Generating .env"
  secret() { openssl rand -base64 32 | tr -d '\n'; }
  cat > .env <<EOF
DVARA_LICENSE_KEY=
DVARA_ENROLMENT_SECRET=$(secret)
DVARA_ENCRYPTION_MASTER_PASSWORD=$(secret)
DVARA_ACTUATOR_API_KEY=$(secret)
DVARA_ACTUATOR_METRICS_API_KEY=$(secret)
DVARA_AUDIT_HMAC_SECRET=$(secret)
DVARA_PII_TOKEN_ENCRYPTION_MASTER_PASSWORD=$(secret)
DB_PASSWORD=dvara
DVARA_API_KEY=gw_$(openssl rand -hex 24)
OWNER_EMAIL=owner@course.local
OWNER_PASSWORD=$(openssl rand -hex 12)
EOF
fi
set -a; source .env; set +a

# 2. The stack.
say "Starting PostgreSQL, Flightdeck and the gateway (the first pull takes a few minutes)"
docker compose up -d --quiet-pull
wait_for() {
  for _ in $(seq 1 90); do curl -sf -o /dev/null "$1" && return 0; sleep 3; done
  fail "$2 did not come up. Check: docker compose logs"
}
wait_for "$FLIGHTDECK/actuator/health/liveness" "Flightdeck"
wait_for "$GATEWAY/actuator/health/liveness" "The gateway"

# 3. Sign in to Flightdeck and register the commerce server.
JAR="$STATE/cookies"; rm -f "$JAR"
fd()   { curl -s -b "$JAR" -c "$JAR" "$@"; }
csrf() { grep -oE 'name="csrf-token" content="[^"]+"' | head -1 | cut -d'"' -f4; }

if [[ $(fd -o /dev/null -w '%{http_code}' "$FLIGHTDECK/setup") == 200 ]]; then
  say "Creating the Flightdeck owner ($OWNER_EMAIL)"
  token=$(fd "$FLIGHTDECK/setup" | csrf)
  fd -o /dev/null "$FLIGHTDECK/setup" --data-urlencode "_csrf=$token" \
    --data-urlencode first_name=Course --data-urlencode last_name=Owner \
    --data-urlencode "email=$OWNER_EMAIL" --data-urlencode "password=$OWNER_PASSWORD" \
    --data-urlencode "confirmPassword=$OWNER_PASSWORD"
fi
token=$(fd "$FLIGHTDECK/login" | csrf)
landing=$(fd -o /dev/null -w '%{redirect_url}' "$FLIGHTDECK/login" --data-urlencode "_csrf=$token" \
  --data-urlencode "email=$OWNER_EMAIL" --data-urlencode "password=$OWNER_PASSWORD")
[[ $landing == *"/login"* ]] && fail "Could not sign in to Flightdeck. Run ./stop.sh --reset and start again."

say "Registering the commerce MCP server"
token=$(fd "$FLIGHTDECK/config/import" | csrf)
fd "$FLIGHTDECK/config/import/preview" --data-urlencode "_csrf=$token" --data-urlencode mode=merge \
  --data-urlencode "payload@seed-config.json" > "$STATE/preview.html"
hash=$(grep -oE 'name="contentHash"[^>]*value="[^"]+"|value="[^"]+"[^>]*name="contentHash"' "$STATE/preview.html" \
  | grep -oE 'value="[^"]+"' | head -1 | cut -d'"' -f2)
[[ -n $hash ]] || fail "Flightdeck rejected seed-config.json; open $STATE/preview.html to see why."
token=$(csrf < "$STATE/preview.html")
fd -o /dev/null "$FLIGHTDECK/config/import/apply" --data-urlencode "_csrf=$token" --data-urlencode "contentHash=$hash"
token=$(fd "$FLIGHTDECK/mcp/servers" | csrf)
fd -o /dev/null -X POST -H "X-CSRF-TOKEN: $token" "$FLIGHTDECK/mcp/servers/$SERVER_ID/sync"

# 4. Wait until the gateway lists the commerce tools.
say "Waiting for the gateway to pick up the commerce tools"
token=$(curl -s -u commerce-agent:commerce-agent-secret -d grant_type=client_credentials -d scope=mcp:read \
  http://localhost:9000/oauth2/token | grep -oE '"access_token":"[^"]+"' | cut -d'"' -f4)
for _ in $(seq 1 30); do
  tools=$(curl -s "$GATEWAY/mcp" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | grep -o 'commerce__' | wc -l || true)
  (( tools > 0 )) && break
  sleep 2
done
(( tools > 0 )) || fail "The gateway does not list the commerce tools yet. Run ./start.sh again."

cat <<EOF

$(printf '\033[1;32m✓ Ready.\033[0m') DVARA is in front of the commerce server. MCP clients sign in with OAuth.

  MCP endpoint   $GATEWAY/mcp
  Tokens from    http://localhost:9000   (AuthServer.java)
  Flightdeck     $FLIGHTDECK   sign in as $OWNER_EMAIL / $OWNER_PASSWORD

  Next, from the lesson folder:
    ./refund.sh 49.00  ask for a refund; it waits for a person in Flightdeck
EOF
