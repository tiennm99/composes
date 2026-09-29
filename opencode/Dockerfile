FROM ghcr.io/anomalyco/opencode:latest

# Shell, git, HTTP and SSH clients for the commands the agent runs.
RUN apk add --no-cache \
      bash \
      curl \
      git \
      openssh-client

WORKDIR /workspace
