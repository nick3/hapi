# syntax=docker/dockerfile:1

# Build stage: compile hub + web assets
FROM oven/bun:1 AS build
WORKDIR /app

# Copy workspace manifests first for better layer caching
COPY package.json bun.lock tsconfig.base.json ./
COPY cli/package.json cli/package.json
COPY shared/package.json shared/package.json
COPY hub/package.json hub/package.json
COPY web/package.json web/package.json
COPY website/package.json website/package.json
COPY docs/package.json docs/package.json

RUN bun install --frozen-lockfile

# Now copy the rest of the repo
COPY . .

# Build hub + web (hub serves web/dist)
#
# hub/src/web/embeddedAssets.generated.ts is gitignored and may be missing in
# clean checkouts (e.g. GitHub Actions). Generate it from web/dist for bundling.
RUN bun run build:web \
    && (cd hub && bun run generate:embedded-web-assets) \
    && bun run build:hub


# Runtime stage: ship only runtime + built artifacts
FROM oven/bun:1 AS runtime
WORKDIR /app

ENV NODE_ENV=production
# Default values can be overridden at `docker run -e ...`
ENV WEBAPP_PORT=3006
ENV HAPI_HOME=/data

# Create a persistent-friendly data dir
RUN mkdir -p /data

COPY --from=build /app/hub/dist ./hub/dist
COPY --from=build /app/web/dist ./web/dist

WORKDIR /app/hub

EXPOSE 3006

CMD ["bun", "dist/index.js"]
