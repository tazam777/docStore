# Build stage
FROM maven:3.8.4-openjdk-17 AS maven-builder

WORKDIR /app
COPY pom.xml .
COPY src ./src

RUN mvn clean package -DskipTests

# Run stage
FROM openjdk:17-jdk-slim

WORKDIR /app
COPY --from=maven-builder /app/target/awsProject-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
