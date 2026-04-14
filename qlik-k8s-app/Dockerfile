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
FROM eclipse-temurin:17-jdk

WORKDIR /app

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download OpenTelemetry Java Agent
RUN curl -L -o /app/opentelemetry-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.17.0/opentelemetry-javaagent.jar

# Download Pyroscope OTEL extension
RUN curl -L -o /app/pyroscope-otel.jar \
    https://github.com/grafana/otel-profiling-java/releases/download/v1.0.4/pyroscope-otel.jar

# Copy built application JAR
COPY --from=build /app/target/*.jar /app/app.jar

# -------- Environment Variables (ONLY profiling-related here) --------
ENV PYROSCOPE_APPLICATION_NAME=qlik-java-app \
    PYROSCOPE_FORMAT=jfr \
    PYROSCOPE_UPLOAD_INTERVAL=30s \
    OTEL_JAVAAGENT_EXTENSIONS=/app/pyroscope-otel.jar \
    OTEL_PYROSCOPE_START_PROFILING=true \
    PYROSCOPE_SERVER_ADDRESS=http://pyroscope.devops-tools.svc.cluster.local:4040

# JVM options (can override at runtime)
ENV JAVA_OPTS=""

# Expose app port
EXPOSE 8080

# Run as non-root (recommended)
RUN useradd -m appuser
USER appuser

# Start application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -javaagent:/app/opentelemetry-javaagent.jar -jar /app/app.jar"]