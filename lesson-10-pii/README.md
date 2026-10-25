# Lesson 10 — PII in tool arguments and results

Agents pass personal data around without meaning to: a customer pastes a card number into a chat,
a lookup tool returns an email address. DVARA scans every tool call in both directions and applies
the workspace's PII action before the data moves on.

New in this lesson:

- Two tools that carry personal data (test values only):
  - `lookup_customer` **returns** an email, a phone number and a card number.
  - `add_order_note` **receives** free text, and logs exactly what arrived.
- The `course` workspace's PII action is `REDACT` (`dvara/seed-config.json`).

## Run it

Stop the previous lesson's DVARA first: `../lesson-09-audit/dvara/stop.sh`.

```bash
jbang CommerceServer.java | tee server.log   # terminal 1
jbang AuthServer.java                        # terminal 2
./dvara/start.sh                             # terminal 3
./try.sh
```

```text
1. lookup_customer C-42. The server returns email, phone and card. The agent receives:
   {"customerId":"C-42","name":"Jane Doe","email":"[REDACTED_EMAIL]","phone":"[REDACTED_PHONE_NUMBER]","cardOnFile":"[REDACTED_CREDIT_CARD]","plan":"Enterprise"}

2. add_order_note. The agent sends:
   Leave at the back door. Charge card 4111 1111 1111 1111, receipt to jane.doe@example.com
   The server receives (its log):
   received: "Leave at the back door. Charge card [REDACTED_CREDIT_CARD], receipt to [REDACTED_EMAIL]"
```

The card number never reaches the tool, and the customer's details never reach the agent.

## The evidence

In Flightdeck (http://localhost:8090) → **Governance → Audit**:

| Event | What it records |
|---|---|
| `MCP_PII_REDACTED` | PII in a tool's **arguments**, removed: `add_order_note`, `CREDIT_CARD, EMAIL`, count 2 |
| `MCP_PII_OUTPUT_LEAK` | PII in a tool's **result**, with the action taken: `lookup_customer`, `REDACT`, count 3 |

The records hold entity types and counts, never the values. **MCP → Tool Calls** marks each call
in the **PII** column.

## Choose the action

Set it per workspace in Flightdeck under **PII & Data Protection**.

| Action | Arguments | Result |
|---|---|---|
| `LOG` (default) | Record it, pass the value on | Record it, return the value |
| `BLOCK` | Refuse the call | Refuse the result |
| `REDACT` | Replace with `[REDACTED_TYPE]` | Replace with `[REDACTED_TYPE]` |
| `TOKENIZE` | Replace with a token you can reverse later | Replace with `[REDACTED_TYPE]` |

Start with `LOG` to learn what your traffic carries, then tighten.

## What this does not cover

Run the agent with a card number in the question:

```bash
set -a; source dvara/.env; set +a; export MCP_URL=http://localhost:8080
jbang CommerceAgent.java "Customer C-42 says: please deliver to the back door and charge my card 4111 1111 1111 1111. Add that as a note on quote Q-1a2b3c4d."
```

The tool receives `[REDACTED_CREDIT_CARD]`. But the model's reply can still repeat the full number:
the question went **straight to the model**, and in this course only tool calls pass through DVARA.
To cover that path too, send model traffic through DVARA's LLM gateway, which applies the same
PII actions to prompts and responses.

Stop DVARA with `./dvara/stop.sh` before the next lesson.
