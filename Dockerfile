# v0.8.3

# 1. Base Image - Setup Globals
FROM node:20-alpine AS base
ARG NODE_MAX_OLD_SPACE_SIZE=6144
ENV NODE_MAX_OLD_SPACE_SIZE=$NODE_MAX_OLD_SPACE_SIZE

# Install jemalloc and other system deps
RUN apk add --no-cache jemalloc curl python3 py3-pip && \
    mkdir -p /app

# Set environment variable to use jemalloc
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

WORKDIR /app

# Configure NPM
RUN npm config set fetch-retry-maxtimeout 600000 && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 15000

# 2. Dependencies - Install ALL dependencies (including dev) for building
FROM base AS deps
# Copy ALL package.json files first to leverage cache for npm ci
COPY package.json package-lock.json ./
COPY packages/data-provider/package.json ./packages/data-provider/
COPY packages/data-schemas/package.json ./packages/data-schemas/
COPY packages/api/package.json ./packages/api/
COPY packages/client/package.json ./packages/client/
COPY client/package.json ./client/
COPY api/package.json ./api/

RUN --mount=type=cache,target=/root/.npm npm ci

# 3. Builder - Service Packages
FROM deps AS build-packages
COPY packages ./packages
# Build all packages in order (or parallel if possible, but sequential is safer for deps)
# We can use the root script if it exists, or run them individually.
# Looking at package.json, "build:packages" runs them.
RUN npm run build:packages

# 4. Builder - Frontend Client
FROM deps AS build-client
ENV NODE_OPTIONS="--max-old-space-size=${NODE_MAX_OLD_SPACE_SIZE}"
# Copy source
COPY client ./client
# Copy built packages from previous stage
COPY --from=build-packages /app/packages/data-provider/dist /app/packages/data-provider/dist
COPY --from=build-packages /app/packages/data-schemas/dist /app/packages/data-schemas/dist
COPY --from=build-packages /app/packages/api/dist /app/packages/api/dist
COPY --from=build-packages /app/packages/client/dist /app/packages/client/dist
COPY --from=build-packages /app/packages/client/src /app/packages/client/src

WORKDIR /app/client
# Run build explicitly
RUN npm run build

# 5. Final Image - Production Runtime
FROM base AS production

# Add `uv` for extended MCP support
COPY --from=ghcr.io/astral-sh/uv:0.9.5-python3.12-alpine /usr/local/bin/uv /usr/local/bin/uvx /bin/
RUN uv --version

WORKDIR /app

# Install ONLY production dependencies
COPY package.json package-lock.json ./
COPY packages/data-provider/package.json ./packages/data-provider/
COPY packages/data-schemas/package.json ./packages/data-schemas/
COPY packages/api/package.json ./packages/api/
COPY packages/client/package.json ./packages/client/
COPY client/package.json ./client/
COPY api/package.json ./api/

RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

# Copy Source Code (API only, client is served from dist)
COPY api ./api
COPY config ./config

# Copy Built Artifacts from previous stages
COPY --from=build-packages /app/packages/data-provider/dist ./packages/data-provider/dist
COPY --from=build-packages /app/packages/data-schemas/dist ./packages/data-schemas/dist
COPY --from=build-packages /app/packages/api/dist ./packages/api/dist
COPY --from=build-client /app/client/dist ./client/dist

# Permissions and Environment
RUN mkdir -p /app/client/public/images /app/logs /app/uploads && \
    chown -R node:node /app/client/public/images /app/logs /app/uploads && \
    touch .env && \
    chown node:node .env

USER node

EXPOSE 3080
ENV HOST=0.0.0.0
# Use node directly instead of npm run to save memory/signals
CMD ["node", "api/server/index.js"]
