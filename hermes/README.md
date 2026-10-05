# hermes

[Hermes Agent](https://github.com/NousResearch/hermes-agent): an autonomous AI
agent with persistent memory, scheduling and chat-platform gateways, from Nous
Research's official image, with its built-in web dashboard.

One container. `gateway run` starts the agent gateway, and the image's s6
supervisor also starts the dashboard on port `9119`: chat (the Hermes
terminal UI in the browser), sessions, config, cron, skills and logs.

## Setup

1. Set `HERMES_DASHBOARD_PUBLIC_URL`, `HERMES_DASHBOARD_PASSWORD`,
   `HERMES_DASHBOARD_SECRET` and `OPENROUTER_API_KEY`.
2. Map the domain to port `9119` and deploy.
3. Open the domain and log in with `HERMES_DASHBOARD_USERNAME` /
   `HERMES_DASHBOARD_PASSWORD`.

Health check: `GET /api/status`, also the compose healthcheck.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `HERMES_DASHBOARD_PUBLIC_URL` | — | Full public URL, e.g. `https://hermes.example.com` |
| `HERMES_DASHBOARD_USERNAME` / `HERMES_DASHBOARD_PASSWORD` | `hermes` / — | Dashboard login |
| `HERMES_DASHBOARD_SECRET` | — | Signs dashboard sessions |
| `OPENROUTER_API_KEY` | empty | Model provider |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY` | optional | Other model providers |

`HERMES_DASHBOARD=1` turns the dashboard on. Bound to `0.0.0.0`, it refuses to
start without an auth provider, so the password is required. The image's
username/password provider is the one that needs no outside identity service;
upstream describes it as meant for trusted networks and recommends OAuth (Nous
Portal) or self-hosted OIDC for a public domain.

`HERMES_DASHBOARD_PUBLIC_URL` adds the domain to the dashboard's Host and
WebSocket Origin guard, which rejects requests for any other host.

`HERMES_DASHBOARD_SECRET` keeps sessions valid across restarts; without it
each restart signs with a new random key and logs everyone out.

The uid/gid are pinned to `1000` in `compose.yml`; the `Dockerfile` depends on
that (see Storage).

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `hermes-data` | `/opt/data` | `HERMES_HOME`: config, `.env`, sessions, memory, skills, logs |
| `hermes-workspace` | `/workspace` | Files the agent works on |

The image hard-blocks the agent's file tools from writing outside
`HERMES_WRITE_SAFE_ROOT`, which it sets to `/opt/data` alone, so
`compose.yml` adds `/workspace` to it. `TERMINAL_CWD` starts gateway and cron
terminal sessions in `/workspace`. Upstream marks that variable deprecated in
favour of `terminal.cwd` in `config.yaml`; it is used here so the setting stays
in the compose file rather than on the volume.

The `Dockerfile` exists only to make `/workspace` writable. The image does not
ship that directory and its init chowns only `/opt/data`, so a named volume on
`/workspace` would come up `root:root`. Creating the directory in the image,
owned by `1000:1000`, fixes that: Docker seeds an empty named volume from the
image directory, ownership included.

## Image

`nousresearch/hermes-agent:latest` moves only on stable releases, roughly
weekly; upstream publishes no major tag. The agent's code lives in the image,
not a volume, so a new release takes effect on the next pull and recreate. The
first start after an upgrade migrates `config.yaml`, keeping a timestamped
backup.
