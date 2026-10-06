# Adds a C toolchain, sudo, zsh and nano to the official image. See README.md,
# which carries the reasoning for everything here.
FROM ghcr.io/getpaseo/paseo:latest

# --- system packages -------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential sudo \
      zsh nano \
 && rm -rf /var/lib/apt/lists/* \
 && usermod -aG sudo paseo

# --- agent cli path --------------------------------------------------------
# Puts the $HOME directories the agent and tool installers write to on PATH.
ENV PATH=/home/paseo/.local/bin:/home/paseo/.opencode/bin:$PATH

# --- entrypoint ------------------------------------------------------------
# Wraps the image's entrypoint with the root-stage setup -- see entrypoint.sh.
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
