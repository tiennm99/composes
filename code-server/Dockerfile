FROM codercom/code-server:latest

USER root

# Extra system packages.
RUN apt-get update \
  && apt-get install -y --no-install-recommends bubblewrap unzip zip \
  && rm -rf /var/lib/apt/lists/*

# Workspace directory, owned by the container user.
RUN mkdir -p /workspace && chown 1000:1000 /workspace

USER 1000
