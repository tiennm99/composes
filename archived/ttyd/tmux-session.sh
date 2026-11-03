#!/usr/bin/env bash
set -euo pipefail

# Attach to the tmux session named by the URL's ?arg=, default "main",
# creating it when missing.
exec tmux new-session -A -s "${1:-main}"
