# Caddy in front of the server, sharing its network namespace.
FROM caddy:2 AS proxy
COPY Caddyfile /etc/caddy/Caddyfile

# The official server image with the engine CLIs installed globally.
FROM ghcr.io/milind-soni/openmausbot:latest AS server
USER root
ARG ENGINES="@anthropic-ai/claude-code @openai/codex"
RUN if [ -n "$ENGINES" ]; then npm install -g $ENGINES && rm -rf /root/.npm /tmp/node-compile-cache; fi
USER maus
