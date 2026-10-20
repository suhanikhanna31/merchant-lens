# ---- Build stage ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -DskipTests package

# ---- Runtime stage ----
FROM eclipse-temurin:17-jre
RUN useradd --system --uid 10001 appuser
WORKDIR /app
COPY --from=build /build/target/merchantlens-api-*.jar app.jar
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
