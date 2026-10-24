# Lesson 4 — Build the agent

The agent asks a model one question and lets it call the MCP tools from lesson 3.

Terminal 1:

```bash
jbang CommerceServer.java
```

Terminal 2:

```bash
jbang CommerceAgent.java "Quote me 2 of the 7-port USB-C hub"
```

## Use a different model

Defaults: local Ollama, `qwen3:8b`, no key. Any OpenAI-compatible endpoint works:

```bash
export MODEL_BASE_URL=https://api.openai.com/v1
export MODEL_API_KEY=<your key>
export MODEL=<a tool-capable model>
```

`MCP_URL` changes the MCP server address (default `http://localhost:8090`).

## What to notice

- The agent has no commerce code. Everything it knows comes from the tools.
- The model talks to the MCP server directly. Nobody records who called what — lesson 6 fixes that.
