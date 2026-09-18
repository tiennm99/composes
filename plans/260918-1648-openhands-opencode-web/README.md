# Plan: openhands + opencode-web services

Status: accepted, ready to implement
Branch: `dev`
Research: [../reports/research-260918-1648-openhands-opencode-web.md](../reports/research-260918-1648-openhands-opencode-web.md)

## Outcome

Two new service directories, each deployable as a Coolify/Dokploy compose
resource on the ARM64 host, following the repo conventions in `CLAUDE.md`.

## Accepted decisions

| Decision | Choice | Source |
| --- | --- | --- |
| opencode toolchain | local `Dockerfile` on `ghcr.io/anomalyco/opencode`, apk layer for bash/git/curl/openssh-client | user |
| openhands workspace | no host workspace — `SANDBOX_VOLUMES` omitted, agent works inside its sandbox container only | user |
| image tags | track `latest` | user |
| agent-server tag | pinned to `1.26.0-python`; GHCR publishes no floating tag for that repo (verified) | evidence |
| opencode state | one named volume on `/root`, as `paseo` does with `$HOME` | evidence: state spread across `.config`, `.local/share`, `.local/state`, `.cache` |
| opencode credentials | `docker compose exec … auth login`, persisted on the `/root` volume; no provider env vars | evidence: `auth login` is interactive, `exec` gives a TTY |
| `xdg-utils` | not installed | `apk --simulate`: pulls X11, 31 MiB image |

## Non-goals

- Publishing ports, `restart:`, `container_name:` — the platform owns these.
- Provider API keys as compose variables.
- Reaching OpenHands sandbox-hosted previews from outside (`SANDBOX_CONTAINER_URL_PATTERN`).

## Phases

### 1. `openhands/`

`compose.yml`, `README.md`. No `Dockerfile`, no `.env.example` — nothing is
per-deployment once `SANDBOX_VOLUMES` is out.

- `image: ghcr.io/openhands/openhands:latest`
- `environment:` `AGENT_SERVER_IMAGE_REPOSITORY`, `AGENT_SERVER_IMAGE_TAG`
  (must-have group, repository first), `TZ`, `LOG_ALL_EVENTS`
- `extra_hosts: host.docker.internal:host-gateway`
- `volumes:` `openhands-state:/.openhands`, docker socket **read-write**
- README covers: rw socket is root-equivalent and why `:ro` cannot work, the
  `extra_hosts` requirement, `/.openhands` not `$HOME`, why no host workspace,
  why the agent-server tag is pinned while the app image is not, port 3000.

### 2. `opencode-web/`

`Dockerfile`, `compose.yml`, `.env.example`, `README.md`.

- `Dockerfile`: `FROM ghcr.io/anomalyco/opencode:latest`, one apk layer, `WORKDIR /workspace`.
- `command: ['web', '--hostname', '0.0.0.0', '--port', '4096']`
- `environment:` `OPENCODE_SERVER_PASSWORD`/`OPENCODE_SERVER_USERNAME` group,
  `TZ`, the four `GIT_*`
- `volumes:` `opencode-home:/root`, `opencode-workspace:/workspace`
- `.env.example` in compose order, generic values only.
- README covers: the vendor image ships only the binary, the unsecured-without-password
  warning, `auth login` over `exec`, the harmless `xdg-open` stack trace on start,
  `--cors` if the UI is cross-origin, port 4096.

### 3. Root `README.md`

Two rows in the services table, alphabetical.

## Acceptance criteria

- `docker compose config` parses in both directories.
- `opencode-web` image builds on arm64 and `git`, `bash` run inside it.
- No `ports:`, `restart:` or `container_name:` in either compose file.
- No rationale comments inside compose/Dockerfile; reasoning in the READMEs.
- `.env.example` carries no real hostname, identity or domain.

## Validation

`docker compose config`; `docker compose build` for opencode-web; `git diff`
review against `CLAUDE.md` conventions.
