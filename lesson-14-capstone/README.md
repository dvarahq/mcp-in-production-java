# Lesson 14 — Production checklist and capstone

Everything from lessons 7–13, switched on together, and a checklist that proves it.

## Run it

Stop the previous lesson's DVARA first: `../lesson-13-limits/dvara/stop.sh`.

```bash
jbang CommerceServer.java     # terminal 1
jbang AuthServer.java         # terminal 2
./dvara/start.sh              # terminal 3
./checklist.sh
```

```text
Gateway and identity
  PASS  Tools are reached through DVARA, named by server             (lesson 7)
  PASS  A call with no credential is refused                         (lesson 8)
  PASS  The shared workspace key is refused on /mcp                  (lesson 8)
  PASS  A client DVARA does not allow is refused                     (lesson 8)
  PASS  A read-only token cannot call tools                          (lesson 8)
Data
  PASS  Personal data in a tool result is redacted                   (lesson 10)
Agents
  PASS  An agent stuck in a loop is stopped                          (lesson 11)
  PASS  Refunds wait for a person (approval required)                (lesson 12)
  PASS  One agent cannot flood the gateway (rate limit)              (lesson 13)
  PASS  Other agents keep working meanwhile                          (lesson 13)
Evidence (records can take a minute to arrive)
  PASS  Every tool call is audited with the agent's identity         (lesson 9)
  PASS  The audit chain has never failed verification                (lesson 9)

All checks passed.
```

`checklist.sh` exits `1` if any check fails, so it can run in CI against a staging gateway.
Each run uses most of two agents' rate limit, so wait a minute before running it again.

## What is switched on

| Control | Where | Lesson |
|---|---|---|
| Agents reach tools only through the gateway | `MCP_URL`, `dvara/seed-config.json` | 6 |
| OAuth 2.1, allowed clients, scopes, no shared keys | `DVARA_MCPGATEWAY_OAUTH_*` | 7 |
| Signed, chained audit of every call | on by default | 8 |
| PII redacted in arguments and results | `pii.action: REDACT` | 9 |
| Session IDs and loop detection | `X-Session-Id`, on by default | 10 |
| Human approval for refunds | `approval.required-tools` | 11 |
| Per-agent rate limit | `DVARA_LLM_GATEWAY_RATE_LIMIT_*` | 12 |

## Capstone

Put your own MCP server behind this gateway:

1. Start it on your machine (any language, streamable HTTP).
2. In Flightdeck, **MCP → Servers**: add it with URL `http://host.docker.internal:<port>` and
   select **Sync Tools**.
3. Point your agent at `http://localhost:8080/mcp` with a token from `AuthServer.java`.
4. Decide which of its tools need approval, and whether `REDACT` or `BLOCK` suits its data.
5. Change `checklist.sh` to call your tools, and make it pass.

## Before production

The lab proves the controls work. Production also needs what a laptop cannot show:

- **HTTPS** for the gateway, Flightdeck and the OAuth issuer. Plain `http` is allowed only for `localhost`.
- **Your identity provider** (Okta, Entra ID, Keycloak…) instead of `AuthServer.java`, with one client per agent.
- **Secrets** generated and stored outside the repo: the `.env` values, above all `DVARA_AUDIT_HMAC_SECRET`.
- **Database access** limited to the people who must have it. The chain detects tampering; it does not prevent it.
- **Audit export** to your SIEM, and an alert on audit-chain failures (lesson 9) and rate-limit refusals (lesson 13).
- **Model traffic** through DVARA's LLM gateway too, so prompts get the same PII rules as tool calls (lesson 10).
- **A licence** for production use. Without one, DVARA runs for non-production use only, up to 3 workspaces
  and 100,000 calls a month.

For a fuller list, see the [MCP security checklist](https://dvarahq.com/mcp-security-checklist).
