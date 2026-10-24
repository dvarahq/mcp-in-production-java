# Lesson 7 — Authenticate MCP clients

In lesson 6 every caller used one shared workspace key, so DVARA could not tell agents apart.
Now each agent signs in with OAuth 2.1 and gets its own token. DVARA checks who issued it,
who it is for, which agent holds it and what it may do — before any tool runs.

`AuthServer.java` is a small authorization server (Spring Authorization Server) standing in
for your company's identity provider. It knows three agents:

| Client | Scopes | What DVARA does |
|---|---|---|
| `commerce-agent` | `mcp:read mcp:call` | Lists and calls tools |
| `reporting-agent` | `mcp:read` | Lists tools; a tool call is refused |
| `unknown-agent` | `mcp:read mcp:call` | Refused: not on DVARA's allowed list |

## Run it

Stop the previous lesson's DVARA first: `../lesson-06-gateway/dvara/stop.sh`.

```bash
jbang CommerceServer.java     # terminal 1
jbang AuthServer.java         # terminal 2
./dvara/start.sh              # terminal 3
```

Four callers, four outcomes:

```bash
./try.sh
```

```text
1. commerce-agent, scopes mcp:read mcp:call
   allowed: {"sku":"HUB-USBC-7","available":14}
2. reporting-agent, scope mcp:read only
   refused (MCP_SCOPE_DENIED): This access token's scopes do not cover tools/call; this operation needs mcp:call.
3. unknown-agent, a valid token from a client DVARA does not allow
   refused (HTTP 403): OAuth client unknown-agent is not one this gateway accepts
4. the workspace API key from lesson 6
   refused (HTTP 401): This gateway accepts OAuth access tokens only
```

Then the agent, signed in as `commerce-agent`:

```bash
jbang CommerceAgent.java "Quote me 2 of the 7-port USB-C hub"
```

In Flightdeck (**MCP → Tool Calls**) each call now names the agent that made it.

## What changed

- **DVARA** (`dvara/docker-compose.yml`, the `DVARA_MCPGATEWAY_OAUTH_*` lines): trust tokens from
  `http://localhost:9000`, only for `http://localhost:8080/mcp`, bind them to the `course` workspace,
  allow two clients, turn workspace keys off for MCP.
- **Agent**: `oauthToken()` replaces `dvaraKey()`. It gets a token with the client-credentials grant
  and sends it on every MCP request.
- **Server**: unchanged.

Stop DVARA with `./dvara/stop.sh` before the next lesson.
