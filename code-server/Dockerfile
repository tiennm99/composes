FROM codercom/code-server:latest

USER root

# Extra system packages.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential bubblewrap unzip zip \
  && rm -rf /var/lib/apt/lists/*

# Command-line utilities: network and DNS, search and review, lint,
# database clients, and backup and maintenance.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    iproute2 lsof bind9-dnsutils netcat-openbsd socat mtr-tiny whois \
    tree fd-find fzf git-delta bat ripgrep jq \
    shellcheck shfmt yamllint \
    postgresql-client sqlite3 redis-tools \
    ncdu tmux restic rclone age hyperfine entr 7zip \
  && rm -rf /var/lib/apt/lists/*

# GitHub CLI and Docker CLI with its Compose and Buildx plugins, from their apt
# repositories.
RUN . /etc/os-release \
  && arch=$(dpkg --print-architecture) \
  && install -d -m 0755 /etc/apt/keyrings \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli.gpg \
  && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/githubcli.gpg /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$arch signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
  && echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    gh docker-ce-cli docker-compose-plugin docker-buildx-plugin \
  && rm -rf /var/lib/apt/lists/*

# GitLab CLI and Gitea CLI, from the .deb in each project's latest release.
RUN arch=$(dpkg --print-architecture) \
  && v=$(curl -fsSL https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest | jq -r .tag_name | sed 's/^v//') \
  && curl -fsSL -o /tmp/glab.deb "https://gitlab.com/gitlab-org/cli/-/releases/v${v}/downloads/glab_${v}_linux_${arch}.deb" \
  && v=$(curl -fsSL https://gitea.com/api/v1/repos/gitea/cli/releases/latest | jq -r .tag_name | sed 's/^v//') \
  && curl -fsSL -o /tmp/gt.deb "https://gitea.com/gitea/cli/releases/download/v${v}/gitea-cli_${v}_${arch}.deb" \
  && apt-get update \
  && apt-get install -y --no-install-recommends /tmp/glab.deb /tmp/gt.deb \
  && rm -rf /tmp/glab.deb /tmp/gt.deb /var/lib/apt/lists/*

# Desktop GUI build libraries: GTK, WebKitGTK, tray and image loaders.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    pkg-config libwebkit2gtk-4.1-dev libssl-dev \
    libayatana-appindicator3-dev librsvg2-dev libxdo-dev \
  && rm -rf /var/lib/apt/lists/*

# Chromium and fonts for headless browser automation.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    chromium fonts-liberation fonts-noto-color-emoji fonts-noto-cjk \
  && rm -rf /var/lib/apt/lists/*

# Workspace directory, owned by the container user.
RUN mkdir -p /workspace && chown 1000:1000 /workspace

# Startup wrapper: enters DEFAULT_WORKSPACE, joins the Docker socket's group,
# then runs the image's entrypoint.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER 1000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]
