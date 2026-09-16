# The official image ships no agent CLIs or language toolchains. Add them here.
#
# Stays root: the entrypoint needs root to chown the mounted volumes, then
# drops to paseo with gosu itself. Nothing installs into $HOME -- that is
# /home/paseo, a volume mount that masks anything baked in at build time.
FROM ghcr.io/getpaseo/paseo:latest

ARG GO_VERSION=1.26.8
ARG PYTHON_VERSION=3.12

# npm here delivers the same native binary as Anthropic's standalone installer;
# it is not a Node wrapper. Do not swap it for the `curl | bash` installer,
# which writes to $HOME/.local.
RUN npm install -g @anthropic-ai/claude-code

# Everyday shell tooling, plus gh from GitHub's own signed repo since Debian
# does not package it.
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      gh less jq unzip zip lsof psmisc ugrep bfs zsh \
 && rm -rf /var/lib/apt/lists/*

# Python via uv (astral.sh/uv), which fetches a standalone CPython build.
# Debian 12 only carries 3.11, and both dirs are kept outside $HOME.
ENV UV_INSTALL_DIR=/usr/local/bin \
    UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin
RUN curl -fsSL https://astral.sh/uv/install.sh | sh \
 && uv python install "${PYTHON_VERSION}" --default

# Go from the official tarball. Debian 12 carries 1.19, far too old.
ENV PATH=/usr/local/go/bin:$PATH
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
      -o /tmp/go.tar.gz \
 && tar -C /usr/local -xzf /tmp/go.tar.gz \
 && rm /tmp/go.tar.gz
