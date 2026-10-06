FROM codercom/code-server:latest

USER root

# Extra system packages.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential bubblewrap unzip zip \
    libffi-dev libssl-dev libyaml-dev zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

# zsh as the container user's login shell.
RUN chsh -s /usr/bin/zsh coder

# Workspace directory, owned by the container user.
RUN mkdir -p /workspace && chown 1000:1000 /workspace

# Startup wrapper: joins the Docker socket's group, then runs the image's entrypoint.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER 1000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]
