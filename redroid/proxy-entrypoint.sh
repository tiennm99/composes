#!/bin/sh
# Hash the login password, then start Caddy.
set -eu

BASIC_AUTH_HASH=$(caddy hash-password --plaintext "${BASIC_AUTH_PASSWORD}")
export BASIC_AUTH_HASH
unset BASIC_AUTH_PASSWORD

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
