package com.example.shopping;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.math.BigDecimal;
import java.util.*;

@Service
public class ShoppingService {
  private final ProductRepository products; private final CartRepository carts;
  private final OrderRepository orders; private final Tracer tracer;
  public ShoppingService(ProductRepository p, CartRepository c, OrderRepository o, Tracer t){products=p;carts=c;orders=o;tracer=t;}

  public Page<Product> listProducts(int page,int size){
    Span span=tracer.spanBuilder("catalog.list_products").startSpan();
    try(Scope ignored=span.makeCurrent()){
      span.setAttribute("app.page",page); span.setAttribute("app.page_size",size);
      Page<Product> result=products.findAll(PageRequest.of(page,size));
      span.setAttribute("app.result_count",result.getNumberOfElements());
      return result;
    } catch(RuntimeException e){span.recordException(e);span.setStatus(StatusCode.ERROR);throw e;} finally{span.end();}
  }

  @Transactional
  public CartLine addToCart(String cartId,Long productId,int quantity){
    Span span=tracer.spanBuilder("cart.add_item").startSpan();
    try(Scope ignored=span.makeCurrent()){
      span.setAttribute("app.cart_id",cartId); span.setAttribute("app.product_id",productId);
      span.setAttribute("app.quantity",quantity);
      if(quantity<1) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"quantity must be positive");
      Product product=products.findById(productId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"product not found"));
      if(product.getStock()<quantity) throw new ResponseStatusException(HttpStatus.CONFLICT,"insufficient stock");
      CartLine line=carts.findByCartIdAndProductId(cartId,productId);
      if(line==null) line=new CartLine(cartId,productId,quantity); else line.setQuantity(line.getQuantity()+quantity);
      return carts.save(line);
    } catch(RuntimeException e){span.recordException(e);span.setStatus(StatusCode.ERROR);throw e;} finally{span.end();}
  }

  public List<Map<String,Object>> viewCart(String cartId){
    Span span=tracer.spanBuilder("cart.view").startSpan();
    try(Scope ignored=span.makeCurrent()){
      span.setAttribute("app.cart_id",cartId);
      List<Map<String,Object>> out=new ArrayList<>();
      for(CartLine line:carts.findByCartId(cartId)){
        Product p=products.findById(line.getProductId()).orElseThrow();
        out.add(Map.of("productId",p.getId(),"name",p.getName(),"quantity",line.getQuantity(),"unitPrice",p.getPrice(),"lineTotal",p.getPrice().multiply(BigDecimal.valueOf(line.getQuantity()))));
      }
      return out;
    }catch(RuntimeException e){span.recordException(e);span.setStatus(StatusCode.ERROR);throw e;}finally{span.end();}
  }

  @Transactional
  public OrderRecord checkout(String cartId){
    Span span=tracer.spanBuilder("checkout.process").startSpan();
    try(Scope ignored=span.makeCurrent()){
      span.setAttribute("app.cart_id",cartId);
      List<CartLine> lines=carts.findByCartId(cartId);
      if(lines.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"cart is empty");
      BigDecimal total=BigDecimal.ZERO;
      for(CartLine line:lines){
        Span itemSpan=tracer.spanBuilder("checkout.validate_and_reserve_item").startSpan();
        try(Scope itemScope=itemSpan.makeCurrent()){
          Product p=products.findById(line.getProductId()).orElseThrow();
          itemSpan.setAttribute("app.product_id",p.getId());
          if(p.getStock()<line.getQuantity()) throw new ResponseStatusException(HttpStatus.CONFLICT,"insufficient stock for "+p.getName());
          p.setStock(p.getStock()-line.getQuantity()); products.save(p);
          total=total.add(p.getPrice().multiply(BigDecimal.valueOf(line.getQuantity())));
        }catch(RuntimeException e){itemSpan.recordException(e);itemSpan.setStatus(StatusCode.ERROR);throw e;}finally{itemSpan.end();}
      }
      OrderRecord order=orders.save(new OrderRecord(cartId,total,"PAID_DEMO"));
      carts.deleteByCartId(cartId);
      span.setAttribute("app.order_id",order.getId());span.setAttribute("app.order_total",total.doubleValue());
      span.setAttribute("app.payment_status","PAID_DEMO");
      return order;
    }catch(RuntimeException e){span.recordException(e);span.setStatus(StatusCode.ERROR);throw e;}finally{span.end();}
  }
}
