# Lesson 3 — Build an MCP server

One file, three tools: `search_products`, `check_stock`, `create_quote`.

```bash
jbang CommerceServer.java
```

The server listens on `http://localhost:8090/mcp` (streamable HTTP).

Look at it with the MCP Inspector:

```bash
npx @modelcontextprotocol/inspector
```

Choose **Streamable HTTP**, enter `http://localhost:8090/mcp`, connect, open **Tools**.

## What to notice

- `@McpTool` turns a method into a tool. The `description` is what the model reads to decide when to call it.
- `@McpToolParam` describes each argument.
- `readOnlyHint` tells clients a tool changes nothing.
- `//JAVAC_OPTIONS -parameters` keeps argument names. Without it the tool asks for `arg0`.
