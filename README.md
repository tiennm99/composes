# composes

My docker compose collection — one directory per service, each self-contained.
Tuned to my own setup rather than written as general-purpose templates.

Services are deployed through [Coolify](https://coolify.io), with
[Dokploy](https://dokploy.com) supported as an optional extra. The platform
owns what a standalone compose file would otherwise declare:

- **No published ports.** The platform attaches the container to its proxy
  network and maps a domain to the internal port. Publishing one would also
  expose it on the host.
- **No `container_name:`.** Compose derives it from the directory.

Every container does set `restart: unless-stopped`. Coolify would inject the
same value on its own, but Dokploy leaves an omitted policy alone, which in its
default compose mode means the container stays down after a reboot.

Services that publish ports or set `container_name:` say so in their own
README.

## Layout

```
<service>/
  compose.yml     # the service definition
  README.md       # what it is, its variables, how it's wired
  .env.example    # required variables, committed
  .env            # real values, gitignored
```

Compose names the project after its directory, so `gitea/` comes up as
the `gitea` project with its own network and volumes.

Each service README covers only its own service. Shared conventions live here
and are not repeated or linked from a service, so editing one service never
touches another's directory — each is a separate Coolify app deploying on a
`<service>/**` watch path.

A service directory holds only what its deploy reads, so changing anything else
never redeploys it. Known issues, troubleshooting and research for a service
live in `docs/<service>/`, named after its directory; agent skills live in
`.claude/skills/`.

## Upstream sources

`sources/` holds checkouts of the upstream repositories behind these images,
cloned as `sources/<owner>/<repo>` when a service needs debugging against its
real code. Only the empty directory is tracked; its contents are gitignored.
The `debug-service` skill in `.claude/skills/` walks through the process.

## Usage

In Coolify or Dokploy, point a Docker Compose resource at the service directory
and set the environment variables from its `.env.example`. To move an existing
deployment and its data onto that resource, use the `migrate-service` skill in
`.claude/skills/`.

Locally:

```sh
cd <service>
cp .env.example .env    # then fill it in
docker compose up -d
docker compose logs -f
docker compose down
```

`.env` is picked up automatically because it sits next to `compose.yml`. Never
commit it — the root `.gitignore` covers `.env`/`*.env` and re-includes
`.env.example`.

## Services

Each links to its own README for variables, ports, and storage.

| Service | What it is |
| --- | --- |
| [alloy](alloy/README.md) | Grafana Alloy shipping host and Docker telemetry to Grafana Cloud |
| [code-server-linuxserver](code-server-linuxserver/README.md) | VS Code in the browser from the LinuxServer image, as a remote dev box |
| [couchbase](couchbase/README.md) | Couchbase Server |
| [diun](diun/README.md) | Image-update notifier, reading the Docker API through a read-only proxy |
| [gitea](gitea/README.md) | Gitea backed by PostgreSQL |
| [gitea-mirror](gitea-mirror/README.md) | gitea-mirror, mirroring GitHub repos into Gitea |
| [goclaw](goclaw/README.md) | Multi-tenant AI agent gateway, with pgvector PostgreSQL |
| [hermes](hermes/README.md) | Hermes Agent with its built-in web dashboard |
| [litellm](litellm/README.md) | LiteLLM proxy in front of many LLM providers, with PostgreSQL and Redis |
| [open-webui](open-webui/README.md) | Open WebUI chat interface for OpenAI-compatible and Ollama providers |
| [openclaw](openclaw/README.md) | OpenClaw AI agent gateway, with built-in browser automation |
| [owncloud](owncloud/README.md) | ownCloud file sync and share, with MariaDB and Redis |
| [paseo](paseo/README.md) | Paseo coding-agent daemon and web UI |
| [traffmonetizer](traffmonetizer/README.md) | TraffMonetizer bandwidth-sharing client |
| [webtop](webtop/README.md) | Ubuntu XFCE desktop in the browser |

Licensed under Apache 2.0 — see [LICENSE](LICENSE).
