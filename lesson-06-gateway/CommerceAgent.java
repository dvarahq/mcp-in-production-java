///usr/bin/env jbang "$0" "$@" ; exit $?
//JAVA 25+
//JAVAC_OPTIONS -parameters
//DEPS org.springframework.boot:spring-boot-dependencies:4.1.1@pom
//DEPS org.springframework.ai:spring-ai-bom:2.0.1@pom
//DEPS org.springframework.ai:spring-ai-starter-mcp-client
//DEPS org.springframework.ai:spring-ai-starter-model-openai

package commerce;

import java.util.Map;

import io.modelcontextprotocol.client.transport.HttpClientStreamableHttpTransport;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.mcp.SyncMcpToolCallbackProvider;
import org.springframework.ai.mcp.customizer.McpClientCustomizer;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

// Asks one question, lets the model call the commerce MCP tools, prints the answer.
// Usage: jbang CommerceAgent.java "Do you have a USB-C cable in stock? Quote me 3."
@SpringBootApplication
public class CommerceAgent {

    public static void main(String[] args) {
        var app = new SpringApplication(CommerceAgent.class);
        app.setDefaultProperties(Map.of(
                "spring.main.web-application-type", "none",
                "spring.main.banner-mode", "off",
                "logging.level.root", "ERROR",
                // Any OpenAI-compatible model. Default: a local Ollama model, no key needed.
                "spring.ai.openai.base-url", env("MODEL_BASE_URL", "http://localhost:11434/v1"),
                "spring.ai.openai.api-key", env("MODEL_API_KEY", "ollama"),
                "spring.ai.openai.chat.options.model", env("MODEL", "qwen3:8b"),
                // Lesson 6: MCP traffic goes to DVARA, which forwards allowed calls to the commerce server.
                "spring.ai.mcp.client.type", "SYNC",
                "spring.ai.mcp.client.streamable-http.connections.commerce.url", env("MCP_URL", "http://localhost:8080"),
                "spring.ai.mcp.client.streamable-http.connections.commerce.endpoint", "/mcp"));
        app.run(args);
    }

    // Lesson 6: the only new code. Every MCP request carries the DVARA workspace key.
    @Bean
    McpClientCustomizer<HttpClientStreamableHttpTransport.Builder> dvaraKey() {
        var key = env("DVARA_API_KEY", "");
        return (name, transport) -> transport.httpRequestCustomizer(
                (request, method, endpoint, body, context) -> request.header("Authorization", "Bearer " + key));
    }

    @Bean
    CommandLineRunner ask(ChatClient.Builder builder, SyncMcpToolCallbackProvider tools) {
        return args -> {
            var question = args.length > 0 ? String.join(" ", args)
                    : "Do you have a USB-C cable in stock? Quote me 3.";
            var agent = builder
                    .defaultSystem("""
                        You are a commerce support agent.
                        Use tools for product, stock and price facts. Never invent a value a tool can provide.
                        A quote is a draft, never an order.
                        """)
                    .build();
            System.out.println(agent.prompt().user(question).tools(tools).call().content());
        };
    }

    static String env(String name, String fallback) {
        var value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }
}
