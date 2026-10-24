///usr/bin/env jbang "$0" "$@" ; exit $?
//JAVA 21+
//DEPS io.modelcontextprotocol.sdk:mcp:2.0.0
//DEPS org.slf4j:slf4j-nop:2.0.17

import java.util.List;
import java.util.Map;

import io.modelcontextprotocol.client.McpClient;
import io.modelcontextprotocol.client.McpSyncClient;
import io.modelcontextprotocol.client.transport.HttpClientStreamableHttpTransport;
import io.modelcontextprotocol.spec.McpSchema.CallToolRequest;
import io.modelcontextprotocol.spec.McpSchema.CallToolResult;
import io.modelcontextprotocol.spec.McpSchema.TextContent;
import io.modelcontextprotocol.spec.McpSchema.Tool;

// Talks to the running commerce server the way an agent would. Exits 1 if any check fails.
public class SmokeTest {

    static int failures = 0;

    public static void main(String[] args) {
        var url = args.length > 0 ? args[0] : "http://localhost:8070";
        var transport = HttpClientStreamableHttpTransport.builder(url).build();

        try (var client = McpClient.sync(transport).build()) {
            client.initialize();

            List<String> names = client.listTools().tools().stream().map(Tool::name).toList();
            check("server lists the three tools",
                    names.containsAll(List.of("search_products", "check_stock", "create_quote")));

            var found = call(client, "search_products", Map.of("query", "usb-c cable"));
            check("search finds the 1 m cable", !found.isError() && text(found).contains("CBL-USBC-1M"));

            var stock = call(client, "check_stock", Map.of("sku", "CBL-USBC-2M"));
            check("out-of-stock item reports 0", !stock.isError() && text(stock).contains("\"available\":0"));

            var quote = call(client, "create_quote", Map.of("sku", "HUB-USBC-7", "quantity", 2));
            check("quote is a DRAFT for 98.00", !quote.isError()
                    && text(quote).contains("DRAFT") && text(quote).contains("98"));

            var unknown = call(client, "check_stock", Map.of("sku", "NOPE"));
            check("unknown SKU returns a tool error", unknown.isError() && text(unknown).contains("Unknown SKU"));
        }

        System.out.println(failures == 0 ? "ALL CHECKS PASSED" : failures + " CHECK(S) FAILED");
        System.exit(failures == 0 ? 0 : 1);
    }

    static CallToolResult call(McpSyncClient client, String tool, Map<String, Object> args) {
        return client.callTool(CallToolRequest.builder(tool).arguments(args).build());
    }

    static String text(CallToolResult result) {
        return result.content().stream()
                .filter(TextContent.class::isInstance)
                .map(c -> ((TextContent) c).text())
                .reduce("", String::concat);
    }

    static void check(String name, boolean ok) {
        System.out.println((ok ? "PASS  " : "FAIL  ") + name);
        if (!ok) failures++;
    }
}
