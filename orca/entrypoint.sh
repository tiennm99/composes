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

# Download the Orca AppImage into ~/.local/bin when missing.
app="$HOME/.local/bin/orca-ide"
mkdir -p "$HOME/.local/bin"
if [[ ! -x "$app" ]]; then
  case "$(uname -m)" in
    aarch64) asset=orca-linux-arm64.AppImage ;;
    *) asset=orca-linux.AppImage ;;
  esac
  curl -fsSL -o "$app.part" \
    "https://github.com/stablyai/orca/releases/latest/download/$asset"
  chmod +x "$app.part"
  mv "$app.part" "$app"
fi

# Empty ~/.zshrc when missing.
touch "$HOME/.zshrc"

# Which pairing link the server prints on start.
case "${ORCA_PAIRING:-runtime}" in
  runtime) pairing=() ;;
  mobile) pairing=(--mobile-pairing) ;;
  none) pairing=(--no-pairing) ;;
  *)
    echo "entrypoint: ORCA_PAIRING must be runtime, mobile or none" >&2
    exit 64
    ;;
esac

# orca serve on port 6768, advertising the public wss:// address.
exec "$app" serve --port 6768 \
  --pairing-address "$ORCA_PAIRING_ADDRESS" "${pairing[@]}"
