# collabora

[Collabora Online](https://www.collaboraonline.com/code/) Development Edition
(CODE): an online office suite for documents, spreadsheets and presentations.
It holds no files itself; a WOPI host, a file server with Collabora
integration, opens documents in it.

One container: `collabora`.

## Setup

1. Set `COLLABORA_ALIASGROUP1` to the WOPI host's URL,
   `COLLABORA_ADMIN_PASSWORD` and `COLLABORA_SERVER_NAME`.
2. Map the domain to port `9980` and deploy.
3. In the WOPI host, set the Collabora server URL to the public `https://`
   address of this domain.

Discovery: `GET /hosting/discovery` returns XML once the server is up. The
image ships its own health check (`coolwsd --probe`, against `/livez`), so the
compose file declares none.

WebSocket editing sessions go through Traefik's default routing; no extra
labels are needed.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `COLLABORA_ALIASGROUP1` | — | Allowed WOPI host, `scheme://host:port`; later comma-separated entries are aliases of it |
| `COLLABORA_ADMIN_USERNAME` / `COLLABORA_ADMIN_PASSWORD` | `admin` / — | Admin console at `/browser/dist/admin/admin.html` |
| `COLLABORA_SERVER_NAME` | empty | Public hostname; empty derives it from each request |
| `COLLABORA_DICTIONARIES` | optional | Space-separated spell-check languages; upstream's default list when unset |

`aliasgroup1` is the only access control on document editing: with no group
set, CODE trusts whichever host connects first after each start. Entries are
regular expressions, so `https://.*\.example\.com:443` allows a whole domain.
A second, unrelated WOPI host needs its own `aliasgroup2` line in
`compose.yml`.

`extra_params` is fixed in `compose.yml`: `--o:ssl.enable=false` serves plain
HTTP on `9980` for Traefik to terminate TLS in front of it, and
`--o:ssl.termination=true` makes CODE build `https://` and `wss://` URLs
anyway. Without it the editor loads over HTTPS but fails on mixed-content
WebSocket URLs.

The admin password fails fast if unset, because the console is served on the
public domain.

## Storage

None. Documents stay on the WOPI host; CODE's jails and cache are rebuilt on
every start.

## Isolation

CODE isolates each document process in a jail, choosing the first that works:
a mount namespace, then a chroot built by `coolforkit-caps`, then landlock.

The compose file adds no capabilities and no `security_opt`. Docker's default
seccomp profile blocks the `unshare` a mount namespace needs, so CODE falls back
to the chroot. `coolforkit-caps` carries file capabilities `CAP_CHOWN`,
`CAP_FOWNER` and `CAP_SYS_CHROOT`, all in Docker's default set, so it works
unprivileged. `MKNOD`, which older CODE images needed, is no longer used.

The price is speed, not safety: without `CAP_SYS_ADMIN` the `coolmount` helper
cannot bind-mount the system template, so each new jail copies it, and
opening a document takes a little longer. The alternatives cost more:
`cap_add: SYS_ADMIN` grants the container broad host-kernel powers, and
upstream's `cool-seccomp-profile.json`, Docker's default list plus the six
namespace and mount syscalls needed, must exist as a file on the host, which a Coolify compose deploy does
not place there.

The startup log line `creating usernamespace for mount user failed` is this
fallback, not a fault. Do not set `no-new-privileges`: `coolforkit-caps` gains
its capabilities on exec, and without them CODE drops to the weaker landlock
jail.

## Image

`collabora/code:latest` is the only moving tag upstream publishes; releases are
versioned `YY.MM.x`. The container keeps no state, so a new release needs only
a redeploy.
