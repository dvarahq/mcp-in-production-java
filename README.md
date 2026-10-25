# MCP in Production — Java

Code for the free **MCP in Production** course by the DVARA Team.
Every server and agent is a single Java file run with [JBang](https://www.jbang.dev/). No build files.

## You need

- Java 25+
- JBang: `curl -Ls https://sh.jbang.dev | bash -s - app setup`
- A model. Default is free and local: [Ollama](https://ollama.com) with `ollama pull qwen3:8b`.
  Any OpenAI-compatible model works — see lesson 5.
- From lesson 7: Docker with Compose v2. Lessons 7–14 run DVARA 1.12.0 with no licence key.

## Lessons

| Lesson | Folder | Run |
|---|---|---|
| 1. Why AI agents break in production | (video only) | — |
| 2. How MCP works | `lesson-02-how-mcp-works` | `jbang CommerceServer.java`, then `./exchange.sh` |
| 3. The production gap | `lesson-03-production-gap` | `jbang CommerceServer.java \| tee server.log`, then `./gap.sh` |
| 4. Build an MCP server | `lesson-04-mcp-server` | `jbang CommerceServer.java` |
| 5. Build the agent | `lesson-05-agent` | `jbang CommerceAgent.java "Quote me 3 USB-C cables"` |
| 6. Test and debug MCP | `lesson-06-testing` | `jbang SmokeTest.java` |
| 7. Put a gateway in front | `lesson-07-gateway` | `./dvara/start.sh`, then the agent |
| 8. Authenticate MCP clients | `lesson-08-oauth` | `./dvara/start.sh`, then `./try.sh` |
| 9. Audit every tool call | `lesson-09-audit` | `./dvara/start.sh`, then `./incident.sh` |
| 10. PII in tool arguments and results | `lesson-10-pii` | `./dvara/start.sh`, then `./try.sh` |
| 11. Stop runaway agents | `lesson-11-runaway` | `./dvara/start.sh`, then `./runaway.sh` |
| 12. Humans in the loop | `lesson-12-approval` | `./dvara/start.sh`, then `./refund.sh 49.00` |
| 13. Limits | `lesson-13-limits` | `./dvara/start.sh`, then `./flood.sh` |
| 14. Production checklist and capstone | `lesson-14-capstone` | `./dvara/start.sh`, then `./checklist.sh` |

Each folder is complete. Start any lesson from its own folder.
