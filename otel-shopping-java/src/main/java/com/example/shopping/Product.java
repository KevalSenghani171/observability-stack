package com.example.shopping;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.math.BigDecimal;

@Entity
public class Product {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
  private String name;
  private String description;
  private BigDecimal price;
  private int stock;

  protected Product() {}
  public Product(String name, String description, BigDecimal price, int stock) {
    this.name=name; this.description=description; this.price=price; this.stock=stock;
  }
  public Long getId(){return id;} public String getName(){return name;}
  public String getDescription(){return description;} public BigDecimal getPrice(){return price;}
  public int getStock(){return stock;}
  public void setStock(int stock){this.stock=stock;}
}
