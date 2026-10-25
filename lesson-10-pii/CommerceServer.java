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

import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

import org.springframework.ai.mcp.annotation.McpTool;
import org.springframework.ai.mcp.annotation.McpTool.McpAnnotations;
import org.springframework.ai.mcp.annotation.McpToolParam;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

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

    // Lesson 10: test data only. 4111 1111 1111 1111 is the standard test card number.
    record Customer(String customerId, String name, String email, String phone, String cardOnFile, String plan) {}

    // Lesson 9: DVARA sends a W3C traceparent header on every call. Keep its trace ID for the log,
    // so a line in this server's log can be matched to DVARA's audit record of the same call.
    @Component
    static class TraceIdFilter extends OncePerRequestFilter {
        @Override
        protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
                throws java.io.IOException, jakarta.servlet.ServletException {
            var traceparent = request.getHeader("traceparent");   // 00-<trace id>-<span id>-<flags>
            MDC.put("trace", traceparent == null ? "none" : traceparent.split("-")[1]);
            try {
                chain.doFilter(request, response);
            } finally {
                MDC.remove("trace");
            }
        }
    }

    @Component
    static class CommerceTools {

        private static final Logger log = LoggerFactory.getLogger("quotes");

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
            var quote = new Quote("Q-" + UUID.randomUUID().toString().substring(0, 8), sku, quantity, total, "DRAFT");
            log.info("quote {} sku={} quantity={} total={} trace={}", quote.quoteId(), sku, quantity, total, MDC.get("trace"));
            return quote;
        }

        // Lesson 10: a result that carries personal data back to the agent.
        @McpTool(name = "lookup_customer",
                description = "Fetch a customer's contact record by customer id, e.g. C-42.",
                annotations = @McpAnnotations(readOnlyHint = true, destructiveHint = false))
        Customer lookupCustomer(@McpToolParam(description = "Customer id, e.g. C-42") String customerId) {
            return new Customer(customerId, "Jane Doe", "jane.doe@example.com", "+1 415 555 0134",
                    "4111 1111 1111 1111", "Enterprise");
        }

        // Lesson 10: arguments that may carry personal data in. The log line shows what actually arrived.
        @McpTool(name = "add_order_note",
                description = "Attach a free-text note to a quote, e.g. a delivery instruction from the customer.",
                annotations = @McpAnnotations(destructiveHint = false))
        String addOrderNote(@McpToolParam(description = "Quote id, e.g. Q-1a2b3c4d") String quoteId,
                            @McpToolParam(description = "The note, in the customer's words") String note) {
            log.info("note on {} received: \"{}\" trace={}", quoteId, note, MDC.get("trace"));
            return "Note saved on " + quoteId + ".";
        }

        private static Product product(String sku) {
            var product = CATALOG.get(sku);
            if (product == null) {
                throw new IllegalArgumentException("Unknown SKU: " + sku);
            }
            return product;
        }
    }
}
