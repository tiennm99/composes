# Research Report: openhands + opencode web as compose services

Conducted 2026-09-18. Target: Linux ARM64 host, deployed via Coolify/Dokploy.

## Executive Summary

Both ship usable upstream images with arm64 manifests, so no cross-build
needed. They differ sharply in how much the image gives you.

OpenHands is a complete product image: one container, port 3000, spawns
sibling *agent-server* containers through the host docker socket. It needs a
read-write socket, `host.docker.internal`, and a state directory. Nothing to
build.

opencode's official image is the opposite — Alpine with a single static
`opencode` binary and nothing else. Verified by running it: no `git`, `bash`,
`curl`, `ssh`, `node`, `python3`. A coding agent whose shell tool has no shell
and no git is close to inert, so a local `Dockerfile` layer is required, the
way `paseo/` already does it.

## Method

- Sources: openhands docs (local-setup, runtimes/docker), opencode docs
  (server, web), GHCR registry API, and direct `docker run` inspection.
- Date: 2026-09-18. Everything below verified against live registries or a
  running container, not recalled.

## Findings — OpenHands

Upstream `docker run` (docs.openhands.dev/usage/local-setup):

```bash
docker run -it --rm --pull=always \
  -e AGENT_SERVER_IMAGE_REPOSITORY=ghcr.io/openhands/agent-server \
  -e AGENT_SERVER_IMAGE_TAG=1.26.0-python \
  -e LOG_ALL_EVENTS=true \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.openhands:/.openhands \
  -p 3000:3000 \
  --add-host host.docker.internal:host-gateway \
  --name openhands-app \
    docker.openhands.dev/openhands/openhands:1.8
```

Registry facts (GHCR API, 2026-09-18):

| Image | arm64 | Note |
| --- | --- | --- |
| `ghcr.io/openhands/openhands:1.8` | yes | `docker.openhands.dev/...` is a mirror of this |
| `ghcr.io/openhands/openhands:latest` | yes | |
| `ghcr.io/openhands/agent-server:1.26.0-python` | yes | pulled by the app, not by compose |
| `ghcr.io/all-hands-ai/openhands` | yes | the old 0.x line, superseded |

Constraints that shape the compose file:

- **Socket must be read-write.** The app creates containers; connecting to a
  unix socket needs write permission, so `:ro` — what `code-server/` uses —
  breaks it. This is full host root-equivalent access.
- **`extra_hosts: host.docker.internal:host-gateway`** is mandatory. Sandbox
  containers publish on the host, and the app reaches them through that name,
  not over the compose network.
- **State lives at `/.openhands`** (repo root, not `$HOME`).
- **`SANDBOX_VOLUMES=host_path:/workspace:rw`** mounts code for the agent. The
  path is resolved by the *host* daemon for the sibling container, so a named
  volume or a path inside the app container does not work.
- Reverse-proxy knobs exist (`AGENT_SERVER_USE_HOST_NETWORK`,
  `SANDBOX_CONTAINER_URL_PATTERN`) but only matter for reaching sandbox-hosted
  previews from outside; the main UI does not need them.
- LLM credentials are set in the UI and persist in the state directory.

## Findings — opencode web

`opencode web` (opencode.ai/docs/web) starts the server *and* a browser UI.
`opencode serve` is the same server without the UI. Flags shared by both:
`--port` (default `0` = random), `--hostname` (default `127.0.0.1`), `--mdns`,
`--cors`. So a container needs `web --hostname 0.0.0.0 --port <fixed>`.

Auth: `OPENCODE_SERVER_PASSWORD` — *"If `OPENCODE_SERVER_PASSWORD` is not set,
the server will be unsecured."* `OPENCODE_SERVER_USERNAME` defaults to
`opencode`. Non-negotiable behind a public domain.

Official image `ghcr.io/anomalyco/opencode` (the repo moved from `sst/`;
`ghcr.io/sst/opencode` now denies anonymous pulls). Tags are plain versions,
`1.0.94`–`1.0.196`, plus `latest`. amd64 + arm64.

Inspected `latest` directly:

```
NAME="Alpine Linux"
git/bash/curl/ssh/node/python3/gh: all MISSING
Entrypoint: ["opencode"]   User: root   HOME=/root   WorkingDir: /
opencode --version -> 1.18.31
```

(Note the image tag series and `--version` disagree; the binary is what counts.)

Consequences:

- A local `Dockerfile` must add at minimum `git`, plus a shell, `curl`,
  `openssh-client`, and whatever toolchain the agent is expected to run.
- `ENTRYPOINT ["opencode"]` means compose passes only `command: [web, ...]`.
- Config and credentials land under `/root`: `~/.config/opencode` (config),
  `~/.local/share/opencode` (auth, storage). Both must persist.
- `opencode auth login` is interactive; in a container the practical path is
  provider API keys as environment variables.

## Comparison

| | openhands | opencode-web |
| --- | --- | --- |
| Build | none, upstream image | local `Dockerfile` required |
| Port | 3000 | chosen, e.g. 4096 |
| Auth | in-app, after first login | `OPENCODE_SERVER_PASSWORD` or open to the world |
| Docker socket | required, rw | not needed |
| Isolation | agent runs in a sibling container | agent runs in *this* container |
| Workspace | host path via `SANDBOX_VOLUMES` | ordinary named volume |

## Recommendations

1. `openhands/` — no build, pin `ghcr.io/openhands/openhands` and the
   `AGENT_SERVER_IMAGE_TAG`, named volume for `/.openhands`, rw socket,
   `extra_hosts`, `SANDBOX_VOLUMES` as a variable so the host path is a
   per-deployment value.
2. `opencode-web/` — `Dockerfile` on `ghcr.io/anomalyco/opencode`, apk layer
   for git/bash/curl/openssh, named volumes for `/root/.config/opencode`,
   `/root/.local/share/opencode` and `/workspace`, `command: [web, --hostname,
   0.0.0.0, --port, 4096]`, mandatory password.
3. Both get a README carrying the reasoning, and a root README row, per repo
   convention.

## Pitfalls

- `:ro` on the OpenHands docker socket — silently fatal.
- Omitting `extra_hosts` — UI loads, agent never connects.
- Expecting `SANDBOX_VOLUMES` to accept a named volume.
- Shipping opencode without `OPENCODE_SERVER_PASSWORD` — an open agent with
  shell access on a public domain.
- Assuming the vendor opencode image can run `git`.

## References

- https://docs.openhands.dev/usage/local-setup
- https://docs.openhands.dev/usage/runtimes/docker
- https://opencode.ai/docs/server/
- https://opencode.ai/docs/web/
- https://github.com/anomalyco/opencode

## Unresolved

- Which toolchains the opencode image should carry beyond git/bash/curl.
- Whether OpenHands should get a host workspace path at all, or run purely on
  sandbox-internal storage.
- Whether to pin versions or track `latest`, as `code-server/` does.
