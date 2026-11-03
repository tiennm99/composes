#!/usr/bin/env bash
set -euo pipefail

# Join the group that owns the mounted Docker socket, then restart under it.
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
      env PATH="$PATH" "$0" "$@"
  fi
fi

# Install ttyd into ~/.local/bin when missing.
mkdir -p ~/.local/bin
if ! command -v ttyd >/dev/null; then
  curl -fsSL -o ~/.local/bin/ttyd \
    "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.$(uname -m)"
  chmod +x ~/.local/bin/ttyd
fi

# Empty ~/.zshrc when missing.
touch ~/.zshrc

# ttyd on 0.0.0.0:7681 behind basic auth, one tmux session per ?arg= name.
credential="ubuntu:$PASSWORD"
unset PASSWORD
exec ttyd --port 7681 --writable --check-origin --url-arg \
  --credential "$credential" /usr/local/bin/tmux-session
