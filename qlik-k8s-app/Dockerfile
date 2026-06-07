# -------- Build Stage --------
FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app

# Optimize dependency caching
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests

# -------- Runtime Stage --------
FROM eclipse-temurin:17-jre

WORKDIR /app

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download OpenTelemetry Java Agent
RUN curl -L -o /app/opentelemetry-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.19.0/opentelemetry-javaagent.jar

# Download Pyroscope OTEL extension
RUN curl -L -o /app/pyroscope-otel.jar \
    https://github.com/grafana/otel-profiling-java/releases/download/v1.0.4/pyroscope-otel.jar

# Copy built application JAR
COPY --from=build /app/target/*.jar /app/app.jar

# -------- Environment Variables (ONLY profiling-related here) --------
ENV OTEL_SERVICE_NAME=qlik-java-app \
    OTEL_TRACES_EXPORTER=otlp \
    OTEL_METRICS_EXPORTER=none \
    OTEL_LOGS_EXPORTER=none \
    OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
    OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability.svc.cluster.local:4317 \
    OTEL_RESOURCE_ATTRIBUTES="service.name=qlik-java-app,deployment.environment=dev" \
    OTEL_JAVAAGENT_EXTENSIONS=/app/pyroscope-otel.jar \
    OTEL_PYROSCOPE_START_PROFILING=true \
    PYROSCOPE_SERVER_ADDRESS=http://pyroscope.devops-tools.svc.cluster.local:4040 \
    PYROSCOPE_APPLICATION_NAME=qlik-java-app

# JVM options (can override at runtime)
ENV JAVA_OPTS=""

# Expose app port
EXPOSE 8080

# Run as non-root (recommended)
RUN useradd -m appuser
USER appuser

# Start application
ENTRYPOINT ["sh","-c","exec java $JAVA_OPTS -javaagent:/app/opentelemetry-javaagent.jar -jar /app/app.jar"]