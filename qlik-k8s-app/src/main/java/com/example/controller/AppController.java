package com.example.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AppController {

    @GetMapping("/")
    public String home() {
        return "Qlik Java App Running 🚀";
    }

    @GetMapping("/health")
    public String health() {
        return "OK";
    }
}
