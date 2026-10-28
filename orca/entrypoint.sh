#!/usr/bin/env bash
set -euo pipefail

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
