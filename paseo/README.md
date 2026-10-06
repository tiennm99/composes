# paseo

[Paseo](https://paseo.sh) — self-hosted daemon and web UI for running coding
agents. Built from a local `Dockerfile` that adds `gh`, `glab`, Python, a C
toolchain, `zsh` and `nano` to the
[official image](https://paseo.sh/docs/docker), which ships none of it. The
agent CLIs are not baked in; `entrypoint.sh` installs them into `$HOME` on
start, see [Agents](#agents).

## Setup

1. Point the domain at port `6767` and deploy.
2. Open the domain. At the pairing screen enter the host **with the port**,
   then the `PASEO_PASSWORD` value:

   ```
   paseo.example.com:443
   ```

3. List the agents you want in `AGENTS`; the first start installs them.
   Log in to each — see [Agents](#agents) — plus `gh auth login` and
   `glab auth login`.

The port must be typed by hand. The UI rejects a bare hostname, and the
auto-connect hint does not help: the daemon builds it from the `Host` header,
browsers drop the default `:443`, and the UI discards a hint with no port. What
you see instead is its `localhost:6767` placeholder, which in a browser means
your own machine.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASEO_PASSWORD` | Web UI and API login, and the `paseo` user's `sudo` password. Generate with `openssl rand -base64 24`. |
| `PASEO_HOSTNAMES` | Domains allowed to reach the daemon, comma-separated. Your domain must be listed. |
| `PASEO_TRUSTED_PROXIES` | Set to `uniquelocal`, or the UI loads but never connects. |
| `AGENTS` | Agent CLIs to install on start if missing, space- or comma-separated. Empty installs none. See [Agents](#agents). |
| `SERVICE_HOSTNAME` | Container hostname, shown as the host label in the UI and in the shell prompt. Without it the label is a random container ID. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for agents and terminals. |

`PASEO_TRUSTED_PROXIES` matches the proxy's *source IP*, so hostnames are
rejected. The daemon trusts `X-Forwarded-Proto` from loopback only, but
Coolify's Traefik reaches it from the Docker bridge network — so it reads the
request as plain HTTP, tells the UI to use `ws://` on an `https://` page, and
the browser blocks that as mixed content. `uniquelocal` covers the private
ranges Docker uses. An exact CIDR works too, but Coolify assigns a fresh subnet
per project.

`SERVICE_HOSTNAME` is used twice: as the container's `hostname:`, which is
where the daemon takes its host label from, and as the `HOST` variable inside
it. Coolify injects `HOST=0.0.0.0` into every compose app, and zsh seeds `$HOST`
and the `%m`/`%M` prompt escapes from that variable rather than calling
`gethostname()` — so the prompt would read `0`, the first dot-separated field
of `0.0.0.0`. Paseo itself never reads `HOST` — it binds `PASEO_LISTEN` — so
overriding it only affects the prompt. bash is unaffected; its `\h` uses the
real hostname.

`SHELL=/bin/zsh` and `TZ=Asia/Ho_Chi_Minh` are written into `compose.yml`
directly rather than read from `.env`, which is why neither is in the table.
They are properties of this setup, not of whoever deploys it — and every
interactive shell exports `SHELL`, so a value routed through `.env` could be
replaced by the deploying terminal's own shell, handing Paseo's terminals a
path the image lacks. Paseo reads `$SHELL` for its terminals and falls back to
`/bin/sh` (dash) otherwise; it ignores the user's login shell, so `chsh` has no
effect. That is what pins zsh here.

## Agents

The image installs none of them. `entrypoint.sh` does, on start, for every name
in `AGENTS` whose command does not already run. The default is
`AGENTS=claude codex`; the other four are opt-in.

| Agent | Name in `AGENTS` | Installer it runs | Log in with |
| --- | --- | --- | --- |
| Claude Code | `claude` | `claude.ai/install.sh` | `claude` |
| Codex | `codex` | `chatgpt.com/codex/install.sh` | `codex login` |
| opencode | `opencode` | `opencode.ai/install` | `opencode auth login` |
| Copilot CLI | `copilot` | `gh.io/copilot-install` | `/login` inside `copilot` |
| Oh My Pi | `omp` | `omp.sh/install` | `omp` |
| Pi | `pi` | `pi.dev/install.sh` | `pi` |

Each vendor's own installer, run as `paseo` through `gosu`, landing in `$HOME`
— `~/.local/bin` for most, `~/.opencode/bin` for opencode. `$HOME` is the
`paseo-home` volume, so the binaries and the logins both survive a redeploy.
Pi and Oh My Pi are separate projects sharing an ancestor; their commands do
not collide.

**First start.** These are fat static binaries, a few hundred MB each — Claude
Code around 216 MB, `omp` around 208 MB — so the default two hold the daemon
back by a minute or more, and all six by several. Later starts skip everything
already present. An agent that fails to install, or a name that is not in the
table, is logged and skipped rather than taking the container with it, so a bad
release or a network blip cannot leave you without a shell.

**Presence check.** The start asks each command for `--version` and reinstalls
only on exit codes 126 and 127, the shell's own codes for a binary it could not
execute. A `curl | bash` cut short — a network drop, or the platform stopping
the container mid-download — leaves a truncated binary on the volume, which a
file-existence check would accept on every later start while the daemon
advertised an agent that fails on every call. An agent that runs but does not
understand `--version` exits with some other code and counts as present, so
nothing assumes all six support the flag.

**Installing by hand.** Run the installer in a terminal inside Paseo as
`paseo` — never under `sudo`, where it targets root's home and lands outside
the volume, and where Claude Code's refuses outright. Both install directories
are on the image's `PATH`, so the daemon picks an agent up as soon as its
installer finishes — no redeploy, no restart. The installers pull in any
runtime they need, into `$HOME` as well. `omp` is the one to know about: it is
Bun-compiled, and with no Bun on `PATH` its installer takes the prebuilt
binary. Ask for the source build (`--source`) and it installs Bun to `~/.bun`
first.

**Why on start and not in the `Dockerfile`.** `paseo` cannot write
`/usr/local`, so a CLI installed there can never apply its own update — every
one of these ships an updater (`claude update`, `codex update`, `omp update`,
…) that rewrites its own binary, and it fails on permissions; Claude Code nags
about it at startup. And a build-time install into `/home/paseo` would only
ever reach a *new* volume: Docker seeds a named volume from the image once, at
creation, and never again. Rebuild with a seventh agent added and nobody with
an existing `paseo-home` would get it. The start-time check fires on every
fresh volume, and the agents update themselves in place afterwards.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `paseo-home` | `/home/paseo` | Daemon state, agent CLIs and their configs and credentials (`.claude`, `.codex`, `.config/*`) |
| `paseo-workspace` | `/workspace` | Code the agents work on |

The agent CLIs, `gh` and `glab` all keep their config under `/home/paseo` — the
base image points `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and the `XDG_*` variables
into it — so every login survives a redeploy, as do dotfiles such as a `.zshrc`
or an oh-my-zsh install. Anything written outside `$HOME` (`chsh`,
`apt install`) is lost on rebuild.

## Image

| Tool | Source | Why not apt |
| --- | --- | --- |
| `gh` | GitHub's signed apt repo | Debian does not package it |
| `glab` (`GLAB_VERSION`) | The `.deb` on GitLab's releases page | Debian does not package it, and GitLab runs no apt repo |
| Python (`PYTHON_VERSION`) | `uv python install` | Debian 12 ships 3.11 |
| `build-essential`, `sudo`, `zsh`, `nano` | apt | — |

Bump a pinned version with a build arg, e.g.
`--build-arg PYTHON_VERSION=3.13`. `uv` itself is installed too.
`GLAB_VERSION` is pinned rather than tracking the latest because GitLab's
download URL carries the version in the path.

The `Dockerfile` and `entrypoint.sh` only say what each step does. The
reasoning:

- Python lives in `/opt/python` rather than under `$HOME`, the `uv` default,
  because `/home/paseo` is a volume that masks anything the build writes there.
- No agent CLIs, and no runtime only they need (`omp`'s Bun). Under
  `/usr/local` they cannot self-update; in `$HOME` they can, and they persist
  anyway. See [Agents](#agents).
- `build-essential` is the C toolchain npm's node-gyp addons and Python C
  extensions shell out to for `gcc` and `make`. No other language toolchain is
  in the image, because none is wanted often enough to pay for a rebuild —
  install Go, a JVM or anything else into `$HOME` from a terminal, where it
  persists on the `paseo-home` volume like the agent CLIs do.
- `git` and `curl` are already in the base image. `sudo` is not, despite
  Debian's `base-passwd` shipping an empty `sudo` group, so the apt layer adds
  it and puts `paseo` in the group.
- The image stays root. `entrypoint.sh`, installed as
  `/usr/local/bin/entrypoint`, runs *before* the base image's
  `paseo-docker-entrypoint` and then hands over to it: that one ends in
  `exec gosu paseo` and never returns, and every job here — `chpasswd`, and
  `gosu paseo` for the agent installs — needs root.
- The `paseo` password is set on every start rather than at build, so it never
  lands in an image layer, and because `/etc/shadow` is in the image rather
  than on a volume and reverts on each recreate. It is piped, not passed as an
  argument, since arguments are visible in `ps`; `chpasswd` splits on the first
  colon, so a colon in the password is fine. A failure there is logged and the
  start continues, because `chpasswd` rejects a multi-line value and under
  `set -e` that would otherwise take the whole service down rather than just
  the password. An empty `PASEO_PASSWORD` leaves the account locked and `sudo`
  unusable.
- `/home/paseo` is not `chown`ed before the agent installs. The base image
  declares it a volume and ships it owned by uid 1000, so a fresh named volume
  is seeded with that ownership; the base entrypoint also chowns it, along
  with `PASEO_HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and the XDG directories,
  whenever one of them is owned by root.
- `chpasswd` and `gosu` are called by absolute path. The agent `PATH` entries
  come first in the image's `PATH`, including root's, and they live on a
  volume that anything running as `paseo` — an agent, by design — can write to;
  a file planted there under one of those names would otherwise run as root on
  the next start.
- Globbing is off (`set -f`) around the `AGENTS` loop. The list is split
  unquoted, so a `*` in it would otherwise expand against `/workspace`, the
  working directory, and report every file in it as an unknown agent.
- The agent `PATH` entries are `ENV` in the image, not a shell rc entry: the
  daemon probes for each provider's binary with `which` in its own environment,
  which never sources an rc file, and would otherwise report every
  self-installed agent as unavailable while a terminal ran it fine. They are
  spelled `/home/paseo/...` because `ENV` only expands variables the
  `Dockerfile` itself set earlier.
