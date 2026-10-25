///usr/bin/env jbang "$0" "$@" ; exit $?
//JAVA 25+
//JAVAC_OPTIONS -parameters
//DEPS org.springframework.boot:spring-boot-dependencies:4.1.1@pom
//DEPS org.springframework.boot:spring-boot-starter-security-oauth2-authorization-server

package auth;

import java.util.List;
import java.util.Map;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.core.ClientAuthenticationMethod;
import org.springframework.security.oauth2.server.authorization.client.InMemoryRegisteredClientRepository;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClient;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClientRepository;
import org.springframework.security.oauth2.server.authorization.token.JwtEncodingContext;
import org.springframework.security.oauth2.server.authorization.token.OAuth2TokenCustomizer;

// A tiny OAuth 2.1 authorization server for the course, at http://localhost:9000.
// Stands in for your company's identity provider (Okta, Entra ID, Keycloak...).
@SpringBootApplication
public class AuthServer {

    // The MCP endpoint the tokens are for. DVARA refuses a token whose audience is anything else.
    static final String MCP_RESOURCE = "http://localhost:8080/mcp";

    public static void main(String[] args) {
        var app = new SpringApplication(AuthServer.class);
        app.setDefaultProperties(Map.of(
                "server.port", "9000",
                "spring.security.oauth2.authorizationserver.issuer", "http://localhost:9000"));
        app.run(args);
    }

    // Three agents. Each one's secret is "<id>-secret".
    @Bean
    RegisteredClientRepository clients() {
        return new InMemoryRegisteredClientRepository(
                client("commerce-agent", "mcp:read", "mcp:call"),   // may list and call tools
                client("reporting-agent", "mcp:read"),              // may only list tools
                client("unknown-agent", "mcp:read", "mcp:call"));   // valid token, but DVARA does not allow it
    }

    // Put the MCP endpoint in "aud" and the agent's id in "client_id".
    @Bean
    OAuth2TokenCustomizer<JwtEncodingContext> mcpClaims() {
        return context -> context.getClaims()
                .audience(List.of(MCP_RESOURCE))
                .claim("client_id", context.getRegisteredClient().getClientId());
    }

    static RegisteredClient client(String id, String... scopes) {
        return RegisteredClient.withId(id)
                .clientId(id)
                .clientSecret("{noop}" + id + "-secret")
                .clientAuthenticationMethod(ClientAuthenticationMethod.CLIENT_SECRET_BASIC)
                .authorizationGrantType(AuthorizationGrantType.CLIENT_CREDENTIALS)
                .scopes(s -> s.addAll(List.of(scopes)))
                .build();
    }
}
