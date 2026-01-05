# syntax=docker/dockerfile:1

# Build stage: compile server + web assets
FROM oven/bun:1 AS build
WORKDIR /app

# Copy workspace manifests first for better layer caching
COPY package.json bun.lock tsconfig.base.json ./
COPY cli/package.json cli/package.json
COPY shared/package.json shared/package.json
COPY server/package.json server/package.json
COPY web/package.json web/package.json
COPY website/package.json website/package.json
COPY docs/package.json docs/package.json

RUN bun install --frozen-lockfile

# Now copy the rest of the repo
COPY . .

# Build server + web (server serves web/dist)
#
# server/src/web/embeddedAssets.generated.ts is gitignored and may be missing in
# clean checkouts (e.g. GitHub Actions). Generate it from web/dist for bundling.
RUN bun run build:web \
    && (cd server && bun run generate:embedded-web-assets) \
    && bun run build:server


# Runtime stage: ship only runtime + built artifacts
FROM oven/bun:1 AS runtime
WORKDIR /app

ENV NODE_ENV=production
# Default values can be overridden at `docker run -e ...`
ENV WEBAPP_PORT=3006
ENV HAPI_HOME=/data

# Create a persistent-friendly data dir
RUN mkdir -p /data

COPY --from=build /app/server/dist ./server/dist
COPY --from=build /app/web/dist ./web/dist

WORKDIR /app/server

EXPOSE 3006

CMD ["bun", "dist/index.js"]
