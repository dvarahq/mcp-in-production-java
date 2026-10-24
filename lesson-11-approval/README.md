# Lesson 11 — Humans in the loop

Some tool calls should never run on an agent's word alone: money out, data deleted, an email to
a customer. DVARA can hold such a call until a person approves it.

New in this lesson:

- `issue_refund`, a tool that sends money back. It logs `REFUND EXECUTED` when it really runs.
- The `course` workspace requires approval for it (`dvara/seed-config.json`):

```json
"approval.required-tools": "issue_refund",
"approval.timeout-seconds": "120",
"approval.default-action": "deny"
```

`required-tools` takes globs, such as `refund_*,delete_*`. Keep `default-action` at `deny`: when
nobody answers, or the approval service is down, the call is refused rather than run.

## Run it

Stop the previous lesson's DVARA first: `../lesson-10-runaway/dvara/stop.sh`.

```bash
jbang CommerceServer.java | tee server.log   # terminal 1
jbang AuthServer.java                        # terminal 2
./dvara/start.sh                             # terminal 3
```

**Approve one.**

```bash
./refund.sh 49.00
```

The call waits, and the server log shows nothing. Open http://localhost:8090 →
**Governance → Approvals**. The pending call shows the tool, the session and the rule that
matched. Choose **Approve**:

```text
Done after 10s: Refunded 49.0 for Q-1a2b3c4d.
```

Only now does the server log `REFUND EXECUTED Q-1a2b3c4d amount=49.0`.

**Deny one.**

```bash
./refund.sh 24500.00 Q-5425b0d2
```

Choose **Deny**:

```text
Refused after 7s (MCP_APPROVAL_DENIED): Tool call denied by human reviewer
```

The server never ran it.

**Ignore one.** Run `./refund.sh 10.00` and do nothing. After two minutes the default action
applies and the call is refused.

## What the agent sees

`tools/list` marks every tool that needs approval with `_meta["dvara/approval_required"]: true`,
so a client can tell the user "this will need sign-off" before it calls.

## The evidence

**Governance → Audit**:

| Event | What it records |
|---|---|
| `MCP_APPROVAL_REQUESTED` | The held call: tool, session, agent, matched rule |
| `MCP_APPROVAL_RESOLVED` | Who decided and what: `actor: owner@course.local`, `action: approve` |
| `MCP_APPROVAL_GRANTED` / `MCP_APPROVAL_DENIED` / `MCP_APPROVAL_TIMEOUT` | How the call ended |

## If approvals never appear

If the call is refused at once with "timed out" and nothing shows under **Approvals**, check the
workspace region. A gateway may only act for workspaces in its own region; this lesson's gateway
is in `default`, so the workspace is `region: default` (`dvara/bootstrap.yaml`).

Stop DVARA with `./dvara/stop.sh` before the next lesson.
