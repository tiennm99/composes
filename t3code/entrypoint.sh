#!/usr/bin/env bash
set -euo pipefail

# Install the t3 CLI into ~/.local/bin when missing.
if ! command -v t3 >/dev/null 2>&1; then
  curl -fsSL https://t3.codes/install.sh | sh
fi

# Empty ~/.zshrc when missing.
touch "$HOME/.zshrc"

# T3 Code server on port 3773, on every interface.
exec t3 serve --host 0.0.0.0 --port 3773
