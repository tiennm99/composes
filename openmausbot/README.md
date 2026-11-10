# openmausbot

[OpenMausBot](https://github.com/milind-soni/OpenMausBot): a self-hosted team
of AI bots (Claude Code, Codex and others) with their own browser, reached from
the web, desktop and phone apps. Built from the official
`ghcr.io/milind-soni/openmausbot` image.

Reached only over Tailscale: no domain, no exposed port. A `tunnel` container
from the official `tailscale/tailscale` image joins the tailnet as its own
machine and runs Tailscale Serve in the server's network namespace. The server
listens only on `127.0.0.1` (`8799` for the app, `8800` for webhooks), and
Serve forwards `https://<TS_HOSTNAME>.<TAILNET_DOMAIN>` to it, as upstream's
own `serve --tailscale` does.

## Setup

1. In the Tailscale admin console, turn on MagicDNS and HTTPS certificates
   (DNS page), and note the tailnet DNS name for `TAILNET_DOMAIN`.
2. Create an auth key (Settings > Keys) for `TS_AUTHKEY`.
3. Deploy with no domain assigned.
4. Get a pairing code from a shell in the `openmausbot` container:
   `openmausbot pair`. From a device on the tailnet, open the printed link, or
   paste it into the desktop app under Connect to a server.
5. Sign the engines in from that shell (`claude`, `codex`) or from the app.

The first HTTPS request after a deploy can take a few seconds while Tailscale
fetches the certificate.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `ENGINES` | `@anthropic-ai/claude-code @openai/codex` | Engine CLIs installed into the image at build time, as npm packages |
| `TS_HOSTNAME` | `openmausbot` | Machine name on the tailnet |
| `TAILNET_DOMAIN` | — | Tailnet DNS name, such as `tailnet-name.ts.net` |
| `OMB_SIGNIN_EMAILS` / `OMB_SIGNIN_MEMBER_EMAILS` | optional | Who may sign in with an emailed code: admins / members (chat and approvals only) |
| `OMB_SIGNIN_SMTP_URL` / `OMB_SIGNIN_SMTP_FROM` | optional | Own SMTP server for those codes, instead of OpenMausBot's account service |
| `OMB_SERVER_NAME` | optional | Name the apps show; without it they show the container id |
| `TS_AUTHKEY` | — | Tailscale auth key for the first login |

`TS_HOSTNAME` and `TAILNET_DOMAIN` build the server's `OMB_PUBLIC_URL` and
`OMB_WEBHOOK_PUBLIC_URL`, which pairing links and webhook URLs use. The server
does not fall back from one to the other, so both are set.

`TS_AUTH_ONCE` makes the key a one-time login: the machine's identity then
lives in `tunnel-state`, so an expired or one-off key does no harm after the
first start. A new key is needed only when that volume is lost. If
`TS_HOSTNAME` is taken on the tailnet, Tailscale adds a suffix and the
pairing links no longer match; free the name or change `TS_HOSTNAME`.

## Access

Only devices on the tailnet reach the server, and pairing is still the
login. Serve sets `X-Forwarded-For` to the tailnet client's address and
`X-Forwarded-Proto: https`, so the server treats each request as remote,
checks it against the `https` origin, sets `Secure` cookies, and keys its
pairing lockout on the right address. Commands run inside the container count
as the owner, which is how `openmausbot pair` issues codes.

`/hooks/*` goes to the webhook receiver with no login; each hook carries its
own secret. Only callers on the tailnet can reach it.

## Tunnel

The `tunnel` image is `tailscale/tailscale` with `serve.json` baked in,
built from the `tunnel` stage of the one `Dockerfile`, so the service needs no
bind mount. Tailscale fills in `${TS_CERT_DOMAIN}` in that file with the
machine's name. Tailscale runs in userspace networking, its image default, so
it needs no `/dev/net/tun` or extra capabilities: Serve only takes incoming
connections.

## Image

The published server image installs no engine CLIs, so the `server` stage
adds them with `npm install -g`, as upstream's local Docker build does.
Upstream's local build also installs xAI's Grok Build CLI from its own
installer; it is left out here. Rebuild the image to update the engines.

`latest` follows upstream's `main` branch, not only releases (those are
`v*` tags); upstream publishes no major tag. Images are built for amd64 and
arm64; on arm64 the bots' browser is Debian's Chromium.

`init: true` and `shm_size: 512m` come from upstream: the init reaps the
browser processes whose parents exit, and Chrome needs the shared memory.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `openmausbot-data` | `/data` | The `maus` user's home: server state in `.openmausbot`, engine logins, bots' files |
| `tunnel-state` | `/var/lib/tailscale` | The Tailscale machine's identity and certificate |
