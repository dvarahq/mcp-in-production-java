# Lesson 13 — Limits

A batch job or a buggy agent can fire thousands of tool calls a minute. Your MCP server, and
whatever sits behind it, pays for every one. DVARA puts a rate limit in front.

New in this lesson, on the gateway (`dvara/docker-compose.yml`):

```yaml
DVARA_LLM_GATEWAY_RATE_LIMIT_ENABLED: "true"
DVARA_LLM_GATEWAY_RATE_LIMIT_PER_KEY_REQUESTS_PER_MINUTE: "10"
DVARA_LLM_GATEWAY_RATE_LIMIT_PER_KEY_REQUESTS_BURST: "10"
```

The same limiter covers model calls and tool calls. Each caller has its own bucket: an API key,
or for an OAuth agent its issuer and subject. So `sales-bot` running hot does not use up
`commerce-agent`'s allowance. Ten a minute is low on purpose, so you can hit it by hand.

## Run it

Stop the previous lesson's DVARA first: `../lesson-12-approval/dvara/stop.sh`.

```bash
jbang CommerceServer.java     # terminal 1
jbang AuthServer.java         # terminal 2
./dvara/start.sh              # terminal 3
./flood.sh
```

```text
  sales-bot      call  1: ok
  ...
  sales-bot      call 10: ok
  sales-bot      call 11: refused (429 rate_limit_exceeded)
  sales-bot      call 12: refused (429 rate_limit_exceeded)
  commerce-agent call  1: ok
  sales-bot      call 13: refused (429 rate_limit_exceeded)
  ...
Refused by the rate limit during this run: 5  (gateway_rate_limit_denied_total)
```

The refused calls never reach the server. The bucket refills continuously: at 10 a minute,
`sales-bot` gets one more call every 6 seconds.

## The evidence

A refused call is stopped before DVARA's tool-call and audit records, so it does not appear in
**MCP → Tool Calls**. Count refusals with the gateway metric
`gateway_rate_limit_denied_total{reason="request"}` on `/actuator/prometheus`
(with `DVARA_ACTUATOR_METRICS_API_KEY` as a bearer token), and alert on it.

## Other limits

| Limit | What it does |
|---|---|
| Loop detection (lesson 11) | Above 60 calls a minute in one **session**, refuses the call |
| Monthly call quota | Without a licence, 100,000 governed calls a month; past it, tool calls get `402 mcp_cap_exceeded` until the 1st |
| Workspace, team and account limits | For model traffic, narrower limits per workspace, team or account (DVARA rate-limiting docs) |

Stop DVARA with `./dvara/stop.sh` before the next lesson.
