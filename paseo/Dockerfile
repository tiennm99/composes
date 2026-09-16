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
