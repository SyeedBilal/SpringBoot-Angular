# ============================================================
# Stage 1: Build — Node + Angular CLI
# ============================================================
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Install Angular CLI globally
RUN npm install -g @angular/cli@latest --no-fund --no-audit

# Copy dependency manifests first (layer caching)
COPY package.json package-lock.json ./

# Install dependencies (clean install for reproducibility)
RUN npm ci --no-fund --no-audit

# Copy source code
COPY . .

# Build for production (output-hashing for cache-busting)
RUN ng build --configuration=production --output-hashing=all

# ============================================================
# Stage 2: Serve — Nginx (minimal Alpine image)
# ============================================================
FROM nginx:1.27-alpine AS production

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy built Angular app from builder stage
COPY --from=builder /app/dist/* /usr/share/nginx/html

# Copy custom nginx config (handles SPA routing)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

# Switch to non-root user
USER appuser

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
