# tastyigniter

[TastyIgniter](https://tastyigniter.com) restaurant ordering platform, built
from the local `Dockerfile` (PHP 8.3 FPM) and served by nginx.

Uses `docker-compose.yml`, publishes `${PORT:-80}`, and sets `restart:` and
`container_name:` on every service — unlike the platform-managed services
described in the [root README](../README.md).

## Services

| Service | Image | Role |
| --- | --- | --- |
| `app` | local `Dockerfile` | PHP-FPM application |
| `nginx` | `nginx:alpine` | Web server, published on `${PORT:-80}` |
| `db` | `mysql:8` | Database |
| `queue` | local `Dockerfile` | `artisan queue:work` for background jobs |
| `cron` | local `Dockerfile` | `artisan schedule:run` every 60s |

All five have health checks; `app`, `queue` and `cron` wait on `db`.

## Environment

| Variable | Purpose |
| --- | --- |
| `APP_KEY` | Laravel application key, 32 random characters. Required. |
| `APP_URL` | Public URL. Required. |
| `APP_NAME` / `APP_ENV` / `APP_DEBUG` | Defaults `TastyIgniter` / `production` / `false`. |
| `IGNITER_CARTE_KEY` | TastyIgniter Carte key, if used. |
| `IGNITER_LOCATION_MODE` | `single` or `multiple`. Defaults to `multiple`. |
| `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` | Database credentials. Defaults `tastyigniter` / `tastyigniter` / unset. |
| `DB_PREFIX` | Table prefix. Defaults to `ti_`. |
| `MYSQL_ROOT_PASSWORD` | MySQL root password. Required. |
| `MAIL_MAILER` / `MAIL_FROM_ADDRESS` / `MAIL_FROM_NAME` | Mail delivery. Defaults to the `log` driver. |
| `PORT` | Host port for nginx. Defaults to `80`. |
| `STACK_NAME` | Prefix for volume and network names. Defaults to `tastyigniter`. |

## Storage

| Volume | Holds |
| --- | --- |
| `${STACK_NAME}_dbdata` | MySQL data |
| `${STACK_NAME}_app` | Application files |
| `${STACK_NAME}_storage` | Uploads, cache, logs |

Back up the database with:

```sh
docker compose exec db mysqldump -u root -p tastyigniter > backup.sql
```
