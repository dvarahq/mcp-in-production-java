///usr/bin/env jbang "$0" "$@" ; exit $?
//JAVA 21+
//JAVAC_OPTIONS -parameters
//DEPS org.springframework.boot:spring-boot-dependencies:4.1.1@pom
//DEPS org.springframework.ai:spring-ai-bom:2.0.1@pom
//DEPS org.springframework.ai:spring-ai-starter-mcp-client
//DEPS org.springframework.ai:spring-ai-starter-model-openai

package commerce;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

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
                // MCP traffic goes to DVARA, which forwards allowed calls to the commerce server.
                "spring.ai.mcp.client.type", "SYNC",
                "spring.ai.mcp.client.streamable-http.connections.commerce.url", env("MCP_URL", "http://localhost:8080"),
                "spring.ai.mcp.client.streamable-http.connections.commerce.endpoint", "/mcp"));
        app.run(args);
    }

    // Lesson 7: every MCP request carries an OAuth access token.
    // Lesson 10: and one session ID per run, so DVARA can see the calls as one piece of work.
    @Bean
    McpClientCustomizer<HttpClientStreamableHttpTransport.Builder> oauthToken() throws Exception {
        var token = fetchToken();
        var session = env("SESSION_ID", "agent-run-" + UUID.randomUUID().toString().substring(0, 8));
        System.out.println("session " + session);
        return (name, transport) -> transport.httpRequestCustomizer((request, method, endpoint, body, context) -> {
            request.header("Authorization", "Bearer " + token);
            request.header("X-Session-Id", session);
        });
    }

    // OAuth client credentials: the agent signs in as itself and asks for the MCP scopes it needs.
    static String fetchToken() throws Exception {
        var clientId = env("CLIENT_ID", "commerce-agent");
        var secret = env("CLIENT_SECRET", clientId + "-secret");
        var request = HttpRequest.newBuilder(URI.create(env("AUTH_URL", "http://localhost:9000") + "/oauth2/token"))
                .header("Authorization", "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + secret).getBytes()))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString("grant_type=client_credentials&scope=mcp:read%20mcp:call"))
                .build();
        var body = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString()).body();
        var match = Pattern.compile("\"access_token\":\"([^\"]+)\"").matcher(body);
        if (!match.find()) {
            throw new IllegalStateException("No token from the authorization server: " + body);
        }
        return match.group(1);
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
