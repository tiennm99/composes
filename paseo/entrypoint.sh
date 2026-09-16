#!/usr/bin/env bash
# Sets the paseo user's login password from PASEO_PASSWORD, then hands off to
# the image's own entrypoint.
#
# At start rather than at build, so the password never lands in a layer. Here
# rather than after the base entrypoint, which ends in `exec gosu paseo` and so
# never returns, and by then is no longer root. Every start, because
# /etc/shadow is in the image, not the /home/paseo volume, and reverts on each
# container recreate.
set -euo pipefail

if [[ "$(id -u)" == "0" && -n "${PASEO_PASSWORD:-}" ]]; then
  # Piped rather than passed as an argument: arguments are visible in ps.
  # chpasswd splits on the first colon, so a colon in the password is fine.
  printf 'paseo:%s\n' "$PASEO_PASSWORD" | chpasswd
fi

# With PASEO_PASSWORD unset the account keeps its locked password and sudo just
# refuses. The base entrypoint already warns about the missing variable.
exec /usr/local/bin/paseo-docker-entrypoint "$@"
