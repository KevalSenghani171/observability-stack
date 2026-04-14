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

# Install curl
RUN apt-get update && apt-get install -y \
    curl \
    libc6 \
    && rm -rf /var/lib/apt/lists/*

# Download OpenTelemetry Java Agent
RUN curl -L -o opentelemetry-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.17.0/opentelemetry-javaagent.jar

# Download Pyroscope OTEL extension
RUN curl -L -o pyroscope-otel.jar \
    https://github.com/grafana/otel-profiling-java/releases/download/v1.0.4/pyroscope-otel.jar

# Copy built application JAR
COPY --from=build /app/target/*.jar app.jar

# -------- Environment Variables --------
ENV PYROSCOPE_APPLICATION_NAME=qlik-java-app \
    PYROSCOPE_FORMAT=jfr \
    PYROSCOPE_PROFILER_EVENT=itimer \
    PYROSCOPE_UPLOAD_INTERVAL=15s \
    OTEL_JAVAAGENT_EXTENSIONS=/app/pyroscope-otel.jar \
    OTEL_PYROSCOPE_ADD_PROFILE_URL=false \
    OTEL_PYROSCOPE_ADD_PROFILE_BASELINE_URL=false \
    OTEL_PYROSCOPE_START_PROFILING=true \
    PYROSCOPE_SERVER_ADDRESS=http://pyroscope.devops-tools.svc.cluster.local:4040

# Optional JVM options
ENV JAVA_OPTS=""

# Expose app port
EXPOSE 8080

# Start application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -javaagent:/app/opentelemetry-javaagent.jar -jar /app/app.jar"]