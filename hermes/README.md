# hermes

[Hermes Agent](https://github.com/NousResearch/hermes-agent): an autonomous AI
agent with persistent memory, scheduling and chat-platform gateways, from Nous
Research's official image, with its built-in web dashboard.

Laid out after upstream's
[Docker guide](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/docker.md):
one container, one data volume at `/opt/data`, `gateway run` as the command,
and `HERMES_DASHBOARD=1` so the image's s6 supervisor also runs the dashboard
on port `9119`.

## Setup

1. Set `HERMES_DASHBOARD_PUBLIC_URL`, `HERMES_DASHBOARD_PASSWORD` and
   `HERMES_DASHBOARD_SECRET`.
2. Map the domain to port `9119` and deploy.
3. Open the domain, log in with `HERMES_DASHBOARD_USERNAME` /
   `HERMES_DASHBOARD_PASSWORD`, and add a model provider under Config.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `HERMES_DASHBOARD_PUBLIC_URL` | — | Full public URL, e.g. `https://hermes.example.com` |
| `HERMES_DASHBOARD_USERNAME` / `HERMES_DASHBOARD_PASSWORD` | `hermes` / — | Dashboard login |
| `HERMES_DASHBOARD_SECRET` | — | Signs dashboard sessions |
| `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY` | optional | Provider keys passed from the environment |

The dashboard refuses to start on a non-loopback bind without an auth
provider, so the password is required. The username/password provider is the
one that needs no outside identity service; upstream describes it as meant
for trusted networks and recommends OAuth (Nous Portal) or self-hosted OIDC
for a public domain.

`HERMES_DASHBOARD_PUBLIC_URL` adds the domain to the dashboard's Host and
WebSocket Origin guard, which rejects requests for any other host.
`HERMES_DASHBOARD_SECRET` keeps sessions valid across restarts; without it
each restart signs with a new random key. It must decode to at least 16
bytes (base64, hex, or raw text), or the password provider does not load and
the dashboard refuses to start; `openssl rand -hex 32` is long enough.

Hermes loads `/opt/data/.env` over the process environment, so a key set in
both takes the file's value. Provider keys are commented out because upstream
keeps them in that file, written from the dashboard.

## Chat platforms

Telegram and the other gateway platforms are configured in the dashboard
under Messaging, which writes `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`,
`TELEGRAM_GROUP_ALLOWED_CHATS` and their equivalents to `/opt/data/.env` and
restarts the gateway. They are not passed from Coolify, so that file is the
one place they are set.

The Coolify environment cannot be the source for them. The gateway runs with
`multiplex_profiles` on by default, and in that mode its allow-lists read
only the profile's `.env`, never the container environment: with
`TELEGRAM_ALLOWED_USERS` set only in Coolify, the bot connects but blocks
every user. Turning multiplexing off (`GATEWAY_MULTIPLEX_PROFILES=false`)
would make the environment count again, but the file still wins for any key
it holds, and the dashboard's Messaging setup writes those keys there, so a
Coolify value would be silently overridden the first time the dashboard is
used.

To edit a value by hand, change it in `/opt/data/.env` from a shell in the
container, as the `hermes` user, then run
`/opt/hermes/.venv/bin/hermes gateway restart`.

In groups the bot answers only when tagged: `telegram.require_mention` is
`true` in `/opt/data/config.yaml`, set with
`/opt/hermes/.venv/bin/hermes config set telegram.require_mention true`
followed by a gateway restart. A group message then needs an `@botusername`
mention, a `/command@botusername`, or a reply to one of the bot's messages;
DMs are not gated. Upstream defaults it to `false`, answering every group
message the bot can see. It lives in the volume for the same reason as the
allow-lists: the gateway reads it from the profile, not the container
environment.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `hermes-data` | `/opt/data` | `HERMES_HOME`: config, `.env`, sessions, memory, skills, logs, and the agent's working files |

`/opt/data` is the image's own home for all mutable state: it is the `hermes`
user's home directory, the image declares it a volume, and the dashboard's
start script uses it directly. The agent's file tools may only write under
it. The `hermes` user keeps the image's default uid, `10000`, and the image fixes
the volume's ownership for that user at start.

## Resources

The 4 GB memory and 2 CPU limits are upstream's own compose example.

## Image

`nousresearch/hermes-agent:latest` moves only on stable releases, roughly
weekly; upstream publishes no major tag. The agent's code lives in the image,
not a volume, so a new release takes effect on the next pull and recreate.
