# Lesson 1 — How MCP works

Before any framework, look at what actually crosses the wire. MCP is JSON-RPC 2.0 over a
transport; this course uses **streamable HTTP**: every message is an HTTP `POST` to one endpoint,
`/mcp`.

## Run it

```bash
jbang CommerceServer.java     # terminal 1: the server you build in lesson 3
./exchange.sh                 # terminal 2
```

`exchange.sh` plays the client with `curl`. It sends four messages and prints each answer
(it uses `jq` to pretty-print if you have it).

| Step | Message | What to notice |
|---|---|---|
| 1 | `initialize` | The client names its protocol version. The server answers with its **capabilities** (tools, resources, prompts) and an `Mcp-Session-Id` header. |
| 2 | `notifications/initialized` | A notification: no `id`, so no answer, just HTTP `202`. |
| 3 | `tools/list` | Each tool's **name**, **description** and **input schema**. The model chooses tools from this text alone. |
| 4 | `tools/call` | A name and arguments in, a `content` list out. `isError` says whether the tool failed. |

## Things to look at

- **The session.** Every request after `initialize` carries `Mcp-Session-Id`. Restart the
  server and the old ID is unknown.
- **Two answer formats.** Step 1 comes back as plain JSON; steps 3 and 4 as an **event stream**
  (`id:`, `event:`, `data:` lines). Streamable HTTP allows either; clients must handle both.
- **Annotations.** `readOnlyHint` and `destructiveHint` are hints from the server. Nothing
  enforces them — keep that in mind for lesson 2.
- **The result is text.** `check_stock` returns JSON *inside* a text item. The model reads it
  as text.

Try another call: edit step 4 to call `create_quote` with `{"sku":"HUB-USBC-7","quantity":2}`,
or an unknown SKU, and see how an error comes back.
