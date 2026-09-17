#!/usr/bin/env bash
# Runs as root ahead of the image's own entrypoint: sets the paseo user's
# login password, installs SDKMAN, then installs any agent CLI named in
# AGENT_CLIS that is not already on PATH. See README.md.
set -euo pipefail

if [[ "$(id -u)" == "0" && -n "${PASEO_PASSWORD:-}" ]]; then
  printf 'paseo:%s\n' "$PASEO_PASSWORD" | chpasswd
fi

agent_installer() {
  case "$1" in
    claude)   echo 'curl -fsSL https://claude.ai/install.sh | bash' ;;
    codex)    echo 'curl -fsSL https://chatgpt.com/codex/install.sh | sh' ;;
    opencode) echo 'curl -fsSL https://opencode.ai/install | bash' ;;
    copilot)  echo 'curl -fsSL https://gh.io/copilot-install | bash' ;;
    omp)      echo 'curl -fsSL https://omp.sh/install | sh' ;;
    pi)       echo 'curl -fsSL https://pi.dev/install.sh | sh' ;;
  esac
}

if [[ "$(id -u)" == "0" ]]; then
  chown paseo:paseo /home/paseo

  if [[ ! -d "${SDKMAN_DIR:-/home/paseo/.sdkman}" ]]; then
    echo "entrypoint: installing sdkman"
    gosu paseo bash -c 'curl -fsSL https://get.sdkman.io | bash' \
      || echo "entrypoint: sdkman failed to install, continuing" >&2
  fi

  agents="${AGENT_CLIS:-}"

  for agent in ${agents//,/ }; do
    installer="$(agent_installer "$agent")"

    if [[ -z "$installer" ]]; then
      echo "entrypoint: no such agent CLI: $agent" >&2
      continue
    fi

    if command -v "$agent" >/dev/null 2>&1; then
      continue
    fi

    echo "entrypoint: installing $agent"
    gosu paseo bash -c "$installer" \
      || echo "entrypoint: $agent failed to install, continuing" >&2
  done
fi

exec /usr/local/bin/paseo-docker-entrypoint "$@"
