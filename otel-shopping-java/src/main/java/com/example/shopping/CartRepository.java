package com.example.shopping;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CartRepository extends JpaRepository<CartLine, Long> {
  List<CartLine> findByCartId(String cartId);
  CartLine findByCartIdAndProductId(String cartId, Long productId);
  void deleteByCartId(String cartId);
}
