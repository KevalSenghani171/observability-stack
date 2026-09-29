package com.example.shopping;

import jakarta.persistence.*;
@Entity
public class CartLine {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  private String cartId;
  private Long productId;
  private int quantity;
  protected CartLine(){}
  public CartLine(String cartId, Long productId, int quantity){this.cartId=cartId;this.productId=productId;this.quantity=quantity;}
  public Long getId(){return id;} public String getCartId(){return cartId;}
  public Long getProductId(){return productId;} public int getQuantity(){return quantity;}
  public void setQuantity(int quantity){this.quantity=quantity;}
}
