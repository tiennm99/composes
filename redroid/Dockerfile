# syntax=docker/dockerfile:1

# Build ws-scrcpy from upstream master.
FROM node:22-alpine AS build
RUN apk add --no-cache g++ make python3 linux-headers
ADD https://github.com/NetrisTV/ws-scrcpy.git#master /src
WORKDIR /src
RUN npm ci --omit=optional --no-audit --no-fund \
    && npm run dist \
    && npm prune --omit=dev --omit=optional --no-audit --no-fund

# Runtime: the built server, its dependencies and adb.
FROM node:22-alpine
RUN apk add --no-cache android-tools
WORKDIR /app
COPY --from=build /src/dist ./
COPY --from=build /src/node_modules ./node_modules
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
EXPOSE 8000
ENTRYPOINT ["/bin/sh", "/usr/local/bin/entrypoint.sh"]
