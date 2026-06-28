# syntax=docker/dockerfile:1
FROM maven:3-amazoncorretto-25-alpine AS builder

WORKDIR /app

COPY . .

RUN mvn clean package -DskipTests

FROM amazoncorretto:25-alpine3.21

WORKDIR /app

RUN addgroup -S appuser && adduser -S appuser -G appuser

COPY --chown=appuser:appuser --from=builder /app/target/money-transfer.jar /app/money-transfer.jar

USER appuser

EXPOSE 8080

CMD ["java", "-jar", "money-transfer.jar"]