#!/usr/bin/env bash
set -euo pipefail

# Add ubuntu to the group that owns the mounted Docker socket, then restart
# under that group.
if [[ -S /var/run/docker.sock ]]; then
  gid=$(stat -c %g /var/run/docker.sock)
  if ! id -G | tr ' ' '\n' | grep -qx "$gid"; then
    group=$(getent group "$gid" | cut -d: -f1 || true)
    if [[ -z "$group" ]]; then
      group=docker-host
      sudo groupadd -g "$gid" "$group"
    fi
    sudo usermod -aG "$group" ubuntu
    exec sudo -E setpriv --reuid=ubuntu --regid=ubuntu --init-groups \
      env PATH="$PATH" HOME="$HOME" USER=ubuntu "$0" "$@"
  fi
fi

# Install the t3 CLI into ~/.local/bin when missing.
if ! command -v t3 >/dev/null 2>&1; then
  curl -fsSL https://t3.codes/install.sh | sh
fi

# Empty ~/.zshrc when missing.
touch "$HOME/.zshrc"

# T3 Code server on port 3773, on every interface.
exec t3 serve --host 0.0.0.0 --port 3773
