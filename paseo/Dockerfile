# The official image ships no agent CLIs or language toolchains. Add them here,
# one concern per layer, cheapest and least-changing first.
#
# Stays root: the entrypoint needs root to chown the mounted volumes, then
# drops to paseo with gosu itself. Nothing installs into $HOME -- that is
# /home/paseo, a volume mount that masks anything baked in at build time.
FROM ghcr.io/getpaseo/paseo:latest

# --- system packages -------------------------------------------------------
# Everyday shell tooling. git and curl are already in the base image; sudo is
# not, despite Debian's base-passwd shipping an (empty) sudo group.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      less nano jq unzip zip lsof psmisc ugrep bfs zsh sudo \
 && rm -rf /var/lib/apt/lists/* \
 && usermod -aG sudo paseo

# --- python ----------------------------------------------------------------
# Debian 12 only carries 3.11, so fetch a standalone CPython build with uv
# (astral.sh/uv). Both directories sit outside $HOME.
ARG PYTHON_VERSION=3.12
ENV UV_INSTALL_DIR=/usr/local/bin \
    UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin
RUN curl -fsSL https://astral.sh/uv/install.sh | sh \
 && uv python install "${PYTHON_VERSION}" --default

# --- go --------------------------------------------------------------------
# Debian 12 carries 1.19, far too old, so use the official tarball.
ARG GO_VERSION=1.26.8
ENV PATH=/usr/local/go/bin:$PATH
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
      -o /tmp/go.tar.gz \
 && tar -C /usr/local -xzf /tmp/go.tar.gz \
 && rm /tmp/go.tar.gz

# --- gh --------------------------------------------------------------------
# Debian does not package gh, so use GitHub's own signed repository.
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# --- bun -------------------------------------------------------------------
# Only omp needs it: @oh-my-pi/pi-coding-agent is Bun-compiled and its bin
# opens with `#!/usr/bin/env bun`, so without Bun on PATH npm installs an omp
# that cannot start. BUN_INSTALL lands it in /usr/local, not the $HOME/.bun
# default that the paseo-home volume would mask.
ENV BUN_INSTALL=/usr/local
RUN curl -fsSL https://bun.sh/install | bash

# --- agent CLIs ------------------------------------------------------------
# These all publish the same way: a thin launcher plus the real binary as a
# per-platform optional dependency. npm therefore installs exactly what each
# vendor's own installer would, and is not a Node wrapper.
#
# Do not swap any of them for their `curl | bash` installer -- those write to
# $HOME/.local, and $HOME is /home/paseo, a volume that masks whatever the
# build put there. Last because these change most often.
RUN npm install -g \
      @anthropic-ai/claude-code \
      @openai/codex \
      opencode-ai \
      @github/copilot \
      @earendil-works/pi-coding-agent \
      @oh-my-pi/pi-coding-agent

# --- entrypoint ------------------------------------------------------------
# Wraps the image's entrypoint to set the paseo user's password while still
# root -- see entrypoint.sh. tini stays in front of it, as in the base image.
# Last so that editing the script rebuilds only this layer.
COPY --chmod=0755 entrypoint.sh /usr/local/bin/paseo-sudo-entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/paseo-sudo-entrypoint"]
