# goclaw

[GoClaw](https://docs.goclaw.sh) is a multi-tenant AI agent gateway in Go: LLM
providers, messaging channels (Telegram, Discord, Slack, Zalo, Feishu,
WhatsApp), agent teams, and a knowledge vault, behind one binary with a
built-in web dashboard.

Two containers: `goclaw`, and `db` — pgvector, which holds tenants,
sessions, encrypted provider keys and the semantic memory.

## Setup

1. Generate the two secrets:

   ```sh
   openssl rand -hex 16   # GOCLAW_GATEWAY_TOKEN
   openssl rand -hex 32   # GOCLAW_ENCRYPTION_KEY
   ```

2. Map the domain to port `18790` and deploy. Migrations run on start.
3. Open the domain and use the setup wizard to add an LLM provider key.

Health check: `GET /health`, which the `goclaw` container also polls as its
compose healthcheck so Coolify can report it healthy. The first check waits 60
seconds, to leave time for migrations on start.

## Authentication

`GOCLAW_GATEWAY_TOKEN` is the bearer token for the API and the dashboard, and
the only thing between the domain and a gateway whose agents run tools. It
fails fast if unset rather than defaulting to blank: upstream's own compose
allows an empty token for loopback-only development, which behind a public
domain would publish the gateway.

`GOCLAW_ENCRYPTION_KEY` encrypts the provider API keys at rest in PostgreSQL
(AES-256-GCM). It is required for the same reason, and it must not change once
keys are stored — every one of them becomes unreadable.

Both are the two values upstream's `prepare-env.sh` generates; the script
itself is not used here.

## Upstream layout

Upstream splits its Docker setup into a base `docker-compose.yml` and
overlays (`docker-compose.postgres.yml`, `.upgrade.yml`, `.browser.yml`,
`.selfservice.yml` and more). Its `Makefile` (`make up`, with `WITH_*` flags)
and `prepare-compose.sh` (which writes `COMPOSE_FILE` into `.env` from
`compose.d/`) choose which ones to merge. `make up` merges the base and the
PostgreSQL overlay, then runs the one-shot `upgrade` service.

`compose.yml` here is that default merge, flattened into one file: Coolify
deploys a single compose file and has no step to run the scripts. Left out:
`build:`, `ports:`, `env_file:`, the `goclaw-net` network, the Bitrix24 debug
variables, and the `upgrade` service, whose job `GOCLAW_AUTO_UPGRADE` does on
start.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `GOCLAW_GATEWAY_TOKEN` | — | Bearer token for the API and dashboard |
| `GOCLAW_ENCRYPTION_KEY` | — | AES-256-GCM key for stored provider keys |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `goclaw` | Database credentials, read by both containers |
| `GOCLAW_AUTO_UPGRADE` | `true` | Apply schema migrations and data hooks on startup |
| `GOCLAW_OWNER_IDS` | empty | Comma-separated user IDs given the owner role |
| `GOCLAW_MINIMAX_API_KEY` | optional | MiniMax LLM provider key |
| `GOCLAW_TTS_MINIMAX_API_KEY` / `GOCLAW_TTS_MINIMAX_GROUP_ID` | optional | MiniMax text-to-speech credentials |
| `GOCLAW_TRACE_VERBOSE` | optional | Set to `1` to log full LLM request and response bodies |

`GOCLAW_AUTO_UPGRADE` defaults to `true`, the value upstream recommends for
Docker. The image entrypoint already runs `goclaw upgrade` before `serve`, but
it only logs a warning when that fails. With the variable set, `serve` applies
any pending migrations itself rather than stopping on a schema check.

`GOCLAW_OWNER_IDS` lists the user IDs that become owner when they log in with
the gateway token and that ID; any other user ID gets admin. GoClaw has no
passwords: an owner shares the gateway token, and a separate per-person login
is an API key from the dashboard, which tops out at admin. Use the same ID the
person has on their chat channel, so their chats and the dashboard belong to
one user. When set, it replaces `gateway.owner_ids` from `config.json`.

The MiniMax variables are the one case where a provider key comes from the
environment rather than the dashboard: GoClaw reads them directly for the
MiniMax provider and its text-to-speech.

`GOCLAW_HOST`, `GOCLAW_PORT`, `GOCLAW_CONFIG` and `GOCLAW_SKILLS_DIR` are set
in `compose.yml` rather than here — they are properties of this layout, not of
whoever deploys it. The two paths override image defaults that point outside
any volume (`/app/config.json`, `/app/skills`), which would drop the
configuration and every installed skill on redeploy.

Other provider API keys are not variables: they are entered in the dashboard
and stored encrypted in PostgreSQL.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `goclaw-data` | `/app/data` | `config.json`, skills, Claude CLI credentials, runtime packages |
| `goclaw-workspace` | `/app/workspace` and `/app/.goclaw` | Files the agents work on, and the `goclaw` user's `~/.goclaw` (global skills, CLI config) |
| `db-data` | `/var/lib/postgresql` | The database |

Mounting `goclaw-workspace` at both paths is what upstream's PostgreSQL
overlay does; without the second mount, `~/.goclaw` is lost on redeploy.

The same overlay also adds a `goclaw-skills` volume at
`/app/skills`; it is not here, because `GOCLAW_SKILLS_DIR` points at
`/app/data/skills` and the volume would mount empty over a path nothing reads.
Skills persist in `goclaw-data` instead.

`db-data` mounts `/var/lib/postgresql`, not `/var/lib/postgresql/data`.
PostgreSQL 18 images moved `PGDATA` down a level into a version directory, so
the parent is now the mount point.

The image's own user owns `/app` — `goclaw`, uid 1000, created with `/app` as
its home. `/app/.claude` is a symlink into `/app/data`, which is how CLI
credentials survive a recreate.

## Networking

Listens on `18790`.

`extra_hosts` maps `host.docker.internal` to the host gateway, so an agent can
reach a service running on the host itself.

## Image

`ghcr.io/nextlevelbuilder/goclaw:full`, the variant with every runtime and
skill dependency pre-installed — Python, Node, pandoc, poppler, the GitHub CLI.
The plain tag ships Python only and installs the rest on demand into
`/app/data/.runtime`, which means the first use of a skill waits on a package
install and a wiped data volume repeats it. Paying for the size once is the
better trade here.

The tag is moving and follows the newest stable full build, published for
amd64 and arm64. The variant tags are published as `full` and
`v<version>-full`; the `latest-full` that upstream's README lists does not
exist. Plain `latest` is not used either: upstream's dev branch pushes over
it, and those builds are amd64 only.

## Hardening

`cap_drop: ALL` with `SETUID`/`SETGID`/`CHOWN` added back, `no-new-privileges`,
a `noexec` tmpfs on `/tmp`, and memory, CPU and pid limits — all as upstream
ships them. The three capabilities are what the entrypoint needs to install
persisted packages as root and then drop to the `goclaw` user via `su-exec`.

This is a service whose whole purpose is running model-chosen tools, so the
limits are worth keeping.
