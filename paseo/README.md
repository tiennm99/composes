# paseo

[Paseo](https://paseo.sh) — self-hosted daemon and web UI for running coding
agents. Built from a local `Dockerfile` that adds Claude Code and `gh` to the
[official image](https://paseo.sh/docs/docker), which ships neither.

## Setup

1. Set the three variables from `.env.example` in Coolify or Dokploy.
2. Point the domain at port `6767` and deploy.
3. Open the domain. At the pairing screen enter the host **with the port**:

   ```
   paseo.example.com:443
   ```

   Then the `PASEO_PASSWORD` value.
4. In a terminal inside Paseo, log in once: `claude` and `gh auth login`.

The port is required — the UI rejects a bare hostname. You must type the
address yourself: the daemon builds its auto-connect hint from the `Host`
header, browsers drop the default `:443`, and the UI discards a hint with no
port. It then shows its built-in `localhost:6767` placeholder, which in a
browser means your own machine.

Still stuck on `localhost:6767` after entering the address? Clear site data —
the old entry is cached in `localStorage`.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASEO_PASSWORD` | Web UI and API login. Generate with `openssl rand -base64 24`. |
| `PASEO_HOSTNAMES` | Domains allowed to reach the daemon, comma-separated. Your domain must be listed. |
| `PASEO_TRUSTED_PROXIES` | Set to `uniquelocal`, or the UI loads but never connects. |

`PASEO_TRUSTED_PROXIES` matches the *source IP* of the proxy, so hostnames are
rejected. By default the daemon believes `X-Forwarded-Proto` only from
loopback, but Coolify's Traefik reaches it from the Docker bridge network. It
therefore reads the request as plain HTTP, tells the UI to use `ws://` on an
`https://` page, and the browser blocks that as mixed content. `uniquelocal`
covers the private ranges Docker uses; an exact CIDR works too, but Coolify
assigns a fresh subnet per project.

## Networking

Listens on `6767`, published nowhere — the platform maps the domain to it, so
`localhost:6767` on the host refuses connections. See the
[root README](../README.md) for why.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `paseo-home` | `/home/paseo` | Daemon state, agent configs, credentials (`.claude`, `.codex`) |
| `paseo-workspace` | `/workspace` | Code the agents work on |

Claude Code and `gh` keep their config in `/home/paseo`, so both logins survive
a redeploy.

## Image

Claude Code comes from npm; `gh` from GitHub's signed apt repo, since Debian
does not package it. Add other agent providers to the `npm install` line:

```dockerfile
RUN npm install -g @anthropic-ai/claude-code @openai/codex opencode-ai
```

Notes for anyone tempted to change it:

- npm installs the same native binary as Anthropic's standalone installer.
  Don't swap in `curl | bash` — it writes to `$HOME/.local`, and `$HOME` is
  `/home/paseo`, a volume mount that hides anything baked in at build time.
- Claude Code can't auto-update (`paseo` can't write `/usr/local`), so it shows
  a notice at startup. Rebuild to update.
- The image stays root on purpose: the entrypoint chowns the volumes, then
  drops to the `paseo` user (uid 1000) with `gosu`.
