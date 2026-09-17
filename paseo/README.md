# paseo

[Paseo](https://paseo.sh) — self-hosted daemon and web UI for running coding
agents. Built from a local `Dockerfile` that adds `gh`, `glab`, Go, Python,
a C toolchain, and shell tooling to the
[official image](https://paseo.sh/docs/docker), which ships none of it. The
agent CLIs are not baked in — install them into `$HOME` yourself, see
[Agents](#agents).

## Setup

1. Set the variables from `.env.example` in Coolify or Dokploy.
2. Point the domain at port `6767` and deploy.
3. Open the domain. At the pairing screen enter the host **with the port**,
   then the `PASEO_PASSWORD` value:

   ```
   paseo.example.com:443
   ```

4. In a terminal inside Paseo, install and log in to the agents you use — see
   [Agents](#agents) — plus `gh auth login` and `glab auth login`.

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

The image installs none of them. Run each vendor's own installer once, in a
terminal inside Paseo, as the `paseo` user — never with `sudo`:

| Agent | Command | Install with | Log in with |
| --- | --- | --- | --- |
| Claude Code | `claude` | `curl -fsSL https://claude.ai/install.sh \| bash` | `claude` |
| Codex | `codex` | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` | `codex login` |
| opencode | `opencode` | `curl -fsSL https://opencode.ai/install \| bash` | `opencode auth login` |
| Copilot CLI | `copilot` | `curl -fsSL https://gh.io/copilot-install \| bash` | `/login` inside `copilot` |
| Oh My Pi | `omp` | `curl -fsSL https://omp.sh/install \| sh` | `omp` |
| Pi | `pi` | `curl -fsSL https://pi.dev/install.sh \| sh` | `pi` |

Each lands in `$HOME` — `~/.local/bin` for most, `~/.opencode/bin` for
opencode — and appends that directory to your shell rc, so open a new terminal
afterwards. `$HOME` is the `paseo-home` volume, so both the binaries and the
logins survive a redeploy.

Both directories are on the image's `PATH`, so Paseo picks an agent up as soon
as its installer finishes — no redeploy, no daemon restart. The shell rc entry
the installers add only reaches interactive terminals; the daemon looks the
binary up in its own environment, and without these entries it reports every
self-installed agent as unavailable while a terminal runs it fine.

The installers pull in any runtime they need, into `$HOME` as well. `omp` is
the one to know about: it is Bun-compiled, and with no Bun on `PATH` its
installer takes the prebuilt binary. Ask for the source build (`--source`) and
it installs Bun to `~/.bun` first.

Why not bake them into the image: `paseo` cannot write `/usr/local`, so a
preinstalled CLI can never apply its own update. Every one of these ships an
updater (`claude update`, `codex update`, `omp update`, …) that expects to
rewrite its own binary, and under `/usr/local` it fails on permissions — Claude
Code nags about it at startup. Installed in `$HOME` they update themselves, and
you are never waiting on an image rebuild for a release that shipped that
morning.

Run the installers unprivileged. Under `sudo` they target root's home and land
outside the volume; Claude Code's refuses outright.

Pi and Oh My Pi are separate projects sharing an ancestor; their commands do
not collide.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `paseo-home` | `/home/paseo` | Daemon state, agent configs, credentials (`.claude`, `.codex`, `.config/*`) |
| `paseo-workspace` | `/workspace` | Code the agents work on |

The agent CLIs, `gh` and `glab` all keep their config under `/home/paseo`, so
every login survives a redeploy — the base image points `CLAUDE_CONFIG_DIR`,
`CODEX_HOME` and the `XDG_*` variables into it. The agent binaries live there
too, since you install them yourself. Dotfiles as well, so a `.zshrc` or
oh-my-zsh install persists. Anything written outside `$HOME` (`chsh`,
`apt install`) is lost on rebuild.

## Image

| Tool | Source | Why not apt |
| --- | --- | --- |
| `gh` | GitHub's signed apt repo | Debian does not package it |
| `glab` (`GLAB_VERSION`) | The `.deb` on GitLab's releases page | Debian does not package it, and GitLab runs no apt repo |
| Go (`GO_VERSION`) | Official go.dev tarball | Debian 12 ships 1.19 |
| Python (`PYTHON_VERSION`) | `uv python install` | Debian 12 ships 3.11 |
| `less nano jq unzip zip lsof psmisc ugrep bfs zsh sudo` | apt | — |
| `build-essential` | apt | — |

Bump a pinned version with a build arg, e.g. `--build-arg GO_VERSION=1.27.1`.
`uv` itself is installed too. `GLAB_VERSION` is pinned rather than tracking the
latest because GitLab's download URL carries the version in the path.

The `Dockerfile` itself only says what each layer installs. The reasoning is
all here:

- `$HOME` is `/home/paseo`, a volume that masks anything the build writes
  there. Hence `/opt/python` and `/usr/local/go` rather than the defaults.
- Do not add agent CLIs here, or a runtime only they need. Under `/usr/local`
  they cannot self-update; in `$HOME` they can, and they persist anyway. Bun
  used to be here for `omp` and went the same way. See [Agents](#agents).
- One concern per layer, cheapest and least-changing first, so bumping a
  version rebuilds as little as possible.
- `build-essential` is the C toolchain the language layers assume but do not
  ship: cgo, npm's node-gyp addons and Python C extensions all shell out to
  `gcc` and `make`. It rides along in the apt layer so there is one
  `apt-get update`.
- `git` and `curl` are already in the base image. `sudo` is not, despite
  Debian's `base-passwd` shipping an empty `sudo` group, so the apt layer adds
  it and puts `paseo` in the group.
- The image stays root: the entrypoint chowns the volumes, then drops to the
  `paseo` user (uid 1000) with `gosu`.
- `entrypoint.sh` sets the `paseo` password from `PASEO_PASSWORD` on every
  start, while still root. `/etc/shadow` is not on a volume, so it reverts on
  each recreate. An empty `PASEO_PASSWORD` leaves the account locked and `sudo`
  unusable.
- `sudo` resets `PATH` to its `secure_path`, which excludes
  `/usr/local/go/bin`. Use `sudo env PATH="$PATH" go ...` or the full path.
- The agent `PATH` entries belong in the image, not in a shell rc: the daemon
  probes for each provider's binary with `which` in its own environment, which
  comes from the image and never sources an rc file. They are spelled
  `/home/paseo/...` because `ENV` only expands variables the `Dockerfile` itself
  set earlier.
