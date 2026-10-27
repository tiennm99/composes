# opencloud

[OpenCloud](https://docs.opencloud.eu/) Server: file sync and share with web,
desktop and mobile clients, spaces and WebDAV.

One container, `opencloud`, running every OpenCloud service in one process,
including the built-in identity provider, user directory and NATS. Files and
metadata live on disk, so there is no database container.

## Setup

1. Set `OC_DOMAIN` and `INITIAL_ADMIN_PASSWORD`.
2. Map the domain to port `9200` over HTTPS and deploy.
3. Log in as `admin` with `INITIAL_ADMIN_PASSWORD`.

Health check: `GET http://127.0.0.1:9205/healthz`, the proxy's debug endpoint,
also the compose healthcheck. It listens on loopback only.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `OC_DOMAIN` | — | Public hostname, without scheme; becomes `OC_URL` |
| `INITIAL_ADMIN_PASSWORD` | — | Password of the `admin` account |
| `OC_LOG_LEVEL` | `info` | Optional. Log level |
| `PROXY_ENABLE_BASIC_AUTH` | `false` | Optional. Basic auth for WebDAV clients without OpenID Connect |

`OC_URL` must be the exact HTTPS URL the browser uses: the built-in identity
provider uses it as its issuer and redirect target.

`INITIAL_ADMIN_PASSWORD` is read only on first start, when the admin account
is created. Changing it later does not change the password; use the web UI.

`PROXY_TLS=false`, `PROXY_HTTP_ADDR` and `OC_INSECURE=false` are fixed in
`compose.yml`. The platform proxy terminates TLS and forwards plain HTTP to
port `9200`, and the certificate it serves is a real one, so certificate
checks stay on.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `opencloud-config` | `/etc/opencloud` | `opencloud.yaml`, with the generated secrets |
| `opencloud-data` | `/var/lib/opencloud` | User files, spaces, the user directory and search index |

The two volumes belong together. `opencloud.yaml` holds the secrets the data
was written with; a data volume restored without its config volume, or the
reverse, does not start cleanly. Back them up as a pair.

The image creates both directories owned by uid `1000`, the user it runs as,
so fresh named volumes are writable without an init step.

## Choices

- **`opencloud init || true; opencloud server`.** `init` writes
  `opencloud.yaml` with random secrets on first start and fails harmlessly
  once it exists, as in upstream's own compose.
- **No config files.** OpenCloud's built-in CSP and app list cover the web UI
  and the built-in identity provider. Upstream's `csp.yaml` and `apps.yaml`
  only add origins for an external identity provider, office server and
  optional web apps.
- **No office integration.** Editing documents in the browser needs a
  separate office server on its own domain, OpenCloud's collaboration service,
  and a custom `csp.yaml` allowing that domain. The office server also needs
  extra kernel capabilities and a WOPI proof key. None of that can be switched
  on by variables alone, so it is left out.
- **`opencloudeu/opencloud:7`.** The `opencloud` repository carries the
  production releases, and `7` tracks the 7.x line. The `opencloud-rolling`
  repository, which upstream's compose defaults to, ships a new major every
  few months.
