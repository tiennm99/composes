# gitea-mirror-docker-compose

A small Docker Compose stack that runs a self-hosted [Gitea](https://about.gitea.com/)
instance backed by PostgreSQL, alongside
[gitea-mirror](https://github.com/RayLabsHQ/gitea-mirror) for mirroring
repositories from GitHub into it.

## Services

| Service        | Image                                     | Host address             |
| -------------- | ----------------------------------------- | ------------------------ |
| `db`           | `postgres:16-alpine`                      | internal only            |
| `gitea`        | `gitea/gitea:latest`                      | `127.0.0.1:3000` (HTTP)  |
|                |                                           | `127.0.0.1:2222` (SSH)   |
| `gitea-mirror` | `ghcr.io/raylabshq/gitea-mirror:latest`   | `127.0.0.1:4321`         |

All published ports are bound to `127.0.0.1`, so nothing is reachable from
outside the host. Put a reverse proxy in front if you need remote access.

`gitea` waits for `db` to pass its health check before starting.

## Usage

```sh
docker compose up -d
```

Then open <http://127.0.0.1:3000> to complete Gitea's first-run setup, and
<http://127.0.0.1:4321> to configure mirroring.

To clone over SSH, note that Gitea advertises port `2222`:

```sh
git clone ssh://git@127.0.0.1:2222/<owner>/<repo>.git
```

Stop the stack with `docker compose down`. State lives in named volumes
(`db-data`, `gitea-data`, `gitea-mirror-data`), so it survives a restart; add
`-v` to that command to delete it.

## Configuration

`compose.yml` currently hardcodes its settings — database credentials, ports,
and the Gitea SSH port are written inline rather than read from the
environment. The stack runs as-is with no additional setup.

`.env.example` documents the keys of a `.env` for this deployment, with sample
values. Copy it and fill in your own:

```sh
cp .env.example .env
```

The real `.env` is gitignored and never committed. Replace
`BETTER_AUTH_SECRET` with a freshly generated random value rather than the
sample string.

Note that **`compose.yml` does not currently reference these variables**, so
editing `.env` has no effect until the compose file is wired up to consume it
(via `env_file:` or `${VAR}` substitution). The sample values also differ from
the hardcoded ones in a couple of places — for example `GITEA_SSH_PORT=8022`
versus the `2222` currently published by `compose.yml`.

## Security notes

- The Postgres credentials in `compose.yml` are the default `gitea` / `gitea`.
  Change them before exposing this stack beyond localhost.
- `BETTER_AUTH_SECRET` in `.env.example` is a secret. Generate a fresh random
  value per deployment and keep it out of version control.
