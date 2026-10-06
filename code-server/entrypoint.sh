#!/bin/sh
set -eu

# Add coder to the group that owns the mounted Docker socket, then restart
# under that group.
if [ -S /var/run/docker.sock ]; then
  gid=$(stat -c %g /var/run/docker.sock)
  if ! id -G | tr ' ' '\n' | grep -qx "$gid"; then
    group=$(getent group "$gid" | cut -d: -f1)
    if [ -z "$group" ]; then
      group=docker-host
      sudo groupadd -g "$gid" "$group"
    fi
    sudo usermod -aG "$group" coder
    exec sudo -E setpriv --reuid=coder --regid=coder --init-groups \
      env PATH="$PATH" USER=coder /usr/bin/entrypoint.sh "$@"
  fi
fi

# Start the image's own entrypoint.
exec /usr/bin/entrypoint.sh "$@"
