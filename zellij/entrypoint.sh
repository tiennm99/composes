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

# Install Zellij into ~/.local/bin when missing.
mkdir -p ~/.local/bin ~/.config/zellij
if ! command -v zellij >/dev/null; then
  curl -fsSL "https://github.com/zellij-org/zellij/releases/latest/download/zellij-$(uname -m)-unknown-linux-musl.tar.gz" \
    | tar -xzf - -C ~/.local/bin zellij
fi

# Empty Zellij config and ~/.zshrc when missing.
touch ~/.config/zellij/config.kdl ~/.zshrc

# Register PASSWORD as the login token named "password", replacing the
# previous one and its browser sessions, then hide it from the shells.
zellij web --list-tokens >/dev/null
hash=$(printf '%s' "$PASSWORD" | sha256sum | cut -d' ' -f1)
sqlite3 ~/.local/share/zellij/tokens.db <<SQL
DELETE FROM session_tokens WHERE auth_token_hash IN
  (SELECT token_hash FROM tokens WHERE name = 'password' AND token_hash != '$hash');
DELETE FROM tokens WHERE name = 'password' AND token_hash != '$hash';
INSERT OR IGNORE INTO tokens (token_hash, name) VALUES ('$hash', 'password');
SQL
unset PASSWORD hash

# Zellij web server on loopback, relayed to 0.0.0.0:8080; stop both when
# either exits or the container stops.
zellij web --ip 127.0.0.1 --port 8082 &
socat TCP-LISTEN:8080,fork,reuseaddr,nodelay TCP:127.0.0.1:8082,nodelay &
trap 'kill $(jobs -p) 2>/dev/null' TERM INT
wait -n || true
kill $(jobs -p) 2>/dev/null || true
exit 1
