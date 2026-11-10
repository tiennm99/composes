# openmausbot

[OpenMausBot](https://github.com/milind-soni/OpenMausBot): a self-hosted team
of AI bots (Claude Code, Codex and others) with their own browser, reached from
the web, desktop and phone apps. Built from the official
`ghcr.io/milind-soni/openmausbot` image.

Laid out after upstream's `deploy/docker-compose.yml`: the server plus a Caddy
container in the server's network namespace. The server listens only on
`127.0.0.1` (`8799` for the app, `8800` for webhooks), so Caddy is what the
platform proxy reaches, on port `80`.

## Setup

1. Set `OMB_PUBLIC_URL` to the domain's full URL.
2. Map the domain to port `80` of the `openmausbot` service and deploy.
3. Get a pairing code from a shell in the `openmausbot` container:
   `openmausbot pair`. Open the printed link, or paste it into the desktop app
   under Connect to a server.
4. Sign the engines in from that shell (`claude`, `codex`) or from the app.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `ENGINES` | `@anthropic-ai/claude-code @openai/codex` | Engine CLIs installed into the image at build time, as npm packages |
| `OMB_PUBLIC_URL` | — | Full public URL; pairing links and webhook URLs point here |
| `OMB_SIGNIN_EMAILS` / `OMB_SIGNIN_MEMBER_EMAILS` | optional | Who may sign in with an emailed code: admins / members (chat and approvals only) |
| `OMB_SIGNIN_SMTP_URL` / `OMB_SIGNIN_SMTP_FROM` | optional | Own SMTP server for those codes, instead of OpenMausBot's account service |
| `OMB_SERVER_NAME` | optional | Name the apps show; without it they show the container id |

`OMB_PUBLIC_URL` feeds both `OMB_PUBLIC_URL` and `OMB_WEBHOOK_PUBLIC_URL`: the
server does not fall back from one to the other, and Caddy serves both on the
one domain.

## Access

Pairing is the login. A remote browser without a session gets the pair page
and nothing else; the server refuses every other request that arrives through
a proxy. Commands run inside the container count as the owner, which is how
`openmausbot pair` issues codes. Caddy adds no password of its own, as
upstream's edge does not.

`/hooks/*` goes straight to the webhook receiver with no login, because
third-party services post there; each hook carries its own secret.

## Proxy

The `proxy` image is `caddy:2` with the `Caddyfile` baked in, built from the
`proxy` stage of the one `Dockerfile`, so the service needs no bind mount.

Caddy trusts private ranges as proxies, so the platform proxy's
`X-Forwarded-Proto: https` reaches the server. The server compares it with the
browser's `Origin` and sets `Secure` cookies from it; with Caddy's own `http`
instead, every same-origin check fails.

Caddy sends one `X-Forwarded-For` hop, the client address, and the server
reads only the last hop for its pairing lockout and logs. Caddy takes that
address from `Cf-Connecting-IP` when Cloudflare is in front, else from
`X-Forwarded-For`. Without this, every client would share the platform proxy's
address and one bad guess would lock everyone out.

## Image

The published image installs no engine CLIs, so the `server` stage adds them
with `npm install -g`, as upstream's local Docker build does. Upstream's local
build also installs xAI's Grok Build CLI from its own installer; it is left
out here. Rebuild the image to update the engines.

`latest` follows upstream's `main` branch, not only releases (those are
`v*` tags); upstream publishes no major tag. Images are built for amd64 and
arm64; on arm64 the bots' browser is Debian's Chromium.

`init: true` and `shm_size: 512m` come from upstream: the init reaps the
browser processes whose parents exit, and Chrome needs the shared memory.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `openmausbot-data` | `/data` | The `maus` user's home: server state in `.openmausbot`, engine logins, bots' files |
