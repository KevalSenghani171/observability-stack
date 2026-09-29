package com.example.shopping;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name="shop_order")
public class OrderRecord {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  private String cartId;
  private BigDecimal total;
  private String status;
  private Instant createdAt;
  protected OrderRecord(){}
  public OrderRecord(String cartId, BigDecimal total, String status){this.cartId=cartId;this.total=total;this.status=status;this.createdAt=Instant.now();}
  public Long getId(){return id;} public String getCartId(){return cartId;}
  public BigDecimal getTotal(){return total;} public String getStatus(){return status;}
  public Instant getCreatedAt(){return createdAt;}
}
