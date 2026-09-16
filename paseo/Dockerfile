# The official image ships no agent CLIs. Add Claude Code globally under
# /usr/local, where the unprivileged paseo user can run it.
#
# npm here delivers the same native binary as the standalone installer -- it is
# not a Node wrapper. Do not swap this for the `curl | bash` installer: that
# writes to $HOME/.local, and $HOME is /home/paseo, a volume mount that masks
# anything baked in at build time.
#
# Stays root: the entrypoint needs root to chown the mounted volumes, then
# drops to paseo with gosu itself.
FROM ghcr.io/getpaseo/paseo:latest

RUN npm install -g @anthropic-ai/claude-code

# gh is not in the Debian repos, so pull it from GitHub's own signed one.
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*
