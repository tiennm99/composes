# paseo

[Paseo](https://paseo.sh) — self-hosted daemon and web UI for running coding
agents. Built from a local `Dockerfile` that adds Claude Code, `gh`, Go,
Python, and shell tooling to the [official image](https://paseo.sh/docs/docker),
which ships none of it.

## Setup

1. Set the variables from `.env.example` in Coolify or Dokploy.
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
| `PASEO_PASSWORD` | Web UI and API login, and the `paseo` user's `sudo` password. Generate with `openssl rand -base64 24`. |
| `PASEO_HOSTNAMES` | Domains allowed to reach the daemon, comma-separated. Your domain must be listed. |
| `PASEO_TRUSTED_PROXIES` | Set to `uniquelocal`, or the UI loads but never connects. |
| `PASEO_LABEL` | Container hostname. Paseo shows it as the host label in the UI; without it you get a random container ID. |
| `TZ` | Timezone for logs and agent shells. |
| `SHELL` | Shell for Paseo's terminals. Paseo reads `$SHELL` and falls back to `/bin/sh`, ignoring the login shell, so `chsh` has no effect. |

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
a redeploy. Dotfiles live there too — a `.zshrc` or oh-my-zsh install persists,
but anything written outside `$HOME` (`chsh`, `apt install`) is lost on rebuild.

## Image

| Tool | Source | Why not apt |
| --- | --- | --- |
| Claude Code | npm | — |
| `gh` | GitHub's signed apt repo | Debian does not package it |
| Go (`GO_VERSION`) | Official go.dev tarball | Debian 12 ships 1.19 |
| Python (`PYTHON_VERSION`) | `uv python install` | Debian 12 ships 3.11 |
| `less jq unzip zip lsof psmisc ugrep bfs zsh sudo` | apt | — |

Bump a language with a build arg, e.g. `--build-arg GO_VERSION=1.27.1`. Add
other agent providers to the `npm install` line:

```dockerfile
RUN npm install -g @anthropic-ai/claude-code @openai/codex opencode-ai
```

`uv` itself is installed too. Notes for anyone tempted to change things:

- npm installs the same native binary as Anthropic's standalone installer.
  Don't swap in `curl | bash` — it writes to `$HOME/.local`, and `$HOME` is
  `/home/paseo`, a volume mount that hides anything baked in at build time.
- Claude Code can't auto-update (`paseo` can't write `/usr/local`), so it shows
  a notice at startup. Rebuild to update.
- The image stays root on purpose: the entrypoint chowns the volumes, then
  drops to the `paseo` user (uid 1000) with `gosu`.
- `sudo` prompts for `PASEO_PASSWORD`. `entrypoint.sh` wraps the image's own
  entrypoint to set it — it has to run at start, since baking a password into a
  layer would commit the secret and `/etc/shadow` is not on a volume, so it
  reverts on every recreate. Leave `PASEO_PASSWORD` empty and the account stays
  locked, which means no `sudo`.
- `sudo` resets `PATH` to its `secure_path`, which does not include
  `/usr/local/go/bin`. `sudo go ...` therefore fails; use `sudo env PATH="$PATH"
  go ...` or the full path.
- Nothing installs into `$HOME`. That is `/home/paseo`, a volume mount that
  hides anything baked in at build time — hence `/opt/python` and
  `/usr/local/go` rather than the defaults.
