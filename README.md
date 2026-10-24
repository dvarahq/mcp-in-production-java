# MCP in Production — Java

Code for the free **MCP in Production** course by the DVARA Team.
Every server and agent is a single Java file run with [JBang](https://www.jbang.dev/). No build files.

## You need

- Java 21+
- JBang: `curl -Ls https://sh.jbang.dev | bash -s - app setup`
- A model. Default is free and local: [Ollama](https://ollama.com) with `ollama pull qwen3:8b`.
  Any OpenAI-compatible model works — see lesson 4.
- From lesson 6: Docker with Compose v2.

## Lessons

| Lesson | Folder | Run |
|---|---|---|
| 3. Build an MCP server | `lesson-03-mcp-server` | `jbang CommerceServer.java` |
| 4. Build the agent | `lesson-04-agent` | `jbang CommerceAgent.java "Quote me 3 USB-C cables"` |
| 5. Test and debug MCP | `lesson-05-testing` | `jbang SmokeTest.java` |
| 6. Put a gateway in front | `lesson-06-gateway` | `./dvara/start.sh`, then the agent |
| 7. Authenticate MCP clients | `lesson-07-oauth` | `./dvara/start.sh`, then `./try.sh` |
| 8. Audit every tool call | `lesson-08-audit` | `./dvara/start.sh`, then `./incident.sh` |
| 9. PII in tool arguments and results | `lesson-09-pii` | `./dvara/start.sh`, then `./try.sh` |
| 10. Stop runaway agents | `lesson-10-runaway` | `./dvara/start.sh`, then `./runaway.sh` |

Each folder is complete. Start any lesson from its own folder.
