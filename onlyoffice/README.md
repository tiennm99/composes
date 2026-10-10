# onlyoffice

[ONLYOFFICE Docs](https://github.com/ONLYOFFICE/Docker-DocumentServer)
Community Edition: an online editor for documents, spreadsheets and
presentations. It has no file storage or user accounts of its own; a storage
app opens files in it and receives the saved result.

One container, `onlyoffice`. Map the domain to port `80`.

## Setup

1. Set `JWT_SECRET`.
2. Map the domain to port `80` and deploy. Every start regenerates the font
   list, so the health check takes a minute or two to pass.
3. Give the storage app the public URL and the same `JWT_SECRET`.

Health check: `GET /healthcheck`. It answers `200` with `false` when a
dependency is down, so the compose healthcheck matches the body `true` rather
than relying on the status code.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `JWT_SECRET` | — | Secret for signing requests between the editor and the storage app |
| `ALLOW_PRIVATE_IP_ADDRESS` | `false` | Allow fetching files from, and calling back to, private IP addresses |

`JWT_ENABLED` is fixed to `true`. `JWT_SECRET` fails fast if unset: the image
otherwise generates a random secret on every start, which breaks the storage
app's connection after each redeploy.

`ALLOW_PRIVATE_IP_ADDRESS` is needed only when the storage app is reached over
a private network, such as a container hostname or a LAN address. The editor
refuses those addresses by default, so leave it off when the storage app uses
a public URL.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `onlyoffice-data` | `/var/www/onlyoffice/Data` | Certificates and generated WOPI keys |
| `onlyoffice-lib` | `/var/lib/onlyoffice` | Document cache and converted files |
| `onlyoffice-logs` | `/var/log/onlyoffice` | Logs |

Nothing here is the documents themselves; those stay in the storage app. The
volumes keep the cache and keys across redeploys.

## Images

`onlyoffice/documentserver:latest`: upstream publishes `X.Y` and `X.Y.Z` tags
but no major tag. Back up the volumes before a pull that crosses a major.

The 9.x images up to 9.4 still run PostgreSQL, RabbitMQ and Redis inside the
container for the Community Edition, in volumes the image declares itself;
upstream's source has since dropped them from the Community build. Either way
no separate database, broker or cache container is needed, and none of their
connection variables are set.

`stop_grace_period: 60s` follows upstream's compose, giving the editor time to
save open documents back to the storage app on shutdown.
