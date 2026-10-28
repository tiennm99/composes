FROM ubuntu:24.04

# System packages: shell and editors, build tools, git, and the libraries and
# virtual display the Orca app needs to run headless.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl git openssh-client \
    sudo zsh nano less procps util-linux \
    build-essential unzip \
    libatk-bridge2.0-0 libatspi2.0-0 libasound2t64 libdrm2 libgbm1 \
    libgtk-3-0 libnss3 libxcomposite1 libxdamage1 libxfixes3 \
    libxkbcommon0 libxrandr2 libxss1 \
    xvfb xauth dbus-x11 \
  && rm -rf /var/lib/apt/lists/*

# The image's ubuntu user (uid 1000): zsh, passwordless sudo, owns /workspace.
RUN chsh -s /bin/zsh ubuntu \
  && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
  && chmod 0440 /etc/sudoers.d/ubuntu \
  && mkdir -p /workspace && chown ubuntu:ubuntu /workspace

# Runs the AppImage without FUSE.
ENV LANG=C.UTF-8 \
    SHELL=/bin/zsh \
    APPIMAGE_EXTRACT_AND_RUN=1 \
    PATH=/home/ubuntu/.local/bin:$PATH

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
USER ubuntu
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
