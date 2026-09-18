#!/usr/bin/env bash
# Runs as root ahead of the image's own entrypoint: sets the paseo user's
# login password, then installs any agent CLI named in AGENTS whose command
# does not already run. See README.md.
set -euo pipefail

if [[ "$(id -u)" != "0" ]]; then
  exec /usr/local/bin/paseo-docker-entrypoint "$@"
fi

if [[ -n "${PASEO_PASSWORD:-}" ]]; then
  printf 'paseo:%s\n' "$PASEO_PASSWORD" | /usr/sbin/chpasswd \
    || echo "entrypoint: could not set the paseo password, continuing" >&2
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

/usr/bin/chown paseo:paseo /home/paseo

agents="${AGENTS:-}"

set -f

for agent in ${agents//,/ }; do
  installer="$(agent_installer "$agent")"

  if [[ -z "$installer" ]]; then
    echo "entrypoint: no such agent CLI: $agent" >&2
    continue
  fi

  # 126 and 127 are the shell's own codes for a binary that is missing or
  # cannot be executed; any other code means it ran.
  rc=0
  /usr/sbin/gosu paseo bash -c '"$0" --version' "$agent" >/dev/null 2>&1 \
    || rc=$?

  if (( rc != 126 && rc != 127 )); then
    continue
  fi

  echo "entrypoint: installing $agent"
  /usr/sbin/gosu paseo bash -c "$installer" \
    || echo "entrypoint: $agent failed to install, continuing" >&2
done

exec /usr/local/bin/paseo-docker-entrypoint "$@"
