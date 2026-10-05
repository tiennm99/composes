# openclaw

[OpenClaw](https://docs.openclaw.ai): a personal AI agent gateway with a web
Control UI, chat-channel bots and browser automation. Runs the project's
official image, in its `-browser` variant with Chromium built in.

Laid out after upstream's [Docker guide](https://docs.openclaw.ai/install/docker)
and its `docker-compose.yml`: one gateway container with the same command,
path variables, three volumes, healthcheck, `init`, dropped capabilities and
`host.docker.internal` mapping, serving the gateway and Control UI on port
`18789`. Upstream's `openclaw-cli` companion service is left out; the CLI runs
inside the gateway container with `docker exec`.

## Setup

1. Set `OPENCLAW_GATEWAY_TOKEN`, `OPENCLAW_PUBLIC_ORIGIN` and
   `OPENROUTER_API_KEY`.
2. Map the domain to port `18789` and deploy.
3. Open the domain and connect with the gateway token. Each new browser is
   then approved once from inside the container:
   `node openclaw.mjs devices approve`.
4. Pick a default model in the Control UI. The image's default is an OpenAI
   model, which needs `OPENAI_API_KEY`.

Health check: `docker-healthcheck.js` from the image, which calls `/healthz`,
on upstream's compose timings.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `OPENCLAW_GATEWAY_TOKEN` | — | Control UI login and API/WebSocket key |
| `OPENCLAW_PUBLIC_ORIGIN` | — | Public origin, e.g. `https://openclaw.example.com` |
| `OPENCLAW_TRUSTED_PROXIES` | `10.0.0.0/16` | Range the reverse proxy connects from |
| `OPENROUTER_API_KEY` | empty | Model provider |
| `TZ` | `Asia/Ho_Chi_Minh` | Timezone for logs and schedules |
| Other provider keys, `AWS_*` | optional | Additional model providers |
| `TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`, `SLACK_*` | optional | Chat channels |

`OPENCLAW_GATEWAY_TOKEN` is required: the gateway binds to all interfaces, and
the token is what keeps the Control UI and API closed. Provider and channel
keys are read from the environment, so the provider set is changed by
uncommenting lines.

`NODE_COMPILE_CACHE` and `OPENCLAW_NO_RESPAWN=1` are the values `doctor`
recommends on ARM and small Linux hosts: a compile cache that speeds up
repeated CLI runs, and gateway restarts that stay inside the process instead
of handing off to a supervisor, since Docker's restart policy already
supervises the container.

`OPENCLAW_TRUSTED_PROXIES` must cover the address Coolify's Traefik connects
from. Traefik joins each app's network with an address from the Docker
address pool, which on this host is `10.0.0.0/16` in `/24` slices; the gateway
answers every proxied request from an untrusted address with 403
`proxy_attribution_required`.

## Config

The rest of OpenClaw's settings live in `openclaw.json` on the state volume
and are edited in the Control UI or with `node openclaw.mjs config set`.

Upstream's guide finishes setup with one-off commands run before the gateway
first starts: `onboard`, then `config set` for `gateway.mode` and
`gateway.bind`. Coolify has no step that runs a command against an app's
volume before it starts, so the `Dockerfile` does the equivalent: it copies
`openclaw.json` into the image's state directory, and Docker seeds an empty
named volume from it on first start. The file holds those two settings, the
port, and the two reverse-proxy settings from upstream's gateway reference,
`publicOrigin` and `trustedProxies`, as `${VAR}` references that OpenClaw
resolves from the environment at load. The image's start-up `doctor --fix`
keeps the references when it rewrites the file. Without `gateway.mode` a
fresh volume crash-loops.

The seed applies only to a fresh volume. Editing `openclaw.json` in the
repository later changes nothing for an existing deployment; change the live
config instead.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `openclaw-state` | `/home/node/.openclaw` | `openclaw.json`, sessions, credentials, agent state |
| `openclaw-workspace` | `/home/node/.openclaw/workspace` | Files the agent works on |
| `openclaw-secrets` | `/home/node/.config/openclaw` | Auth-profile secrets |

The three mounts are upstream's own. `/home/node` as a whole is not mounted:
the bundled Chromium lives in `/home/node/.cache`, and a volume there would
freeze it at the first image's version. The image runs as the non-root `node`
user.

## Image

`ghcr.io/openclaw/openclaw:latest-browser` is the latest stable release with
Playwright Chromium built in, published by the project's release automation.
Upstream publishes no major tag.

On ARM64, release 2026.9.8 cannot find its bundled Chromium ("No supported
browser found"); the fix is merged upstream but not yet released. Everything
except browser automation works meanwhile, and the browser starts working on
the first pull after a release that contains the fix, with no change here.
