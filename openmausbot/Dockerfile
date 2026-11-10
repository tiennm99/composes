# Tailscale in front of the server, sharing its network namespace, with the
# Serve config that forwards HTTPS on the tailnet to the server.
FROM tailscale/tailscale:latest AS tunnel
COPY serve.json /config/serve.json

# The official server image with the engine CLIs installed globally.
FROM ghcr.io/milind-soni/openmausbot:latest AS server
USER root
ARG ENGINES="@anthropic-ai/claude-code @openai/codex"
RUN if [ -n "$ENGINES" ]; then npm install -g $ENGINES && rm -rf /root/.npm /tmp/node-compile-cache; fi
USER maus
