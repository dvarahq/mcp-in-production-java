# Lesson 10 — Stop runaway agents

An agent that polls a tool that never finishes will call it forever, burning model tokens and
hammering your server. DVARA watches each session's tool calls and refuses the loop.

New in this lesson:

- `check_delivery`, a tool that always answers "still being booked, call again".
- The agent sends an `X-Session-Id` header on every MCP call, one ID per run
  (`SESSION_ID` overrides it). Without a session ID, DVARA cannot join calls into a session
  or see a loop across them.

## Run it

Stop the previous lesson's DVARA first: `../lesson-09-pii/dvara/stop.sh`.

```bash
jbang CommerceServer.java     # terminal 1
jbang AuthServer.java         # terminal 2
./dvara/start.sh              # terminal 3
./runaway.sh
```

`runaway.sh` plays a stuck agent: seven identical calls in one session.

```text
session runaway-f2fefd
  call 1: reached the server: still being booked
  call 2: reached the server: still being booked
  call 3: reached the server: still being booked
  call 4: reached the server: still being booked
  call 5: refused (AGENT_LOOP_DETECTED): Tool 'commerce::check_delivery' called 5 times consecutively
  call 6: refused (AGENT_LOOP_DETECTED): Tool 'commerce::check_delivery' called 5 times consecutively
  call 7: refused (AGENT_LOOP_DETECTED): Tool 'commerce::check_delivery' called 5 times consecutively
```

The fifth call never reaches the server. The agent gets the refusal back as an error instead of
another "call again".

DVARA's default loop checks:

| Check | Default |
|---|---|
| Same tool called again and again | Refuse the 5th call in a row |
| A repeating cycle of 2–4 calls | Refuse after 3 repetitions |
| Call rate | Refuse above 60 calls a minute in one session |

## Kill the session

Refusing the loop does not end the session: the agent can still call other tools in it.
To stop the whole run, open http://localhost:8090 → **MCP → Sessions**, find the session and
choose **Kill session**. A new session can take a minute to appear; **Kill a session by id** at
the top of the page works right away (workspace `course`).

```bash
./runaway.sh runaway-f2fefd
```

```text
session runaway-f2fefd: refused (SESSION_KILLED): Agent session has been killed: runaway-f2fefd
```

Every tool is refused for that session now, on every gateway, within seconds.
A kill stops a **session**, not an agent: a new session ID works. To stop an agent, remove it
from DVARA's allowed clients or disable it at the authorization server (lesson 7).

## The evidence

**Governance → Audit**:

| Event | What it records |
|---|---|
| `AGENT_LOOP_DETECTED` | Loop type, tool, server, session |
| `AGENT_SESSION_KILLED` | Who killed which session, `scope: all_planes` |
| `SESSION_KILL_ENFORCED` | The first refusal of the killed session on a gateway |

## Try the real agent

```bash
set -a; source dvara/.env; set +a; export MCP_URL=http://localhost:8080
jbang CommerceAgent.java "Has delivery been booked for quote Q-1a2b3c4d? Keep checking until you have a final answer."
```

A small local model usually gives up after a few calls. A more persistent agent hits the limit
on the fifth.

Stop DVARA with `./dvara/stop.sh` before the next lesson.
