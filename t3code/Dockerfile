FROM ubuntu:24.04

# System packages: shell and editors, build tools, git.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl git openssh-client \
    sudo zsh nano less procps \
    build-essential unzip \
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
