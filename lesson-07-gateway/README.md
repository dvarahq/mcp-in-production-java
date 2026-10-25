# Lesson 7 — Put a gateway in front

Same server, same agent. The agent now talks to DVARA, an AI gateway, which checks
and records every tool call before passing it to the commerce server.

```text
Lesson 5:  agent ──────────────────────────► commerce server
Lesson 7:  agent ──► DVARA (key, record) ──► commerce server
```

You also need Docker with Compose v2. No licence key: DVARA runs every feature for
non-production use, up to 3 workspaces and 100,000 calls a month.

## Run it

Terminal 1, the server:

```bash
jbang CommerceServer.java
```

Terminal 2, DVARA (the first run downloads the images):

```bash
./dvara/start.sh
```

It prints your API key and the Flightdeck sign-in. Then run the agent through DVARA:

```bash
set -a; source dvara/.env; set +a
export MCP_URL=http://localhost:8080
jbang CommerceAgent.java "Quote me 2 of the 7-port USB-C hub"
```

## See the record

Open http://localhost:8090, sign in with the details from `start.sh`, go to **MCP → Tool Calls**.
Every call is there: workspace, server, tool, decision, status, latency.

Try a wrong key — DVARA refuses it with `401` and the server is never called:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/mcp \
  -H "Authorization: Bearer gw_wrong" -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## What changed in the code

- `MCP_URL` now points at DVARA (`http://localhost:8080`) instead of the server.
- One new bean, `dvaraKey()`, sends the workspace key on every MCP request.
- Tool names arrive as `commerce__search_products`: DVARA prefixes each tool with its server,
  so tools from many servers can share one endpoint.

Stop DVARA with `./dvara/stop.sh` before the next lesson (`--reset` also deletes its data and `.env`).
