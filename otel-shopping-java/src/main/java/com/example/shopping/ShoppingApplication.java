
package com.example.shopping;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator;
import io.opentelemetry.context.propagation.ContextPropagators;
import io.opentelemetry.exporter.otlp.logs.OtlpGrpcLogRecordExporter;
import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.logs.SdkLoggerProvider;
import io.opentelemetry.sdk.logs.export.BatchLogRecordProcessor;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;

import jakarta.annotation.PreDestroy;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class ShoppingApplication {

    private OpenTelemetrySdk openTelemetrySdk;

    public static void main(String[] args) {
        SpringApplication.run(ShoppingApplication.class, args);
    }

    @Bean
    OpenTelemetry openTelemetry(
            @Value("${OTEL_EXPORTER_OTLP_ENDPOINT:http://otel-collector-opentelemetry-collector.observability.svc.cluster.local:4317}")
            String endpoint,

            @Value("${OTEL_SERVICE_NAME:shopping-api}")
            String serviceName) {

        // Define common resource attributes.
        Resource resource = Resource.getDefault()
                .toBuilder()
                .put(AttributeKey.stringKey("service.name"), serviceName)
                .build();

        // -----------------------------------------
        // Configure trace exporter
        // -----------------------------------------

        OtlpGrpcSpanExporter spanExporter =
                OtlpGrpcSpanExporter.builder()
                        .setEndpoint(endpoint)
                        .build();

        SdkTracerProvider tracerProvider =
                SdkTracerProvider.builder()
                        .setResource(resource)
                        .addSpanProcessor(
                                BatchSpanProcessor.builder(spanExporter).build()
                        )
                        .build();

        // -----------------------------------------
        // Configure log exporter
        // -----------------------------------------

        OtlpGrpcLogRecordExporter logExporter =
                OtlpGrpcLogRecordExporter.builder()
                        .setEndpoint(endpoint)
                        .build();

        SdkLoggerProvider loggerProvider =
                SdkLoggerProvider.builder()
                        .setResource(resource)
                        .addLogRecordProcessor(
                                BatchLogRecordProcessor.builder(logExporter).build()
                        )
                        .build();

        // -----------------------------------------
        // Build OpenTelemetry SDK
        // -----------------------------------------

        OpenTelemetrySdk otel =
                OpenTelemetrySdk.builder()
                        .setTracerProvider(tracerProvider)
                        .setLoggerProvider(loggerProvider)
                        .setPropagators(
                                ContextPropagators.create(
                                        W3CTraceContextPropagator.getInstance()
                                )
                        )
                        .build();

        this.openTelemetrySdk = otel;

        // Register SDK globally for OpenTelemetry integrations.
        GlobalOpenTelemetry.set(otel);

        return otel;
    }

    // -----------------------------------------
    // Tracer bean
    // -----------------------------------------

    @Bean
    Tracer tracer(OpenTelemetry otel) {
        return otel.getTracer(
                "com.example.shopping",
                "1.0.0"
        );
    }

    // -----------------------------------------
    // Graceful shutdown
    // -----------------------------------------

    @PreDestroy
    public void shutdownOpenTelemetry() {

        if (openTelemetrySdk != null) {
            openTelemetrySdk.close();
        }
    }
}