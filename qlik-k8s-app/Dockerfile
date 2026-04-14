FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app

# Download Pyroscope Java Agent
RUN wget https://github.com/grafana/pyroscope-java/releases/latest/download/pyroscope.jar -O /pyroscope.jar

COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java","-javaagent:/pyroscope.jar","-Dpyroscope.application.name=qlik-java-app","-Dpyroscope.server.address=http://pyroscope.devops-tools.svc.cluster.local:4040","-jar","app.jar"]