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
    tree fd-find fzf git-delta bat \
    shellcheck shfmt yamllint \
    postgresql-client sqlite3 redis-tools \
    ncdu tmux restic rclone age hyperfine entr 7zip \
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
