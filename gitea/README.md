# gitea

Self-hosted [Gitea](https://about.gitea.com/) backed by PostgreSQL.

## Services

| Service | Image | Internal port | Domain |
| --- | --- | --- | --- |
| `db` | `postgres:16-alpine` | 5432 | none |
| `gitea` | `gitea/gitea:28` | 3000 | `GITEA_ROOT_URL` |

In Coolify, give `gitea` a domain on port 3000 matching `GITEA_ROOT_URL`.

`gitea` waits for `db` to pass its health check, and checks `/api/healthz`
itself.

## Variables

| Variable | Feeds | Notes |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | `db`, `gitea` | Defaults to `gitea`. |
| `GITEA_ROOT_URL` | Gitea `server.ROOT_URL` | Public URL, with trailing slash. Gitea builds clone URLs and redirects from it. |
| `GITEA_CLONE_TIMEOUT` | Gitea `git.timeout` `MIGRATE` and `MIRROR` | Seconds a mirror's first clone or a later fetch may run. Defaults to `3600`. |

## Choices

- **HTTPS only.** The proxy routes HTTP, not SSH, so Gitea's SSH server is
  disabled and the UI offers HTTPS clone URLs only.
- **One-hour clone timeout.** Gitea's defaults (600 s to migrate, 300 s to
  fetch) cut off multi-gigabyte repositories mid-clone, leaving empty mirrors
  that still hold gigabytes of unreachable packfiles. A client that calls the
  migrate API gets no response until the clone ends, so it must wait at least
  this long.
- **`gitea/gitea:28`.** Gitea publishes major tags; the major pin takes
  updates without a surprise major upgrade.
- **`postgres:16-alpine`** stays on 16: a new Postgres major cannot read the
  existing data directory without a dump and restore.

## Usage

Complete Gitea's first-run setup at `GITEA_ROOT_URL`, then create an access
token for any tool that mirrors into it.

## Storage

| Volume | Holds |
| --- | --- |
| `db-data` | PostgreSQL data |
| `gitea-data` | Repositories, Gitea config and state |
