FROM codercom/code-server:latest

USER root

# Extra system packages.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential bubblewrap unzip zip \
    libffi-dev libssl-dev libyaml-dev zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

# Docker CLI with the Compose and Buildx plugins, from Docker's apt repository,
# and GitHub CLI, from GitHub's apt repository.
RUN install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && chmod a+r /etc/apt/keyrings/docker.asc /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && printf '%s\n' \
    'Types: deb' \
    'URIs: https://download.docker.com/linux/debian' \
    "Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")" \
    'Components: stable' \
    "Architectures: $(dpkg --print-architecture)" \
    'Signed-By: /etc/apt/keyrings/docker.asc' \
    > /etc/apt/sources.list.d/docker.sources \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    docker-ce-cli docker-buildx-plugin docker-compose-plugin gh \
  && rm -rf /var/lib/apt/lists/*

# Workspace directory, owned by the container user.
RUN mkdir -p /workspace && chown 1000:1000 /workspace

# Startup wrapper: enters DEFAULT_WORKSPACE, joins the Docker socket's group,
# then runs the image's entrypoint.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER 1000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]
