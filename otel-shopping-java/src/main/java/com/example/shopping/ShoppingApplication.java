package com.example.shopping;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator;
import io.opentelemetry.context.propagation.ContextPropagators;
import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.semconv.ResourceAttributes;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class ShoppingApplication {
  public static void main(String[] args) { SpringApplication.run(ShoppingApplication.class, args); }

  @Bean
  OpenTelemetry openTelemetry(@Value("${OTEL_EXPORTER_OTLP_ENDPOINT:http://localhost:4317}") String endpoint,
                              @Value("${OTEL_SERVICE_NAME:shopping-api}") String serviceName) {
    var exporter = OtlpGrpcSpanExporter.builder().setEndpoint(endpoint).build();
    var provider = SdkTracerProvider.builder()
        .setResource(Resource.getDefault().toBuilder().put(AttributeKey.stringKey("service.name"), serviceName).build())
        .addSpanProcessor(BatchSpanProcessor.builder(exporter).build()).build();
    return OpenTelemetrySdk.builder().setTracerProvider(provider)
        .setPropagators(ContextPropagators.create(W3CTraceContextPropagator.getInstance())).build();
  }

  @Bean Tracer tracer(OpenTelemetry otel) { return otel.getTracer("com.example.shopping", "1.0.0"); }
}
