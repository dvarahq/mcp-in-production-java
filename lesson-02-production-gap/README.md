# Lesson 2 — The production gap

An MCP server that works on your laptop is not ready for production. This lesson runs the
course's full commerce server, every tool from lessons 3–11, with **nothing in front of it**,
and shows what that means.

## Run it

```bash
jbang CommerceServer.java | tee server.log   # terminal 1
./gap.sh                                     # terminal 2
```

```text
1. Who are you? Nobody asks.
   This script sent no credential at all. The server answered: {"sku":"HUB-USBC-7","available":14}
2. Personal data goes straight to the agent (and to the model behind it).
   {"customerId":"C-42",...,"email":"jane.doe@example.com","phone":"+1 415 555 0134","cardOnFile":"4111 1111 1111 1111",...}
3. A stuck agent can loop for ever.
   20 identical check_delivery calls in a row: 20 of 20 reached the server.
4. Money moves on the agent's word alone.
   Refunded 24500.0 for Q-5425b0d2.
5. Nothing stops a flood.
   50 calls in 1s: 50 of 50 answered.
6. Afterwards: who did it?
   REFUND EXECUTED Q-5425b0d2 amount=24500.0 trace=none
   An amount and a quote. No caller, no agent, no session: the server never knew.
```

## Threat-model it

For each row, decide what would go wrong for **your** business, then note the lesson that closes it.

| # | Gap | What could go wrong | Closed in |
|---|---|---|---|
| 1 | No identity: anyone who can reach `/mcp` can call any tool | | Lesson 7 |
| 2 | Personal data flows to the agent and the model untouched | | Lesson 9 |
| 3 | Nothing notices an agent repeating itself | | Lesson 10 |
| 4 | Irreversible tools run on the agent's word | | Lesson 11 |
| 5 | No limit on how fast one caller can go | | Lesson 12 |
| 6 | No record of who called what | | Lesson 8 |
| 7 | Tool descriptions are trusted as written: a poisoned description can steer the model | | DVARA scans every tool description when it syncs a server: `MCP_TOOL_CATALOG_SCANNED` in the lesson 6 audit |

`readOnlyHint` and `destructiveHint` (lesson 1) do not help here: they are hints the server
gives, not rules anyone enforces.

Each gap could be fixed inside the server. In practice you have many servers, in different
languages, from different teams and vendors. The rest of the course closes all of them in one
place, in front of every server: an AI gateway.
