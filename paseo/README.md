# paseo

[Paseo](https://paseo.sh) — a self-hosted daemon and web UI for running coding
agents, from the [official image](https://paseo.sh/docs/docker).

Built from a local `Dockerfile` rather than the upstream image directly: the
official image ships no provider CLIs, so this one layers Claude Code on top
via `npm install -g @anthropic-ai/claude-code`. Add other providers
(`@openai/codex`, `opencode-ai`) to that same line if you need them.

npm installs the same native binary as Anthropic's standalone installer, so
there is nothing to gain by switching. The `curl | bash` installer is in fact
the wrong choice here — it writes to `$HOME/.local`, and `$HOME` is
`/home/paseo`, a volume mount that hides anything baked in at build time.

Claude Code cannot auto-update, since `paseo` can't write `/usr/local`; expect
a one-time notice at startup. Rebuild the image to pick up a new version.

The image intentionally keeps running as root — its entrypoint chowns the
mounted volumes and then drops to the unprivileged `paseo` user with `gosu`.

Coolify and Dokploy build the image themselves from the compose `build:`
stanza; there is nothing to push.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASEO_PASSWORD` | Auth for the daemon API and WebSocket |
| `PASEO_HOSTNAMES` | Comma-separated DNS names allowed to reach the daemon, e.g. `paseo.example.com,.lan`. IPs and localhost always pass. |

Generate a password with `openssl rand -base64 24`. The proxied domain must
appear in `PASEO_HOSTNAMES` or requests are rejected.

## Networking

Listens on `6767`. No ports are published — point the domain at that port in
Coolify or Dokploy. See the [root README](../README.md) for why.

## Storage

Two named volumes:

| Volume | Mount | Holds |
| --- | --- | --- |
| `paseo-home` | `/home/paseo` | Daemon state, agent configs, credentials (`.codex`, `.claude`) |
| `paseo-workspace` | `/workspace` | Code the agents work on |

Claude Code's own config lives under `/home/paseo/.claude`, so it persists in
`paseo-home` — credentials survive a redeploy.

The daemon runs as uid/gid `1000:1000`; anything bind-mounted in its place must
be writable by that user.
