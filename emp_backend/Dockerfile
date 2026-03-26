# ============================================================
# Stage 1: Build — Maven + JDK
# ============================================================
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder

# Use Java 21 as specified in pom.xml
WORKDIR /build

# Copy only dependency descriptors first (maximises layer caching)
COPY pom.xml .
COPY .mvn/ .mvn/

# Download all dependencies in a separate cached layer
RUN mvn dependency:go-offline -B --no-transfer-progress

# Copy source code
COPY src/ src/

# Package the application (skip tests here; run them in CI before Docker build)
RUN mvn package -B --no-transfer-progress -DskipTests

# ============================================================
# Stage 2: Extract layers — Spring Boot layertools
#   Splits the fat JAR into four fine-grained layers so that
#   only changed layers are pushed/pulled on subsequent builds.
# ============================================================
FROM eclipse-temurin:21-jre-alpine AS extractor

WORKDIR /extract

# Copy fat JAR from builder
COPY --from=builder /build/target/*.jar app.jar

# Extract layers using Spring Boot Layertools
RUN java -Djarmode=layertools -jar app.jar extract

# ============================================================
# Stage 3: Production runtime
# ============================================================
FROM eclipse-temurin:21-jre-alpine AS production

# Install curl for health checks, then clean up
RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy Spring Boot layers in dependency-change-frequency order
# (least-frequently changed → most-frequently changed)
COPY --from=extractor --chown=appuser:appgroup /extract/dependencies/          ./
COPY --from=extractor --chown=appuser:appgroup /extract/spring-boot-loader/    ./
COPY --from=extractor --chown=appuser:appgroup /extract/snapshot-dependencies/ ./
COPY --from=extractor --chown=appuser:appgroup /extract/application/           ./

# JVM tuning for containers:
#   UseContainerSupport  — respect cgroup CPU/memory limits (on by default in JDK 11+, explicit here for clarity)
#   MaxRAMPercentage     — use 75 % of container memory for the heap
#   ExitOnOutOfMemoryError — crash fast instead of limping along
#   +UseG1GC             — G1 is the default in JDK 9+; explicit for documentation
ENV JAVA_OPTS="\
  -XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=75.0 \
  -XX:+ExitOnOutOfMemoryError \
  -XX:+UseG1GC \
  -Djava.security.egd=file:/dev/./urandom"

# Default Spring profile (override with --env SPRING_PROFILES_ACTIVE=prod)
ENV SPRING_PROFILES_ACTIVE=prod

# App port
EXPOSE 8080

# Health check (Spring Boot Actuator endpoint)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Switch to non-root
USER appuser

# Run via Spring Boot's custom JarLauncher (no fat JAR needed — uses extracted layers)
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]