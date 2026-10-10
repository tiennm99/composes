# seafile

[Seafile](https://manual.seafile.com/13.0/) Community Edition 13: file sync
and share with libraries, web, desktop and mobile clients. Based on the
official 13.0 Docker compose, without its bundled Caddy; the platform proxy
terminates TLS.

Four containers: `seafile` (Seahub web UI and file server), `notification`
(real-time change notifications over WebSocket), `db` (MariaDB) and `cache`
(Redis).

## Setup

1. Set `SEAFILE_SERVER_HOSTNAME`, `JWT_PRIVATE_KEY`, `INIT_SEAFILE_ADMIN_EMAIL`,
   `INIT_SEAFILE_ADMIN_PASSWORD`, `DB_PASSWORD` and `DB_ROOT_PASSWORD`.
2. Map the domains, both on the same host:

   | Container | Domain | Port |
   | --- | --- | --- |
   | `seafile` | `https://seafile.example.com` | `80` |
   | `notification` | `https://seafile.example.com/notification` | `8083` |

   Keep the app's strip-prefix setting on (the default), so the notification
   server receives `/` rather than `/notification`.
3. Deploy. The first start creates the databases and the admin account; log in
   with `INIT_SEAFILE_ADMIN_EMAIL` / `INIT_SEAFILE_ADMIN_PASSWORD`.

Health check: `curl -f http://localhost:80` inside `seafile`, from the official
compose. Its start period is two minutes instead of the official ten seconds:
the first start creates the databases before Seahub answers, and
`notification` waits for `seafile` to be healthy.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `SEAFILE_SERVER_HOSTNAME` | — | Public hostname, without scheme; also builds the notification URL |
| `JWT_PRIVATE_KEY` | — | Shared secret between `seafile` and `notification`, 32+ characters |
| `INIT_SEAFILE_ADMIN_EMAIL` / `INIT_SEAFILE_ADMIN_PASSWORD` | — | Admin account, first start only |
| `DB_PASSWORD` | — | Password of the `seafile` MariaDB user |
| `DB_ROOT_PASSWORD` | — | MariaDB root password, used by the first start to create the user and databases |
| `TIME_ZONE` | `Etc/UTC` | Server time zone |

`SEAFILE_SERVER_PROTOCOL` is fixed to `https`: TLS ends at the proxy, but the
generated links, CSRF origins and notification URL must use the public scheme.

The `INIT_*` variables and `DB_ROOT_PASSWORD` take effect only on the first
start. Changing them later does not change the admin account or the database
passwords.

Logs go to stdout (`SEAFILE_LOG_TO_STDOUT=true`) so they show in the
platform's log view instead of only under `/shared/seafile/logs`.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `seafile-data` | `/shared` | Libraries, config, logs |
| `db-data` | `/var/lib/mysql` | The ccnet, seafile and seahub databases |
| `cache-data` | `/data` | Redis cache |

`notification` has no volume: it reads its settings from the environment and,
with `SEAFILE_LOG_TO_STDOUT=true`, writes no log file, so the log mount of the
official compose is not needed.

The `redis` image declares `/data` a volume, so without a named one Docker
creates an anonymous volume on every recreate.

## Left out

- **SeaDoc** (`ENABLE_SEADOC=false`). It needs `/sdoc-server/` with the prefix
  stripped and `/socket.io/` with it kept, on the same host. The proxy's
  strip-prefix setting applies to the whole app, so both cannot be routed at
  once.
- **Thumbnail server.** It needs `/thumbnail/` unstripped and
  `/thumbnail/ping` rewritten to `/ping`, the same conflict. Without it, Seahub
  generates thumbnails itself.
- **SeaSearch, Seafile AI, metadata server.** Not needed for file sync;
  SeaSearch publishes no arm64 image.
- **Redis password.** The official compose passes an empty one by default;
  Redis is reachable only on the app's internal network.

## Images

`seafileltd/seafile-mc:13.0-latest` and
`seafileltd/notification-server:13.0-latest` track the 13.0 line. Seafile
publishes no `:13` tag, `latest` has not moved since 2025, and 14 is still a
testing release. A Seafile major upgrade runs database migrations; back up
both volumes first.

`mariadb:10.11` is the version the official 13.0 compose pins, and the tag
follows its patch releases. `MARIADB_AUTO_UPGRADE=1` (from the official compose) runs
`mariadb-upgrade` after a minor update. A MariaDB data directory cannot move
back to an older major.

`redis:8` is the major the official compose's unpinned `redis` resolves to
today; the tag keeps it there instead of following a future major with no
review. Redis holds only cache, so a version change loses nothing.
