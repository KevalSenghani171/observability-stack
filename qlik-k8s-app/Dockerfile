# FROM maven:3.9.6-eclipse-temurin-17 AS build
FROM eclipse-temurin:17-jdk-alpine
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jdk-alpine

# Download Pyroscope Java Agent
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.17.0/opentelemetry-javaagent.jar opentelemetry-javaagent.jar
ADD https://github.com/grafana/otel-profiling-java/releases/download/v1.0.4/pyroscope-otel.jar pyroscope-otel.jar

ENV PYROSCOPE_APPLICATION_NAME=qlik-java-app
ENV PYROSCOPE_FORMAT=jfr
ENV PYROSCOPE_PROFILING_INTERVAL=10ms
ENV PYROSCOPE_PROFILER_EVENT=itimer
ENV PYROSCOPE_PROFILER_LOCK=10ms
ENV PYROSCOPE_PROFILER_ALLOC=512k
ENV PYROSCOPE_UPLOAD_INTERVAL=15s
ENV OTEL_JAVAAGENT_EXTENSIONS=./pyroscope-otel.jar
ENV OTEL_PYROSCOPE_ADD_PROFILE_URL=false
ENV OTEL_PYROSCOPE_ADD_PROFILE_BASELINE_URL=false
ENV OTEL_PYROSCOPE_START_PROFILING=true

## Useful for debugging
# ENV PYROSCOPE_LOG_LEVEL=debug

## Those environment variables need to be overwritten at runtime, if you are using Grafana Cloud
ENV PYROSCOPE_SERVER_ADDRESS=http://pyroscope.devops-tools.svc.cluster.local:4040
COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java",  "-javaagent:./opentelemetry-javaagent.jar", "-jar", "app.jar" ]