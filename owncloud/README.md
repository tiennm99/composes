# owncloud

[ownCloud](https://doc.owncloud.com/server/11.0/admin_manual/installation/installing_with_docker.html)
Server: file sync and share, with web, desktop and mobile clients.

Three containers: `owncloud`, `db` (MariaDB) for metadata, users and shares, and
`cache` (Redis) for file locking and the distributed cache.

## Setup

1. Set `OWNCLOUD_DOMAIN`, `OWNCLOUD_ADMIN_PASSWORD`, `DB_PASSWORD` and
   `DB_ROOT_PASSWORD`.
2. Map the domain to port `8080` and deploy. The first start installs
   ownCloud and creates the admin account.
3. Log in with `OWNCLOUD_ADMIN_USERNAME` / `OWNCLOUD_ADMIN_PASSWORD`.

Health check: `/usr/bin/healthcheck`, the image's own script, also the compose
healthcheck. It requests `/status.php` on port `8080`.

Every start runs `occ upgrade` when `config.php` on `owncloud-data` says
ownCloud is installed, and a fresh install otherwise. A new image version is
therefore migrated on the next deploy, against whatever database `db` holds.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `OWNCLOUD_DOMAIN` | — | Public hostname, without scheme |
| `OWNCLOUD_ADMIN_USERNAME` / `OWNCLOUD_ADMIN_PASSWORD` | `admin` / — | Admin account |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | `owncloud` / `owncloud` / — | Database credentials, read by both containers |
| `DB_ROOT_PASSWORD` | — | MariaDB root password |

`OWNCLOUD_DOMAIN` also fills `OWNCLOUD_TRUSTED_DOMAINS`; ownCloud rejects
requests for any host not on that list.

TLS ends at the proxy, so ownCloud sees plain HTTP. `OWNCLOUD_OVERWRITE_PROTOCOL`
makes the URLs it generates `https`, and `OWNCLOUD_PROTOCOL` does the same for
the URL `occ` and cron jobs use in links.

The admin variables are read only by the first-start install. Changing them
later does not change the account; use the web UI or `occ user:resetpassword`.

The database credentials are stored inside the MariaDB data directory when it
is first created. Changing them in the environment afterwards breaks the
connection rather than changing the password.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `owncloud-data` | `/mnt/data` | User files, apps, `config.php` |
| `db-data` | `/var/lib/mysql` | The database |
| `cache-data` | `/data` | Redis locks and cache |

The Redis volume follows ownCloud's own compose. Its contents are rebuilt
after a restart, but the `redis` image declares `/data` a volume, so without a
named one Docker creates an anonymous volume on every recreate.

## Images

`owncloud/server:11` tracks the 11.x line, so patch releases arrive on the next
deploy and a move to a new major stays a deliberate upgrade. ownCloud's own
compose pins a full version instead.

`mariadb:10.11` is the release ownCloud 11's compose uses and the top of the
MariaDB range ownCloud supports (10.2 to 10.11); a newer major is outside it.
`MARIADB_AUTO_UPGRADE=1`, also from ownCloud's compose, runs `mariadb-upgrade`
when the server version changes. A MariaDB data directory cannot move back to
an older major, so going down a version means a dump and restore into an empty
volume, not an image change. Back up `db-data` before changing the tag.

`redis:7` is the version ownCloud's compose uses.

ownCloud 11 runs on PHP 8. Apps installed into `/mnt/data/apps` from the
marketplace under 10.x were built for PHP 7, so they are removed or replaced
with PHP 8 versions before moving a 10.x install to 11.
