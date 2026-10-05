# hermes

[Hermes Agent](https://github.com/NousResearch/hermes-agent), an autonomous AI
agent with persistent memory and scheduling, behind
[Hermes WebUI](https://github.com/nesquena/hermes-webui), a self-hosted web
chat for it.

Two containers: `hermes-agent` runs the agent gateway, and `hermes-webui`
serves the chat on port `8787`.

## Setup

1. Set `HERMES_WEBUI_PASSWORD` and `OPENROUTER_API_KEY`.
2. Map the domain to the `hermes-webui` container on port `8787` and deploy.
3. Open the domain and log in with `HERMES_WEBUI_PASSWORD`.

Health check: `GET /health` on the web UI, also its compose healthcheck.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `HERMES_WEBUI_PASSWORD` | — | Web UI login |
| `OPENROUTER_API_KEY` | empty | Model provider |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY` | optional | Other model providers |

`HERMES_WEBUI_PASSWORD` is required: without it the chat, and the agent
behind it, are open to anyone who reaches the domain.

The uid/gid pairs are pinned to `1000` in `compose.yml`. Both containers write
the shared `hermes-home` volume, so both must run as the same user.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `hermes-home` | `/home/hermes/.hermes` (agent), `/home/hermeswebui/.hermes` (web UI) | Agent config, memory, skills and sessions; web UI state in `webui/` |
| `hermes-agent-src` | `/opt/hermes` (agent), `.hermes/hermes-agent`, read-only (web UI) | The agent's source code, which the web UI imports |
| `hermes-workspace` | `/workspace` (web UI) | Files the agent works on |

### Updating the agent

`hermes-agent-src` is filled from the agent image only when the volume is
first created. A newer `latest` image therefore keeps running the old source
until the volume is removed, which upstream documents as the upgrade step:
stop the app, delete the `hermes-agent-src` volume, and deploy again. Nothing
else lives in that volume.

## Images

Both images use `latest`. Upstream recommends moving the two together, since
the web UI imports the agent's source and is built against matching versions.
