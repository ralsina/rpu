# Multi-stage build for Crystal Projects Visualization
FROM crystallang/crystal:1.13.0-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    curl \
    build-base \
    sqlite-dev \
    yaml-dev \
    openssl-dev

# Set working directory
WORKDIR /app

# Copy shard files first for better Docker layer caching
COPY shard.yml shard.lock ./

# Install dependencies
RUN shards install --production

# Copy source code
COPY src/ ./src/
COPY public/ ./public/

# Build the application in release mode
RUN shards build --release --production

# Production stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    git \
    curl \
    sqlite \
    yaml

# Create non-root user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy built binaries from builder stage
COPY --from=builder /app/bin/collect_data /usr/local/bin/collect_data
COPY --from=builder /app/bin/server /usr/local/bin/server

# Copy public files
COPY --from=builder /app/public/ ./public/

# Set permissions
RUN chown -R appuser:appgroup /app
USER appuser

# Expose port
EXPOSE 3000

# Environment variables
ENV PORT=3000
ENV GITHUB_USER=ralsina
ENV MAX_DEPTH=3
ENV MAX_PROJECTS=500
ENV RATE_LIMIT_DELAY=0.1
ENV DATA_FILE=/app/public/projects.json

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/ || exit 1

# Default command runs the server
CMD ["server"]