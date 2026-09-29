package com.example.shopping;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import java.math.BigDecimal;
import java.util.List;

@Component
public class DataLoader implements CommandLineRunner {
  private final ProductRepository products;
  public DataLoader(ProductRepository products){this.products=products;}
  @Override public void run(String... args){
    if(products.count()==0) products.saveAll(List.of(
      new Product("Wireless Mouse","Ergonomic wireless mouse",new BigDecimal("24.99"),100),
      new Product("Mechanical Keyboard","Hot-swappable keyboard",new BigDecimal("89.00"),50),
      new Product("USB-C Hub","7-in-1 USB-C hub",new BigDecimal("39.50"),75),
      new Product("Monitor 27 inch","QHD display",new BigDecimal("249.99"),20),
      new Product("Laptop Stand","Aluminum adjustable stand",new BigDecimal("32.00"),60),
      new Product("Webcam","1080p webcam",new BigDecimal("59.99"),40),
      new Product("Headphones","Noise-isolating headphones",new BigDecimal("79.00"),30),
      new Product("Desk Lamp","Dimmable LED lamp",new BigDecimal("28.75"),90),
      new Product("Portable SSD","1TB external SSD",new BigDecimal("119.00"),25),
      new Product("Bluetooth Speaker","Compact portable speaker",new BigDecimal("45.00"),45),
      new Product("Phone Charger","65W USB-C charger",new BigDecimal("29.99"),100),
      new Product("Laptop Sleeve","Protective 15-inch sleeve",new BigDecimal("21.00"),70)
    ));
  }
}
