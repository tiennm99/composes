# ttyd

[tmux](https://github.com/tmux/tmux) in the browser through
[ttyd](https://github.com/tsl0922/ttyd), as a terminal workspace. Sessions
keep running after the browser closes, and each one has its own URL:

- `https://<domain>/` attaches to the session `main`.
- `https://<domain>/?arg=<name>` attaches to session `<name>`, creating it if
  needed.

Every tab on the same URL shares one session. tmux's keys are a prefix
(`Ctrl+B`) followed by a plain key, so they do not collide with the browser's
own Ctrl shortcuts. Ctrl+W still closes the tab; ttyd asks before leaving, and
the session survives either way.

The image is `ubuntu:24.04` with tmux, git, zsh, sudo, build tools and
command-line utilities. On first start, `entrypoint.sh` installs the ttyd
release binary into `~/.local/bin`. Other tools are yours to install into
home, which survives redeploys.

## Setup

1. Set `PASSWORD`, point the domain at port `7681` and deploy.
2. Open the domain and log in as `ubuntu` with `PASSWORD`.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASSWORD` | Web login for the user `ubuntu`. Required. Generate with `openssl rand -base64 24`. |
| `SERVICE_HOSTNAME` | Container hostname, also passed as `HOST` for the zsh prompt |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |

Coolify injects `HOST=0.0.0.0`, and zsh takes its prompt hostname from
`$HOST`, hence the override.

## Login

ttyd uses HTTP basic auth, so the browser remembers the login until it is
closed. The entrypoint unsets `PASSWORD` before starting ttyd, so sessions do
not inherit it, but the credential stays in ttyd's command line. That exposes
nothing new: anyone logged in is root in the container (passwordless `sudo`)
and on the host (the Docker socket). ttyd has no rate limiting, so keep
`PASSWORD` random.

ttyd runs with `--check-origin`, which refuses WebSocket connections opened
from another site's page.

## Terminal

The container has no TTY, so Docker sets no `TERM`; the image sets
`TERM=xterm-256color` to match the browser's xterm.js, and tmux sets its own
inside panes. tmux reads `~/.tmux.conf` if you create one, for example
`set -g mouse on` or a different prefix.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `ttyd-home` | `/home/ubuntu` | ttyd and your tools, logins, config |
| `ttyd-workspace` | `/workspace` | Code; sessions start here |

The user is the image's own `ubuntu` (UID 1000). tmux sessions end when the
container restarts.

To upgrade ttyd, delete `~/.local/bin/ttyd` and restart. tmux comes from
Ubuntu and upgrades with the image.

## Docker access

The host's Docker socket is mounted at `/var/run/docker.sock`; install the
Docker CLI into `~/.local/bin` to use it. Because the socket's group ID varies
by host, the entrypoint adds `ubuntu` to a group with that ID and re-executes
itself under it. `:ro` does not restrict the Docker API.
