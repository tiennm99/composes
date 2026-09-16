# paseo

[Paseo](https://paseo.sh) — self-hosted daemon and web UI for running coding
agents. Built from a local `Dockerfile` that adds six agent CLIs, `gh`, Go,
Python, a C toolchain, and shell tooling to the
[official image](https://paseo.sh/docs/docker), which ships none of it.

## Setup

1. Set the variables from `.env.example` in Coolify or Dokploy.
2. Point the domain at port `6767` and deploy.
3. Open the domain. At the pairing screen enter the host **with the port**,
   then the `PASEO_PASSWORD` value:

   ```
   paseo.example.com:443
   ```

4. In a terminal inside Paseo, log in once per tool you use — see
   [Agents](#agents) — plus `gh auth login`.

The port must be typed by hand. The UI rejects a bare hostname, and the
auto-connect hint does not help: the daemon builds it from the `Host` header,
browsers drop the default `:443`, and the UI discards a hint with no port. What
you see instead is its `localhost:6767` placeholder, which in a browser means
your own machine.

If it stays on `localhost:6767` after you enter the address, clear site data —
the old entry is cached in `localStorage`.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASEO_PASSWORD` | Web UI and API login, and the `paseo` user's `sudo` password. Generate with `openssl rand -base64 24`. |
| `PASEO_HOSTNAMES` | Domains allowed to reach the daemon, comma-separated. Your domain must be listed. |
| `PASEO_TRUSTED_PROXIES` | Set to `uniquelocal`, or the UI loads but never connects. |
| `PASEO_LABEL` | Container hostname, shown as the host label in the UI. Without it the label is a random container ID. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for agents and terminals. |
| `TZ` | Timezone for logs and agent shells. |
| `SHELL` | Shell for Paseo's terminals. Paseo reads `$SHELL` and falls back to `/bin/sh`, ignoring the login shell, so `chsh` has no effect. |

`PASEO_TRUSTED_PROXIES` matches the proxy's *source IP*, so hostnames are
rejected. The daemon trusts `X-Forwarded-Proto` from loopback only, but
Coolify's Traefik reaches it from the Docker bridge network — so it reads the
request as plain HTTP, tells the UI to use `ws://` on an `https://` page, and
the browser blocks that as mixed content. `uniquelocal` covers the private
ranges Docker uses. An exact CIDR works too, but Coolify assigns a fresh subnet
per project.

## Networking

Listens on `6767`, published nowhere — the platform maps the domain to it, so
`localhost:6767` on the host refuses connections. See the
[root README](../README.md) for why.

## Agents

| Agent | Command | Package | Log in with |
| --- | --- | --- | --- |
| Claude Code | `claude` | `@anthropic-ai/claude-code` | `claude` |
| Codex | `codex` | `@openai/codex` | `codex login` |
| opencode | `opencode` | `opencode-ai` | `opencode auth login` |
| Copilot CLI | `copilot` | `@github/copilot` | `/login` inside `copilot` |
| Pi | `pi` | `@earendil-works/pi-coding-agent` | `pi` |
| Oh My Pi | `omp` | `@oh-my-pi/pi-coding-agent` | `omp` |

All six come from npm, so another provider is one more entry on the `npm
install` line. Pi and Oh My Pi are separate projects sharing an ancestor; their
commands do not collide.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `paseo-home` | `/home/paseo` | Daemon state, agent configs, credentials (`.claude`, `.codex`, `.config/*`) |
| `paseo-workspace` | `/workspace` | Code the agents work on |

Every agent CLI and `gh` keep their config under `/home/paseo`, so all logins
survive a redeploy — the base image points `CLAUDE_CONFIG_DIR`, `CODEX_HOME`
and the `XDG_*` variables into it. Dotfiles live there too, so a `.zshrc` or
oh-my-zsh install persists. Anything written outside `$HOME` (`chsh`,
`apt install`) is lost on rebuild.

## Image

| Tool | Source | Why not apt |
| --- | --- | --- |
| Agent CLIs (see [above](#agents)) | npm | — |
| Bun | Official `bun.sh` install script | Debian does not package it |
| `gh` | GitHub's signed apt repo | Debian does not package it |
| Go (`GO_VERSION`) | Official go.dev tarball | Debian 12 ships 1.19 |
| Python (`PYTHON_VERSION`) | `uv python install` | Debian 12 ships 3.11 |
| `less nano jq unzip zip lsof psmisc ugrep bfs zsh sudo` | apt | — |
| `build-essential` | apt | — |

Bump a language with a build arg, e.g. `--build-arg GO_VERSION=1.27.1`. `uv`
itself is installed too.

Constraints worth knowing before changing the `Dockerfile`:

- `$HOME` is `/home/paseo`, a volume that masks anything the build writes
  there. Hence `/opt/python` and `/usr/local/go` rather than the defaults, and
  hence npm rather than each vendor's `curl | bash` installer, which writes to
  `$HOME/.local`. npm delivers the same native binaries regardless — every one
  of these packages is a thin launcher with the real binary as a per-platform
  optional dependency.
- Bun exists for `omp` alone, whose bin opens with `#!/usr/bin/env bun`.
  Node runs the other five.
- The agent CLIs cannot auto-update, since `paseo` cannot write `/usr/local`.
  Claude Code shows a notice at startup. Rebuild to update.
- The image stays root: the entrypoint chowns the volumes, then drops to the
  `paseo` user (uid 1000) with `gosu`.
- `entrypoint.sh` sets the `paseo` password from `PASEO_PASSWORD` on every
  start, while still root. `/etc/shadow` is not on a volume, so it reverts on
  each recreate. An empty `PASEO_PASSWORD` leaves the account locked and `sudo`
  unusable.
- `sudo` resets `PATH` to its `secure_path`, which excludes
  `/usr/local/go/bin`. Use `sudo env PATH="$PATH" go ...` or the full path.
