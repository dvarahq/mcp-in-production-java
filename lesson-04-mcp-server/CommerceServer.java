///usr/bin/env jbang "$0" "$@" ; exit $?
//JAVA 25+
//JAVAC_OPTIONS -parameters
//DEPS org.springframework.boot:spring-boot-dependencies:4.1.1@pom
//DEPS org.springframework.ai:spring-ai-bom:2.0.1@pom
//DEPS org.springframework.ai:spring-ai-starter-mcp-server-webmvc

package commerce;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.ai.mcp.annotation.McpTool;
import org.springframework.ai.mcp.annotation.McpTool.McpAnnotations;
import org.springframework.ai.mcp.annotation.McpToolParam;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.stereotype.Component;

// A small commerce MCP server: three tools over streamable HTTP at http://localhost:8070/mcp
@SpringBootApplication
public class CommerceServer {

    public static void main(String[] args) {
        var app = new SpringApplication(CommerceServer.class);
        app.setDefaultProperties(Map.of(
                "server.port", "8070",
                "spring.ai.mcp.server.name", "commerce",
                "spring.ai.mcp.server.version", "1.0.0",
                "spring.ai.mcp.server.protocol", "STREAMABLE"));
        app.run(args);
    }

    record Product(String sku, String name, BigDecimal unitPrice) {}

    record Stock(String sku, int available) {}

    record Quote(String quoteId, String sku, int quantity, BigDecimal total, String status) {}

    @Component
    static class CommerceTools {

        private static final Map<String, Product> CATALOG = Map.of(
                "CBL-USBC-1M", new Product("CBL-USBC-1M", "USB-C cable, 1 m", new BigDecimal("9.99")),
                "CBL-USBC-2M", new Product("CBL-USBC-2M", "USB-C cable, 2 m", new BigDecimal("12.99")),
                "HUB-USBC-7", new Product("HUB-USBC-7", "7-port USB-C hub", new BigDecimal("49.00")));

        private static final Map<String, Integer> STOCK = Map.of(
                "CBL-USBC-1M", 120,
                "CBL-USBC-2M", 0,
                "HUB-USBC-7", 14);

        @McpTool(name = "search_products",
                description = "Find products whose name contains the given words. Returns SKU, name and unit price.",
                annotations = @McpAnnotations(readOnlyHint = true, destructiveHint = false))
        List<Product> searchProducts(@McpToolParam(description = "Words to look for, e.g. 'usb-c cable'") String query) {
            // Ignore case and spaces, so "2m" matches "2 m".
            var words = List.of(query.toLowerCase().split("\\s+"));
            return CATALOG.values().stream()
                    .filter(p -> words.stream().allMatch(w -> p.name().toLowerCase().replace(" ", "").contains(w)))
                    .toList();
        }

        @McpTool(name = "check_stock",
                description = "Units in stock for one SKU.",
                annotations = @McpAnnotations(readOnlyHint = true, destructiveHint = false))
        Stock checkStock(@McpToolParam(description = "Product SKU, e.g. CBL-USBC-1M") String sku) {
            return new Stock(product(sku).sku(), STOCK.get(sku));
        }

        @McpTool(name = "create_quote",
                description = "Create a DRAFT price quote. A quote is not an order and does not reserve stock.",
                annotations = @McpAnnotations(destructiveHint = false))
        Quote createQuote(@McpToolParam(description = "Product SKU") String sku,
                          @McpToolParam(description = "Number of units, 1 or more") int quantity) {
            if (quantity < 1) {
                throw new IllegalArgumentException("quantity must be 1 or more");
            }
            var total = product(sku).unitPrice().multiply(BigDecimal.valueOf(quantity));
            return new Quote("Q-" + UUID.randomUUID().toString().substring(0, 8), sku, quantity, total, "DRAFT");
        }

        private static Product product(String sku) {
            var product = CATALOG.get(sku);
            if (product == null) {
                // Spring AI sends the message, then its cause's message: what went wrong, then what to do.
                throw new IllegalArgumentException("Unknown SKU: " + sku + ".",
                        new IllegalArgumentException("Use search_products to find a valid SKU."));
            }
            return product;
        }
    }
}
