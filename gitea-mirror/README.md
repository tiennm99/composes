# gitea-mirror

Self-hosted [Gitea](https://about.gitea.com/) backed by PostgreSQL, with
[gitea-mirror](https://github.com/RayLabsHQ/gitea-mirror) mirroring GitHub
repositories into it.

Publishes ports, unlike the platform-managed services described in the
[root README](../README.md) — but binds them all to `127.0.0.1`, so nothing is
reachable from outside the host. Put a reverse proxy in front for remote
access.

## Services

| Service | Image | Address |
| --- | --- | --- |
| `db` | `postgres:16-alpine` | internal only |
| `gitea` | `gitea/gitea:latest` | `127.0.0.1:3000` (HTTP), `127.0.0.1:2222` (SSH) |
| `gitea-mirror` | `ghcr.io/raylabshq/gitea-mirror:latest` | `127.0.0.1:4321` |

`gitea` waits for `db` to pass its health check before starting.

## Usage

```sh
docker compose up -d
```

Complete Gitea's first-run setup at <http://127.0.0.1:3000>, then configure
mirroring at <http://127.0.0.1:4321>.

Gitea advertises SSH port `2222`:

```sh
git clone ssh://git@127.0.0.1:2222/<owner>/<repo>.git
```

## Configuration

`compose.yml` hardcodes everything — database credentials, ports and the Gitea
SSH port are written inline and read no environment variables. `.env.example`
is not wired up: editing a `.env` has no effect until the compose file consumes
it via `env_file:` or `${VAR}` substitution.

The Postgres credentials are `gitea` / `gitea`. Change them before exposing
this stack beyond localhost.

## Storage

| Volume | Holds |
| --- | --- |
| `db-data` | PostgreSQL data |
| `gitea-data` | Repositories, Gitea config and state |
| `gitea-mirror-data` | Mirror job database |

`docker compose down -v` deletes all three.
