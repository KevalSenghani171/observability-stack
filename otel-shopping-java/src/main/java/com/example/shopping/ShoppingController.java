package com.example.shopping;

import org.springframework.data.domain.Page;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ShoppingController {
  private final ShoppingService service; private final ProductRepository products;
  public ShoppingController(ShoppingService s,ProductRepository p){service=s;products=p;}

  @GetMapping("/products")
  public Page<Product> products(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="10") int size){
    if(page<0 || size<1 || size>100) throw new IllegalArgumentException("page must be >=0 and size must be 1..100");
    return service.listProducts(page,size);
  }
  @PostMapping("/cart/{cartId}/items")
  public CartLine add(@PathVariable String cartId,@RequestBody AddItemRequest req){return service.addToCart(cartId,req.productId(),req.quantity());}
  @GetMapping("/cart/{cartId}")
  public List<Map<String,Object>> cart(@PathVariable String cartId){return service.viewCart(cartId);}
  @PostMapping("/cart/{cartId}/checkout")
  public OrderRecord checkout(@PathVariable String cartId){return service.checkout(cartId);}
  @PostMapping("/buy/{productId}")
  public OrderRecord buy(@PathVariable Long productId,@RequestParam(defaultValue="1") int quantity,@RequestParam(defaultValue="direct-demo") String cartId){
    service.addToCart(cartId,productId,quantity); return service.checkout(cartId);
  }
  public record AddItemRequest(Long productId,int quantity){}
}
