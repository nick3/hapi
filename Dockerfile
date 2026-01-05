# Build stage
FROM oven/bun:1.3.5 AS builder

WORKDIR /app

# Copy package files
COPY package.json bun.lock ./
COPY cli/package.json ./cli/
COPY server/package.json ./server/
COPY web/package.json ./web/
COPY shared/package.json ./shared/
COPY website/package.json ./website/
COPY docs/package.json ./docs/

# Install dependencies
RUN bun install --frozen-lockfile

# Copy source code
COPY . .

# Build the project
# 1. Build web assets
# 2. Generate embedded web assets for server
# 3. Build CLI with embedded web assets (single executable)
RUN bun run build:single-exe

# Runtime stage
FROM oven/bun:1.3.5-slim

WORKDIR /app

# Copy the built executable from builder stage
COPY --from=builder /app/cli/dist-exe/bun-linux-x64/hapi /usr/local/bin/hapi

# Set executable permissions
RUN chmod +x /usr/local/bin/hapi

# Create data directory
RUN mkdir -p /root/.hapi

# Expose the default port
EXPOSE 3006

# Set default environment variables
ENV WEBAPP_PORT=3006
ENV HAPI_HOME=/root/.hapi

# Run the server by default
ENTRYPOINT ["hapi"]
CMD ["server"]
