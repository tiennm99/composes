# Adds Python, a C toolchain and CLI tooling to the official image, which ships
# none of it. Agent CLIs are not among them -- see README.md, which carries the
# reasoning for everything here.
FROM ghcr.io/getpaseo/paseo:latest

# --- system packages -------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential sudo \
      zsh nano \
 && rm -rf /var/lib/apt/lists/* \
 && usermod -aG sudo paseo

# --- python ----------------------------------------------------------------
ARG PYTHON_VERSION=3.12
ENV UV_INSTALL_DIR=/usr/local/bin \
    UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin
RUN curl -fsSL https://astral.sh/uv/install.sh | sh \
 && uv python install "${PYTHON_VERSION}" --default

# --- gh and glab -----------------------------------------------------------
# gh from GitHub's signed apt repository, glab from the .deb on its releases
# page.
ARG GLAB_VERSION=1.118.0
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_$(dpkg --print-architecture).deb" \
      -o /tmp/glab.deb \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh /tmp/glab.deb \
 && rm -f /tmp/glab.deb \
 && rm -rf /var/lib/apt/lists/*

# --- agent cli path --------------------------------------------------------
# Puts the $HOME directories the agent installers write to on PATH.
ENV PATH=/home/paseo/.local/bin:/home/paseo/.opencode/bin:$PATH

# --- entrypoint ------------------------------------------------------------
# Wraps the image's entrypoint with the root-stage setup -- see entrypoint.sh.
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
