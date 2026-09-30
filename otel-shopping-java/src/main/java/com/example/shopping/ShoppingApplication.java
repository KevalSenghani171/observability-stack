
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

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.DependsOn;
import org.springframework.context.annotation.PreDestroy;

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

        Resource resource = Resource.getDefault()
                .toBuilder()
                .put(AttributeKey.stringKey("service.name"), serviceName)
                .build();

        // Trace exporter: sends spans to the OpenTelemetry Collector.
        var spanExporter = OtlpGrpcSpanExporter.builder()
                .setEndpoint(endpoint)
                .build();

        var tracerProvider = SdkTracerProvider.builder()
                .setResource(resource)
                .addSpanProcessor(
                        BatchSpanProcessor.builder(spanExporter).build()
                )
                .build();

        // Log exporter: sends application log records to the Collector.
        var logExporter = OtlpGrpcLogRecordExporter.builder()
                .setEndpoint(endpoint)
                .build();

        var loggerProvider = SdkLoggerProvider.builder()
                .setResource(resource)
                .addLogRecordProcessor(
                        BatchLogRecordProcessor.builder(logExporter).build()
                )
                .build();

        OpenTelemetrySdk otel = OpenTelemetrySdk.builder()
                .setTracerProvider(tracerProvider)
                .setLoggerProvider(loggerProvider)
                .setPropagators(
                        ContextPropagators.create(
                                W3CTraceContextPropagator.getInstance()
                        )
                )
                .build();

        this.openTelemetrySdk = otel;

        // Register the SDK globally for OpenTelemetry integrations.
        GlobalOpenTelemetry.set(otel);

        return otel;
    }

    @Bean
    Tracer tracer(OpenTelemetry otel) {
        return otel.getTracer(
                "com.example.shopping",
                "1.0.0"
        );
    }

    @PreDestroy
    public void shutdownOpenTelemetry() {
        if (openTelemetrySdk != null) {
            openTelemetrySdk.close();
        }
    }
}