FROM ubuntu:24.04

# System packages: shell and editors, build tools, network and DNS, search
# and review, lint, sqlite3 for the login token and socat for the web port.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git openssh-client \
    sudo zsh nano vim-tiny less procps \
    build-essential bubblewrap unzip zip \
    iproute2 lsof bind9-dnsutils netcat-openbsd \
    tree fd-find fzf git-delta bat \
    shellcheck shfmt yamllint \
    sqlite3 socat \
  && rm -rf /var/lib/apt/lists/*

# The image's ubuntu user (uid 1000): zsh, passwordless sudo, owns /workspace.
RUN chsh -s /bin/zsh ubuntu \
  && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
  && chmod 0440 /etc/sudoers.d/ubuntu \
  && mkdir -p /workspace && chown ubuntu:ubuntu /workspace

ENV LANG=C.UTF-8 \
    TERM=xterm-256color \
    SHELL=/bin/zsh \
    PATH=/home/ubuntu/.local/bin:$PATH

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER ubuntu
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
