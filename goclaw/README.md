# goclaw

[GoClaw](https://docs.goclaw.sh) is a multi-tenant AI agent gateway in Go: LLM
providers, messaging channels (Telegram, Discord, Slack, Zalo, Feishu,
WhatsApp), agent teams, and a knowledge vault, behind one binary with a
built-in web dashboard.

Two containers: `goclaw`, and `postgres` — pgvector, which holds tenants,
sessions, encrypted provider keys and the semantic memory.

## Setup

1. Generate the two secrets and set them, with the rest of `.env.example`, in
   Coolify or Dokploy:

   ```sh
   openssl rand -hex 16   # GOCLAW_GATEWAY_TOKEN
   openssl rand -hex 32   # GOCLAW_ENCRYPTION_KEY
   ```

2. Point the domain at port `18790` and deploy. Migrations run on start.
3. Open the domain and use the setup wizard to add an LLM provider key.

Health check: `GET /health`.

## Authentication

`GOCLAW_GATEWAY_TOKEN` is the bearer token for the API and the dashboard, and
the only thing between the domain and a gateway whose agents run tools. It
fails fast if unset rather than defaulting to blank: upstream's own compose
allows an empty token for loopback-only development, which behind a public
domain would publish the gateway.

`GOCLAW_ENCRYPTION_KEY` encrypts the provider API keys at rest in PostgreSQL
(AES-256-GCM). It is required for the same reason, and it must not change once
keys are stored — every one of them becomes unreadable.

Both are 1:1 with what `prepare-env.sh` generates upstream; that script is not
used here because the platform owns the environment.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `GOCLAW_GATEWAY_TOKEN` | — | Bearer token for the API and dashboard |
| `GOCLAW_ENCRYPTION_KEY` | — | AES-256-GCM key for stored provider keys |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `goclaw` | Database credentials, read by both containers |
| `GOCLAW_TRACE_VERBOSE` | `0` | Log full LLM request and response bodies |

`GOCLAW_HOST`, `GOCLAW_PORT`, `GOCLAW_CONFIG` and `GOCLAW_SKILLS_DIR` are set
in `compose.yml` rather than here — they are properties of this layout, not of
whoever deploys it. The two paths override image defaults that point outside
any volume (`/app/config.json`, `/app/skills`), which would drop the
configuration and every installed skill on redeploy.

Provider API keys are not variables: they are entered in the dashboard and
stored encrypted in PostgreSQL.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `goclaw-data` | `/app/data` | `config.json`, skills, Claude CLI credentials, runtime packages |
| `goclaw-workspace` | `/app/workspace` | Files the agents work on |
| `postgres-data` | `/var/lib/postgresql` | The database |

Upstream's PostgreSQL overlay adds a third `goclaw-skills` volume at
`/app/skills`; it is not here, because `GOCLAW_SKILLS_DIR` points at
`/app/data/skills` and the volume would mount empty over a path nothing reads.
Skills persist in `goclaw-data` instead.

`postgres-data` mounts `/var/lib/postgresql`, not `/var/lib/postgresql/data`.
PostgreSQL 18 images moved `PGDATA` down a level into a version directory, so
the parent is now the mount point.

The image's own user owns `/app` — `goclaw`, uid 1000, created with `/app` as
its home. `/app/.claude` is a symlink into `/app/data`, which is how CLI
credentials survive a recreate.

## Networking

Listens on `18790`, published nowhere — the platform maps the domain to it. See
the [root README](../README.md) for why.

`extra_hosts` maps `host.docker.internal` to the host gateway, so an agent can
reach a service running on the host itself.

## Image

`ghcr.io/nextlevelbuilder/goclaw:full`, the variant with every runtime and
skill dependency pre-installed — Python, Node, pandoc, poppler, the GitHub CLI.
The plain tag ships Python only and installs the rest on demand into
`/app/data/.runtime`, which means the first use of a skill waits on a package
install and a wiped data volume repeats it. Paying for the size once is the
better trade here.

The tag is moving, tracking the newest full build. The variant tags are only
published as `full` and `<major>.<minor>-full` — there is no `<major>-full` —
so `full` is the moving tag to follow.

## Hardening

`cap_drop: ALL` with `SETUID`/`SETGID`/`CHOWN` added back, `no-new-privileges`,
a `noexec` tmpfs on `/tmp`, and memory, CPU and pid limits — all as upstream
ships them. The three capabilities are what the entrypoint needs to install
persisted packages as root and then drop to the `goclaw` user via `su-exec`.

This is a service whose whole purpose is running model-chosen tools, so the
limits are worth keeping even though nothing else here sets them.
