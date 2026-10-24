# Lesson 5 — Test and debug MCP

Start the server:

```bash
jbang CommerceServer.java
```

## 1. Look: MCP Inspector

```bash
npx @modelcontextprotocol/inspector
```

Streamable HTTP, `http://localhost:8070/mcp`. Call each tool by hand.

## 2. Check: smoke test

```bash
jbang SmokeTest.java
```

It connects like an agent, lists the tools, calls each one and checks the answers. Exit code 1 on any failure.

## 3. Automate: CI

`.github/workflows/smoke-test.yml` starts the server and runs the smoke test on every push.

## Usual failures

| You see | Cause | Fix |
|---|---|---|
| `required property 'arg0' not found` | Compiled without parameter names | Add `//JAVAC_OPTIONS -parameters` |
| `Port 8070 was already in use` | Server already running | Stop it, or pass `--server.port=8071` |
| Agent answers without calling tools | Small model, or vague tool description | Sharpen the `description`; try a bigger model |
| Tool call crashes the agent | Exception leaks out | Throw a clear message; MCP returns it as a tool error |
