# Lesson 8 — Audit every tool call

Something went wrong overnight. Find which agent did it, prove it, and see what happens
when someone tries to rewrite the record.

New in this lesson:

- `sales-bot`, a fourth agent in `AuthServer.java`, allowed by DVARA.
- The server logs each quote with the **trace ID** DVARA sends (the W3C `traceparent` header).
  DVARA's audit record of the same call carries the same ID. That is how you join the two.
- DVARA re-checks its audit chain every 15 seconds instead of every hour.

## Run it

Stop the previous lesson's DVARA first: `../lesson-07-oauth/dvara/stop.sh`.

```bash
jbang CommerceServer.java | tee server.log   # terminal 1
jbang AuthServer.java                        # terminal 2
./dvara/start.sh                             # terminal 3
./incident.sh
```

```text
Monday, 9:00. A customer writes in:
  "We received quote Q-5425b0d2 for 500 USB-C hubs, $24,500. Nobody here asked for it."
```

## Investigate

**1. Find the call in the server's log.**

```bash
grep Q-5425b0d2 server.log
```

```text
quote Q-5425b0d2 sku=HUB-USBC-7 quantity=500 total=24500.00 trace=739472f75dbd3b0395f32695675469f0
```

The server knows what it did, but not who asked. That is in DVARA's record.

**2. Find the same trace in DVARA.** Open http://localhost:8090 (sign-in from `start.sh`) →
**Governance → Audit**. Set **Event type** to `MCP_TOOL_INTENT`. Click the rows until the
`trace_id` matches. Records can take up to a minute to appear.

```text
client_id:   sales-bot
auth_method: oauth
auth_issuer: http://localhost:9000
tool_name:   create_quote
```

**3. What else did it do?** Read the other `MCP_TOOL_INTENT` rows: `sales-bot` made five quotes
for 500 hubs in a row. `MCP_CLIENT_REFUSED` shows a fourth caller, `unknown-agent`, that tried
three times and never reached the server.

DVARA never stores the tool arguments or the token, only a hash of the arguments (`args_hash`).
The quantity and price come from the server's own log; the identity comes from DVARA.

## Try to cover it up

```bash
./tamper.sh
```

It edits the database directly and rewrites every record that names `sales-bot` to say
`commerce-agent`. Within seconds DVARA reports it:

```text
Audit-chain verification FAILED ... HMAC mismatch at chain position 11: event 0S12FWGRQ0JPB
```

Each record is signed and carries the previous record's signature, so changing, removing or
reordering one breaks the chain at that point. The chain **detects** changes; it does not stop
them. Protect database access and the signing secret (`DVARA_AUDIT_HMAC_SECRET`) separately.

The chain stays broken. Start over with `./dvara/stop.sh --reset`.
