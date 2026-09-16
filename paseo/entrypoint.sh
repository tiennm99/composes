#!/usr/bin/env bash
# Sets the paseo user's login password from PASEO_PASSWORD, then hands off to
# the image's own entrypoint.
#
# Has to happen at start, not build: the password is a secret and would
# otherwise be baked into a layer. Has to happen here, not in a later hook: the
# base entrypoint ends in `exec gosu paseo`, so it never comes back, and by then
# we are no longer root and cannot write /etc/shadow. And it has to run every
# time -- /etc/shadow sits in the image, not in the /home/paseo volume, so it
# reverts on every container recreate.
set -euo pipefail

if [[ "$(id -u)" == "0" && -n "${PASEO_PASSWORD:-}" ]]; then
  # Piped rather than passed as an argument: arguments are visible in ps.
  # chpasswd splits on the first colon, so a colon in the password is fine.
  printf 'paseo:%s\n' "$PASEO_PASSWORD" | chpasswd
fi

# With PASEO_PASSWORD unset the account keeps its locked password and sudo just
# refuses. The base entrypoint already warns about the missing variable.
exec /usr/local/bin/paseo-docker-entrypoint "$@"
