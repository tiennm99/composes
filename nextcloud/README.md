# nextcloud

[Nextcloud](https://github.com/nextcloud/docker) Server: file sync and share,
calendar, contacts and office apps, with web, desktop and mobile clients.

## Containers

| Service | Image | Internal port | Role |
| --- | --- | --- | --- |
| `nextcloud` | `nextcloud:35-apache` | 80 | Web app |
| `cron` | `nextcloud:35-apache` | none | Background jobs, via `/cron.sh` |
| `db` | `postgres:18-alpine` | 5432 | Metadata, users and shares |
| `cache` | `redis:8-alpine` | 6379 | File locking and the distributed cache |

In Coolify, give `nextcloud` the domain from `NEXTCLOUD_DOMAIN` on port `80`.
`nextcloud` and `cron` wait for `db` and `cache` to pass their health checks.

## Setup

1. Set `NEXTCLOUD_DOMAIN`, `NEXTCLOUD_ADMIN_PASSWORD` and `POSTGRES_PASSWORD`.
2. Map the domain to port `80` and deploy. The first start installs Nextcloud
   and creates the admin account.
3. Log in with `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`. The first
   run of `cron` switches background jobs to **Cron** on its own.

Office editing is an app from the app store plus an external document server,
both set up in the admin UI, not in this compose file.

## Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD` | `admin` / — | Admin account |
| `NEXTCLOUD_DOMAIN` | — | Public hostname, without scheme |
| `TRUSTED_PROXIES` | private IPv4 ranges | Proxies allowed to set `X-Forwarded-*` |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | `nextcloud` / `nextcloud` / — | Database credentials, read by `db` and by the install |
| `PHP_MEMORY_LIMIT` | `1G` | PHP `memory_limit` |
| `PHP_UPLOAD_LIMIT` | `16G` | PHP `upload_max_filesize` and `post_max_size` |

`NEXTCLOUD_DOMAIN` fills `NEXTCLOUD_TRUSTED_DOMAINS` and `OVERWRITECLIURL`.
Nextcloud rejects requests for any host not on the trusted list.

The admin and database variables are read only by the first-start install.
The installer creates its own database role and writes it to `config.php`, so
changing them later changes nothing; use the web UI or `occ`.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `nextcloud-html` | `/var/www/html` | Nextcloud code, apps, `config.php` and user files |
| `db-data` | `/var/lib/postgresql` | The database |
| `cache-data` | `/data` | Redis locks and cache |

`cron` mounts the same volume at the same path as `nextcloud`; the two must
match for background jobs to see the same installation.

The Redis contents are rebuilt after a restart, but the `redis` image declares
`/data` a volume, so without a named one Docker creates an anonymous volume on
every recreate.

## Choices

- **Behind a TLS-terminating proxy.** The proxy speaks HTTP to port 80, so
  `OVERWRITEPROTOCOL=https` keeps generated links and redirects on HTTPS.
  `APACHE_DISABLE_REWRITE_IP=1` with `TRUSTED_PROXIES` makes Nextcloud read
  the client IP and host from `X-Forwarded-*`, which brute-force protection
  and the admin overview's proxy check rely on. No port is published, so only
  containers on the app's networks can reach port 80; the private ranges cover
  whatever subnet the proxy network gets.
- **Larger PHP limits.** The image defaults both to `512M`. The web UI and
  the desktop and mobile clients upload in chunks, but WebDAV clients that send
  a file in one request hit `PHP_UPLOAD_LIMIT`, and preview generation for big
  images needs more memory.
- **`cron` container.** Nextcloud's recommended background job mode is system
  cron; the image ships `/cron.sh`, which runs `cron.php` as `www-data` every
  five minutes.
- **`nextcloud:35-apache`.** The major tag takes point releases; Nextcloud
  can only upgrade one major at a time, so a new major is a deliberate change.
  The `apache` variant serves PHP itself, with no separate web server.
- **`postgres:18-alpine`** is the version the Nextcloud 35 admin manual
  recommends. Postgres 18 images keep data under `/var/lib/postgresql/18/`,
  so the volume mounts at `/var/lib/postgresql`. A new Postgres major cannot
  read an older data directory without a dump and restore.
- **`redis:8-alpine`** matches the Redis line upstream's example uses.
