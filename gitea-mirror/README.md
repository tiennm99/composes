# gitea-mirror

Self-hosted [Gitea](https://about.gitea.com/) backed by PostgreSQL, with
[gitea-mirror](https://github.com/RayLabsHQ/gitea-mirror) mirroring GitHub
repositories into it.

## Services

| Service | Image | Internal port | Domain |
| --- | --- | --- | --- |
| `db` | `postgres:16-alpine` | 5432 | none |
| `gitea` | `gitea/gitea:28` | 3000 | `GITEA_ROOT_URL` |
| `gitea-mirror` | `ghcr.io/raylabshq/gitea-mirror:latest` | 4321 | `GITEA_MIRROR_URL` |

In Coolify, give `gitea` and `gitea-mirror` each a domain on their internal
port, matching the two URL variables.

`gitea` waits for `db` to pass its health check. `gitea` checks
`/api/healthz`; the `gitea-mirror` image ships its own health check.

## Variables

| Variable | Feeds | Notes |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | `db`, `gitea` | Defaults to `gitea`. |
| `GITEA_ROOT_URL` | Gitea `server.ROOT_URL` | Public URL, with trailing slash. Gitea builds clone URLs and redirects from it. |
| `GITEA_CLONE_TIMEOUT` | Gitea `git.timeout` `MIGRATE` and `MIRROR`; gitea-mirror `BUN_CONFIG_HTTP_IDLE_TIMEOUT` | Seconds a mirror's first clone or a later fetch may run. Defaults to `3600`; at most `14340`. |
| `BETTER_AUTH_SECRET` | gitea-mirror | Signs sessions and encrypts its login keys. Generate with `openssl rand -base64 32`. |
| `ENCRYPTION_SECRET` | gitea-mirror | Encrypts the stored GitHub and Gitea tokens. Generate with `openssl rand -base64 48`. |
| `GITEA_MIRROR_URL` | `BETTER_AUTH_URL`, `PUBLIC_BETTER_AUTH_URL`, `BETTER_AUTH_TRUSTED_ORIGINS` | Public URL of the mirror UI, no trailing slash. |

Postgres sets the password only when it first initialises `db-data`. Changing
`POSTGRES_PASSWORD` later breaks Gitea's connection until the role is altered
to match:

```sh
docker compose exec db psql -U gitea -c "ALTER USER gitea PASSWORD '<new>';"
```

Behind a reverse proxy, gitea-mirror rejects sign-in with "invalid origin"
unless all three Better Auth variables hold the external URL, so one variable
feeds them all.

Both secrets are set explicitly rather than left to the image, which would
otherwise generate its own into `gitea-mirror-data`. Data encrypted under one
secret is unreadable under another, so moving the data to a new deployment
means carrying the secrets with it. Never change either on an existing
install.

## Choices

- **HTTPS only.** The proxy routes HTTP, not SSH, so Gitea's SSH server is
  disabled and the UI offers HTTPS clone URLs only.
- **One-hour clone timeout.** Gitea's defaults (600 s to migrate, 300 s to
  fetch) cut off multi-gigabyte repositories mid-clone, leaving empty mirrors
  that still hold gigabytes of unreachable packfiles.
- **gitea-mirror waits as long as Gitea clones.** Gitea's migrate API sends
  nothing until the clone ends, and Bun's `fetch` drops a connection idle for
  5 minutes. gitea-mirror then marks the repository failed while Gitea keeps
  cloning; on retry it finds the half-made repository and marks it mirrored.
  If that clone later fails, Gitea keeps an empty repository with no mirror
  record, which never syncs. `BUN_CONFIG_HTTP_IDLE_TIMEOUT` takes the same
  value as the clone timeout so the request outlives the clone. Bun caps it
  at 239 minutes, so a larger `GITEA_CLONE_TIMEOUT` stops helping there.
- **A redeploy kills clones in progress.** Gitea restarts and the clone dies
  with it. Avoid pushing to this directory while a large first mirror runs.
- **`gitea/gitea:28`.** Gitea publishes major tags; the major pin takes
  updates without a surprise major upgrade.
- **`gitea-mirror:latest`** with `pull_policy: always`: upstream publishes no
  major tag, so every redeploy takes the newest release.
- **`postgres:16-alpine`** stays on 16: a new Postgres major cannot read the
  existing data directory without a dump and restore.

## Usage

Complete Gitea's first-run setup at `GITEA_ROOT_URL`, create an access token,
then configure mirroring at `GITEA_MIRROR_URL`. In gitea-mirror, set the Gitea
URL to `http://gitea:3000` so it talks to Gitea over the internal network.

## Storage

| Volume | Holds |
| --- | --- |
| `db-data` | PostgreSQL data |
| `gitea-data` | Repositories, Gitea config and state |
| `gitea-mirror-data` | Mirror job database and generated secrets |
