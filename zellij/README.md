# zellij

[Zellij](https://zellij.dev)'s [web client](https://zellij.dev/documentation/web-client.html)
as a terminal workspace in the browser. Sessions keep running after the
browser closes, and each one has its own URL:

- `https://<domain>/` lists sessions and starts new ones.
- `https://<domain>/<name>` attaches to session `<name>`, creating or
  resurrecting it if needed.

The image is `ubuntu:24.04` with git, zsh, sudo, build tools and
command-line utilities. On first start, `entrypoint.sh` installs the Zellij
release binary into `~/.local/bin`. Other tools are yours to install into
home, which survives redeploys.

## Setup

1. Set `PASSWORD`, point the domain at port `8080` and deploy.
2. Open the domain and enter `PASSWORD` at the token prompt. Tick
   "Remember me" to stay logged in for four weeks.
3. Open or create a session.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASSWORD` | Web login. Required. Generate with `openssl rand -base64 24`. |
| `SERVICE_HOSTNAME` | Container hostname, also passed as `HOST` for the zsh prompt |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |

Coolify injects `HOST=0.0.0.0`, and zsh takes its prompt hostname from
`$HOST`, hence the override.

## Login

Zellij has no password option; it logs in with tokens stored as unsalted
SHA-256 hashes in `~/.local/share/zellij/tokens.db`. On every start the
entrypoint writes the hash of `PASSWORD` there as the token `password`,
replacing an older one and logging out its browsers, then unsets the variable
so sessions never see it. The schema is internal to Zellij, so an upgrade may
break this. Zellij has no rate limiting, so keep `PASSWORD` random.

`zellij web --create-token`, `--list-tokens` and `--revoke-token <name>`
manage extra tokens. Anyone logged in is root in the container (passwordless
`sudo`) and on the host (the Docker socket).

## Web port

Zellij refuses to listen beyond `127.0.0.1` without its own TLS certificate.
The proxy already terminates TLS, so Zellij listens on `127.0.0.1:8082` and
`socat` relays `0.0.0.0:8080` to it with `TCP_NODELAY`, so keystrokes are not
batched. If either process exits, the container restarts.

The container has no TTY, so Docker sets no `TERM`, and Zellij passes that
on to its panes as `TERM=unknown`. Without terminfo, zsh cannot move the
cursor left: backspace moves it right instead and redraws stutter. The image
sets `TERM=xterm-256color`, which matches the browser's xterm.js.

Zellij's web server exits silently without a config file, so the entrypoint
creates an empty `~/.config/zellij/config.kdl`, plus an empty `~/.zshrc` to
skip zsh's first-run wizard. Both are yours to edit.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `zellij-home` | `/home/ubuntu` | Zellij and your tools, logins, tokens, config |
| `zellij-workspace` | `/workspace` | Code; sessions start here |

The user is the image's own `ubuntu` (UID 1000). Running sessions end when the
container restarts; Zellij can resurrect their layout, with commands to
confirm again.

To upgrade Zellij, delete `~/.local/bin/zellij` and restart.

## Docker access

The host's Docker socket is mounted at `/var/run/docker.sock`; install the
Docker CLI into `~/.local/bin` to use it. Because the socket's group ID varies
by host, the entrypoint adds `ubuntu` to a group with that ID and re-executes
itself under it. `:ro` does not restrict the Docker API.

## Browser for agent-browser

The image ships no browser: Ubuntu's `chromium` is a snap stub, and snaps do
not run in containers. Playwright's Chromium works, including on arm64:

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
. "$HOME/.nvm/nvm.sh"
nvm install 24

npx -y playwright install --with-deps chromium
ln -sf "$(ls -d ~/.cache/ms-playwright/chromium-*/chrome-linux*/chrome | sort -V | tail -1)" ~/.local/bin/chromium
echo 'export AGENT_BROWSER_EXECUTABLE_PATH="$HOME/.local/bin/chromium"' >> ~/.zshrc
```

Test from a new shell with
`npx -y agent-browser open https://example.com && npx -y agent-browser snapshot`.

`--with-deps` installs system libraries outside the home volume, so a redeploy
removes them. Rerun `npx -y playwright install-deps chromium` after each
redeploy, or add the libraries to the `Dockerfile` if you use the browser
regularly.
