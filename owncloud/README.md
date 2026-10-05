# owncloud

[ownCloud](https://doc.owncloud.com/server/10.16/admin_manual/installation/docker/)
Server: file sync and share, with web, desktop and mobile clients.

Three containers: `owncloud`, `mariadb` for metadata, users and shares, and
`redis` for file locking and the distributed cache.

## Setup

1. Set `OWNCLOUD_DOMAIN`, `OWNCLOUD_ADMIN_PASSWORD`, `DB_PASSWORD` and
   `DB_ROOT_PASSWORD`.
2. Map the domain to port `8080` and deploy. The first start installs
   ownCloud and creates the admin account.
3. Log in with `OWNCLOUD_ADMIN_USERNAME` / `OWNCLOUD_ADMIN_PASSWORD`.

Health check: `/usr/bin/healthcheck`, the image's own script, also the compose
healthcheck.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `OWNCLOUD_DOMAIN` | — | Public hostname, without scheme |
| `OWNCLOUD_ADMIN_USERNAME` / `OWNCLOUD_ADMIN_PASSWORD` | `admin` / — | Admin account |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | `owncloud` / `owncloud` / — | Database credentials, read by both containers |
| `DB_ROOT_PASSWORD` | — | MariaDB root password |

`OWNCLOUD_DOMAIN` also fills `OWNCLOUD_TRUSTED_DOMAINS`; ownCloud rejects
requests for any host not on that list.

The admin variables are read only by the first-start install. Changing them
later does not change the account; use the web UI or `occ user:resetpassword`.

The database credentials are stored inside the MariaDB data directory when it
is first created. Changing them in the environment afterwards breaks the
connection rather than changing the password.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `owncloud-data` | `/mnt/data` | User files, apps, `config.php` |
| `owncloud-mysql-data` | `/var/lib/mysql` | The database |
| `owncloud-redis-data` | `/data` | Redis locks and cache |

The Redis volume follows ownCloud's own compose. Its contents are rebuilt
after a restart, but the `redis` image declares `/data` a volume, so without a
named one Docker creates an anonymous volume on every recreate.

## Images

`owncloud/server:10` tracks the 10.x line. `latest` points at the same
release today, but ownCloud now also publishes 11.x, and a move to a new major
should be a deliberate upgrade with a backup, not a side effect of a pull.

`mariadb:12` and `redis:6` track their major versions. A MariaDB data
directory cannot move back to an older major, so back up the database volume
before changing it.
