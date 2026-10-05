# openclaw

[OpenClaw](https://docs.openclaw.ai): a personal AI agent gateway with a web
UI, chat-channel bots and browser automation. Runs Coolify's
`coollabsio/openclaw` image, which wraps OpenClaw with nginx basic auth and
env-driven configuration.

Two containers: `openclaw`, and `browser`, a Chromium the agent drives over
the Chrome DevTools Protocol.

## Setup

1. Set `AUTH_PASSWORD`, `OPENCLAW_GATEWAY_TOKEN` and `OPENROUTER_API_KEY`.
2. Map the domain to port `8080` and deploy.
3. Open the domain and log in with `AUTH_USERNAME` / `AUTH_PASSWORD`.

Health check: `GET /healthz`, also the compose healthcheck.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `AUTH_USERNAME` / `AUTH_PASSWORD` | `admin` / — | Basic-auth login in front of the web UI |
| `OPENCLAW_GATEWAY_TOKEN` | — | Token the web UI and clients use to reach the gateway |
| `OPENROUTER_API_KEY` | empty | Model provider |
| `OPENCLAW_PRIMARY_MODEL` | optional | Default model |
| Other provider keys, `AWS_*`, `OLLAMA_BASE_URL` | optional | Additional model providers |
| `TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`, `SLACK_*`, `WHATSAPP_ENABLED` | optional | Chat channels |
| `OPENCLAW_ALLOWED_ORIGINS` | optional | Origins allowed to open the control UI |
| `BROWSER_*`, `HOOKS_*`, `OPENCLAW_GATEWAY_BIND` | optional | Tuning, defaults shown in `compose.yml` |
| `OPENCLAW_DOCKER_APT_PACKAGES` | optional | Extra apt packages installed at start |

`AUTH_PASSWORD` is required: without it nginx serves the UI with no login.
The entrypoint itself refuses to start without `OPENCLAW_GATEWAY_TOKEN` or
without at least one provider key.

OpenRouter stays active as the one provider every deployment needs; any
other provider is enabled by uncommenting its line. Each provider key is read
from the environment on every start, never stored in the config.

`PORT`, the gateway port, the state and workspace directories and
`BROWSER_CDP_URL` are fixed in `compose.yml`, as properties of this layout.

`OPENCLAW_CONFIG_JSON` sets `gateway.trustedProxies` to `127.0.0.1`. The
image's own nginx sits in front of the gateway on loopback, and current
OpenClaw (tested on 2026.9.8) rejects every proxied request with 403
`proxy_attribution_required` unless that proxy is trusted. The wrapper merges
this JSON into `openclaw.json` on every start.

The wrapper adds the deployment's domain to the control UI's allowed origins
from the `COOLIFY_URL` and `COOLIFY_FQDN` Coolify injects.
`OPENCLAW_ALLOWED_ORIGINS` is for any other origin, and for a deployment
Coolify does not inject that into.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `openclaw-data` | `/data` | Config and sessions in `.openclaw`, the agent workspace in `workspace` |
| `browser-data` | `/config` | Chromium profile: cookies and logins of sites the agent uses |

## Images

Both images use `latest`. `coollabsio/openclaw` publishes no major tag, only
dated releases, so `latest` is the moving one.
