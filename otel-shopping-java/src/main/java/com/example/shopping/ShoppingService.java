package com.example.shopping;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class ShoppingService {

    private static final Logger log = LoggerFactory.getLogger(ShoppingService.class);

    private final ProductRepository products;
    private final CartRepository carts;
    private final OrderRepository orders;
    private final Tracer tracer;

    public ShoppingService(ProductRepository products, CartRepository carts,
                           OrderRepository orders, Tracer tracer) {
        this.products = products;
        this.carts = carts;
        this.orders = orders;
        this.tracer = tracer;
    }

    public Page<Product> listProducts(int page, int size) {
        Span span = tracer.spanBuilder("catalog.list_products").startSpan();
        try (Scope ignored = span.makeCurrent()) {
            span.setAttribute("app.page", page);
            span.setAttribute("app.page_size", size);
            log.info("Listing products: page={}, size={}", page, size);

            Page<Product> result = products.findAll(PageRequest.of(page, size));
            span.setAttribute("app.result_count", result.getNumberOfElements());
            log.info("Products returned: count={}", result.getNumberOfElements());
            return result;
        } catch (RuntimeException e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR);
            log.error("Error listing products: page={}, size={}", page, size, e);
            throw e;
        } finally {
            span.end();
        }
    }

    @Transactional
    public CartLine addToCart(String cartId, Long productId, int quantity) {
        Span span = tracer.spanBuilder("cart.add_item").startSpan();
        try (Scope ignored = span.makeCurrent()) {
            span.setAttribute("app.cart_id", cartId);
            span.setAttribute("app.product_id", productId);
            span.setAttribute("app.quantity", quantity);
            log.info("Adding item to cart: cartId={}, productId={}, quantity={}",
                    cartId, productId, quantity);

            if (quantity < 1) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "quantity must be positive");
            }

            Product product = products.findById(productId)
                    .orElseThrow(() -> new ResponseStatusException(
                            HttpStatus.NOT_FOUND, "product not found"));
            if (product.getStock() < quantity) {
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "insufficient stock");
            }

            CartLine line = carts.findByCartIdAndProductId(cartId, productId);
            if (line == null) {
                line = new CartLine(cartId, productId, quantity);
            } else {
                line.setQuantity(line.getQuantity() + quantity);
            }

            CartLine saved = carts.save(line);
            log.info("Item added to cart: cartId={}, productId={}", cartId, productId);
            return saved;
        } catch (RuntimeException e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR);
            log.error("Error adding item to cart: cartId={}, productId={}",
                    cartId, productId, e);
            throw e;
        } finally {
            span.end();
        }
    }

    public List<Map<String, Object>> viewCart(String cartId) {
        Span span = tracer.spanBuilder("cart.view").startSpan();
        try (Scope ignored = span.makeCurrent()) {
            span.setAttribute("app.cart_id", cartId);
            log.info("Viewing cart: cartId={}", cartId);

            List<Map<String, Object>> out = new ArrayList<>();
            for (CartLine line : carts.findByCartId(cartId)) {
                Product product = products.findById(line.getProductId()).orElseThrow();
                out.add(Map.of(
                        "productId", product.getId(),
                        "name", product.getName(),
                        "quantity", line.getQuantity(),
                        "unitPrice", product.getPrice(),
                        "lineTotal", product.getPrice().multiply(
                                BigDecimal.valueOf(line.getQuantity()))));
            }

            log.info("Cart retrieved: cartId={}, itemCount={}", cartId, out.size());
            return out;
        } catch (RuntimeException e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR);
            log.error("Error viewing cart: cartId={}", cartId, e);
            throw e;
        } finally {
            span.end();
        }
    }

    @Transactional
    public OrderRecord checkout(String cartId) {
        Span span = tracer.spanBuilder("checkout.process").startSpan();
        try (Scope ignored = span.makeCurrent()) {
            span.setAttribute("app.cart_id", cartId);
            log.info("Starting checkout: cartId={}", cartId);

            List<CartLine> lines = carts.findByCartId(cartId);
            if (lines.isEmpty()) {
                log.warn("Checkout rejected because cart is empty: cartId={}", cartId);
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "cart is empty");
            }

            BigDecimal total = BigDecimal.ZERO;
            for (CartLine line : lines) {
                Span itemSpan = tracer.spanBuilder("checkout.validate_and_reserve_item").startSpan();
                try (Scope itemScope = itemSpan.makeCurrent()) {
                    Product product = products.findById(line.getProductId()).orElseThrow();
                    itemSpan.setAttribute("app.product_id", product.getId());
                    log.info("Validating checkout item: productId={}, quantity={}",
                            product.getId(), line.getQuantity());

                    if (product.getStock() < line.getQuantity()) {
                        throw new ResponseStatusException(HttpStatus.CONFLICT,
                                "insufficient stock for " + product.getName());
                    }

                    product.setStock(product.getStock() - line.getQuantity());
                    products.save(product);
                    total = total.add(product.getPrice().multiply(
                            BigDecimal.valueOf(line.getQuantity())));
                } catch (RuntimeException e) {
                    itemSpan.recordException(e);
                    itemSpan.setStatus(StatusCode.ERROR);
                    log.error("Error validating checkout item: productId={}",
                            line.getProductId(), e);
                    throw e;
                } finally {
                    itemSpan.end();
                }
            }

            OrderRecord order = orders.save(new OrderRecord(cartId, total, "PAID_DEMO"));
            carts.deleteByCartId(cartId);

            span.setAttribute("app.order_id", order.getId());
            span.setAttribute("app.order_total", total.doubleValue());
            span.setAttribute("app.payment_status", "PAID_DEMO");
            log.info("Checkout completed: orderId={}, cartId={}, total={}, status={}",
                    order.getId(), cartId, total, "PAID_DEMO");
            return order;
        } catch (RuntimeException e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR);
            log.error("Checkout failed: cartId={}", cartId, e);
            throw e;
        } finally {
            span.end();
        }
    }
}
