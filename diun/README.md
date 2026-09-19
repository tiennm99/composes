# diun

[Diun](https://crazymax.dev/diun/) watches the images of every running
container and sends a Telegram message when one has an update. It only
notifies — it never pulls or restarts anything.

Two containers: `diun` itself, and `dockerproxy`, which hands it a read-only
slice of the Docker API.

## Docker API access

Diun needs the Docker API to enumerate containers and read the image reference
each one runs. Mounting `/var/run/docker.sock` into it directly would be
host-root-equivalent — the API has no read/write split, so anything that can
talk to the socket can create a privileged container that mounts `/`. Adding
`:ro` to the mount does not help: it stops the socket *file* being replaced, not
the API being used.

So the socket is mounted into
[tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)
instead, and Diun reaches it over the compose network at
`tcp://dockerproxy:2375`. `POST` is revoked by default in that image, so
container create, `exec`, start and kill return 403. A compromised Diun image
can no longer become root on the host — which matters because Diun is the one
service here whose whole job is to talk to the daemon.

Exactly two API sections are granted, both verified against a live watch cycle:

| Variable | Why |
| --- | --- |
| `CONTAINERS` | enumerate running containers |
| `IMAGES` | `ImageInspect` on each container's image — without it every image logs `403 Forbidden` and nothing is analysed |

`INFO`, `NETWORKS`, `VOLUMES` and the rest stay revoked; a watch cycle runs
clean without them.

## Environment

`DIUN_NOTIF_TELEGRAM_TOKEN` and `DIUN_NOTIF_TELEGRAM_CHATIDS` are required and
fail fast if unset. Everything else has a working default.

| Variable | Default | Purpose |
| --- | --- | --- |
| `DIUN_NOTIF_TELEGRAM_TOKEN` | — | Bot token from @BotFather |
| `DIUN_NOTIF_TELEGRAM_CHATIDS` | — | Comma-separated chat ids to notify |
| `DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT` | `true` | Watch every container without per-container labels |
| `DIUN_WATCH_SCHEDULE` | `0 */6 * * *` | Cron for the watch cycle |
| `DIUN_WATCH_WORKERS` | `10` | Parallel registry lookups |
| `DIUN_WATCH_JITTER` | `30s` | Random delay before each job |
| `TZ` | `UTC` | Timezone for the schedule and log timestamps |
| `LOG_LEVEL` / `LOG_JSON` | `info` / `false` | Logging |

State lives in the `diun-data` volume (`DIUN_DB_PATH=/data/diun.db`). Diun
notifies on first sight of an image, so a fresh volume produces one round of
notifications for everything currently running.

## Version pinning

`crazymax/diun:4.33` rather than `:latest`. Diun holds Docker API access, so an
unreviewed image change is the highest-leverage supply-chain step on the host;
the proxy bounds what a bad image could do, and the pin means an image only
changes when this file does.
