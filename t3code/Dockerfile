FROM ubuntu:26.04

# System packages: shell and editors, build tools, git.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl git openssh-client \
    sudo zsh nano less procps util-linux \
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

# Fonts for browser screenshots, and ffmpeg.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    fonts-liberation fonts-noto-color-emoji fonts-noto-cjk ffmpeg \
  && rm -rf /var/lib/apt/lists/*

# GitHub CLI and Docker CLI with its Compose and Buildx plugins, from their apt
# repositories.
RUN . /etc/os-release \
  && arch=$(dpkg --print-architecture) \
  && install -d -m 0755 /etc/apt/keyrings \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli.gpg \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/githubcli.gpg /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$arch signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
  && echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    gh docker-ce-cli docker-compose-plugin docker-buildx-plugin \
  && rm -rf /var/lib/apt/lists/*

# GitLab CLI and SOPS, from the .deb in each project's latest release.
RUN arch=$(dpkg --print-architecture) \
  && v=$(curl -fsSL https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest | jq -r .tag_name | sed 's/^v//') \
  && curl -fsSL -o /tmp/glab.deb "https://gitlab.com/gitlab-org/cli/-/releases/v${v}/downloads/glab_${v}_linux_${arch}.deb" \
  && v=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/getsops/sops/releases/latest | sed 's|.*/v||') \
  && curl -fsSL -o /tmp/sops.deb "https://github.com/getsops/sops/releases/download/v${v}/sops_${v}_${arch}.deb" \
  && apt-get update \
  && apt-get install -y --no-install-recommends /tmp/glab.deb /tmp/sops.deb \
  && rm -rf /tmp/glab.deb /tmp/sops.deb /var/lib/apt/lists/*

# Desktop GUI build libraries: GTK, WebKitGTK, tray and image loaders.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    pkg-config libwebkit2gtk-4.1-dev libssl-dev \
    libayatana-appindicator3-dev librsvg2-dev libxdo-dev \
  && rm -rf /var/lib/apt/lists/*

# The image's ubuntu user (uid 1000): zsh, passwordless sudo, owns /workspace.
RUN chsh -s /bin/zsh ubuntu \
  && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
  && chmod 0440 /etc/sudoers.d/ubuntu \
  && mkdir -p /workspace && chown ubuntu:ubuntu /workspace

ENV LANG=C.UTF-8 \
    SHELL=/bin/zsh \
    PATH=/home/ubuntu/.local/bin:$PATH

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
USER ubuntu
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
