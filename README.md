# composes

My docker compose collection — one directory per service, each self-contained.
Tuned to my own setup rather than written as general-purpose templates.

Services are deployed through [Coolify](https://coolify.io) and
[Dokploy](https://dokploy.com), which own what a standalone compose file would
otherwise declare:

- **No published ports.** The platform attaches the container to its proxy
  network and maps a domain to the internal port. Publishing one would also
  expose it on the host.
- **No `restart:` policy.** The platform manages the container lifecycle.
- **No `container_name:`.** Compose derives it from the directory.

Services that do publish ports or set `restart:` say so in their own README.

## Layout

```
<service>/
  compose.yml     # the service definition
  README.md       # what it is, its variables, how it's wired
  .env.example    # required variables, committed
  .env            # real values, gitignored
```

Compose names the project after its directory, so `code-server/` comes up as
the `code-server` project with its own network and volumes.

## Usage

In Coolify or Dokploy, point a Docker Compose resource at the service directory
and set the environment variables from its `.env.example`.

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
| [code-server](code-server/README.md) | VS Code in the browser, as a remote dev box |
| [couchbase](couchbase/README.md) | Couchbase Server |
| [gitea-mirror-local](gitea-mirror-local/README.md) | Gitea + PostgreSQL + gitea-mirror, mirroring GitHub repos |
| [netdata](netdata/README.md) | Netdata monitoring agent |
| [ollama](ollama/README.md) | Ollama LLM server |
| [openvpn-as](openvpn-as/README.md) | OpenVPN Access Server |
| [paseo](paseo/README.md) | Paseo coding-agent daemon and web UI |
| [tastyigniter](tastyigniter/README.md) | TastyIgniter restaurant ordering platform |
| [traffmonetizer](traffmonetizer/README.md) | TraffMonetizer bandwidth-sharing client |

Licensed under Apache 2.0 — see [LICENSE](LICENSE).
