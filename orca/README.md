# orca

[Orca](https://github.com/stablyai/orca) run headless with `orca serve`, as a
Remote Orca Server. The server owns the projects, worktrees, terminals and
agents; a browser, the Orca desktop app or the Orca mobile app connects to it
and is only the UI. Upstream ships no Docker image, so a local `Dockerfile`
builds one from `ubuntu:26.04`, and `entrypoint.sh` downloads the Orca AppImage
into `$HOME` on first start.

The container is a workspace: code lives in `/workspace`, and the image carries
build tools, command-line utilities, the `gh`, `glab`, `sops` and `docker`
CLIs. Language toolchains are installed into home, below.

Orca is reached through a public domain, so a client needs no VPN. See
[Exposure](#exposure).

## Setup

1. Point the domain at port `6768`. Set `ORCA_PAIRING_ADDRESS` to that domain
   as `wss://orca.example.com`, then deploy.
2. Open the deploy log and find the lines printed after `Orca server ready`:

   ```
   Web client URL: https://orca.example.com/web-index.html#pairing=...
   Pairing URL: orca://pair?code=...
   ```

3. **Browser:** open the `Web client URL`. **Desktop app:** paste the
   `Pairing URL` into **Settings → Remote Orca Servers → Add Server**.
4. **Mobile:** set `ORCA_PAIRING=mobile` and redeploy. The log then prints a
   QR code and a mobile `Pairing URL`. In Orca Mobile choose **Pair** and scan
   the QR code or paste the link.
5. Once every client is paired, set `ORCA_PAIRING=none` and redeploy, so later
   starts print no link.
6. From a terminal inside Orca, install and log in to the agent CLIs you want
   (`claude`, `codex`, …), and add accounts with `orca account add --agent
   claude`.

A start without `none` prints a link. An unused link stays the same across
restarts, and a new token is created only after the previous one has been used.
Paired clients keep their grant until it is revoked under **Settings → Remote
Orca Servers → Shared Server Access**, so a redeploy does not disconnect them.

## Toolchains

Only `/home/ubuntu` and `/workspace` survive a redeploy, so install toolchains
into home from a terminal inside Orca. Each command below was tested in
the image, in this order. Open a new terminal afterwards so the `PATH` changes
apply.

The terminal is zsh, and `~/.zshrc` starts empty. Put `~/.local/bin` on `PATH`
first, for the binaries below:

```sh
mkdir -p ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

### Official install methods

These follow the project's own documented install, which already targets home.

Node.js, with fnm, one of the methods on the
[Node.js download page](https://nodejs.org/en/download). fnm, Node and global
npm packages all live in `~/.local/share/fnm`. The default alias keeps one
stable path for shells and tools that do not load `fnm env`:

```sh
curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
echo 'export PATH="$HOME/.local/share/fnm/aliases/default/bin:$HOME/.local/share/fnm:$PATH"' >> ~/.zshenv
echo 'eval "$(fnm env --use-on-cd --shell zsh)"' >> ~/.zshrc
. ~/.zshenv
fnm install --lts
fnm default lts-latest
```

Python, with uv, from the
[uv installation guide](https://docs.astral.sh/uv/getting-started/installation/)
and [Python install guide](https://docs.astral.sh/uv/guides/install-python/).
uv puts itself in `~/.local/bin` and prebuilt Pythons in
`~/.local/share/uv/python`, and `--default` adds `python` and `python3`.
python.org itself documents only distro packages and source builds, both of
which land outside home:

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install 3 --default
```

Rust, with rustup, from the [install page](https://rustup.rs/). The toolchain
lives in `~/.rustup`, and `cargo` with the tools it installs in `~/.cargo/bin`;
rustup adds itself to `~/.zshenv`. `-y` accepts the default install:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
```

### Suggested by AI, may not be the optimal way

These use each project's official download, but no official doc covers
installing it into home: the location and the latest-version lookup are
improvised. Ubuntu's own packages are no alternative, since they can lag
behind.

Go, from the official tarball on [go.dev/dl](https://go.dev/dl/).
[go.dev/doc/install](https://go.dev/doc/install) extracts it to `/usr/local`;
the tarball runs from any directory, so it goes in `~/.local/go`. `go install`
puts tools in `~/go/bin`:

```sh
V=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)
curl -fsSL "https://go.dev/dl/$V.linux-$(dpkg --print-architecture).tar.gz" | tar -C ~/.local -xzf -
echo 'export PATH="$HOME/.local/go/bin:$HOME/go/bin:$PATH"' >> ~/.zshrc
```

To upgrade Go, `rm -rf ~/.local/go` and run the same commands again, without
the `echo` line.

### Java, last

Java, with SDKMAN, from its [install guide](https://sdkman.io/install/).
SDKMAN and every JDK it installs live in `~/.sdkman`; it needs the `zip` and
`unzip` the `Dockerfile` installs. Its installer appends to `~/.zshrc` and
requires its lines to stay at the end of the file, so install it after
everything above. `sdk install java` with no version takes SDKMAN's default,
the current Temurin LTS:

```sh
curl -s "https://get.sdkman.io" | bash
. "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java
```

`sdk list java` shows other vendors and versions, and `sdk install gradle` or
`sdk install maven` adds a build tool the same way.

## Environment

| Variable | Purpose |
| --- | --- |
| `ORCA_PAIRING_ADDRESS` | The address clients dial, as a `wss://` URL on the domain. Required. |
| `ORCA_PAIRING` | Which link the start prints: `runtime` (browser and desktop, the default), `mobile` or `none`. |
| `SERVICE_HOSTNAME` | Container hostname, shown as the host name in the prompt. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for agents and terminals. |

`ORCA_PAIRING_ADDRESS` is only what the server advertises; it still binds
`0.0.0.0:6768`. Without it the links point at `127.0.0.1`, which only works
inside the container. Given a `wss://` address, Orca turns it into the
`https://` web client URL itself, and the proxy carries both the page and the
WebSocket on the one port.

The web client URL is only printed in `runtime` mode, and the mobile app needs
a mobile-scoped link, so the two cannot come from one start; hence the
`ORCA_PAIRING` switch. A second `orca-ide serve` from a terminal inside the
container cannot mint a link either: it refuses while this server holds the
profile. `none` starts without a new link, for when every client is paired.

The links are printed rather than hidden because the server runs in the
foreground without `--supervise`; Orca redacts them only when supervised. The
container's restart policy replaces that supervisor. Treat the logs as secret:
the link is the credential.

`HOST` is set to `SERVICE_HOSTNAME` because Coolify injects `HOST=0.0.0.0`,
which zsh would otherwise show as the prompt's host name.

## Exposure

The port is public through the domain so that clients need no VPN. Upstream
advises against forwarding the Orca port directly to the internet and accepts
an authenticated tunnel, so an authenticating proxy in front of the domain is
worth adding; test that the desktop and mobile apps can still get through it.

Without one, the pairing token is the only barrier. It is 192 random bits, and
traffic is end-to-end encrypted above the WebSocket, so the proxy cannot read
it. The web client and the pre-login WebSocket are open to anyone, and Orca caps
connections at 128 WebSocket and 256 TCP, so a flood can lock clients out.

The token stays valid after it is used, so a link in the logs keeps working
until it is revoked, not just until first use. Revoking it also removes the
devices paired from it, and they have to pair again. Anyone who can read the
container's logs can therefore pair.

## Docker access

The host's Docker socket is bind-mounted at `/var/run/docker.sock`. Containers
started through it are siblings on the host, so bind mounts in them resolve
against host paths.

**Access to the socket is root on the host.** Orca is public and anyone who pairs
gets a shell, so a leaked pairing link gives root on the host and on everything
it runs. The `:ro` flag is not a boundary: it marks the socket file read-only,
but clients reach the Docker API by connecting to it. To drop this access, remove
the mount; `entrypoint.sh` skips its socket step when there is no socket.

The socket's group ID differs from host to host, so a fixed `group_add:` would
break on another host. `entrypoint.sh` reads the ID off the socket, adds `ubuntu`
to a group with that ID, creating `docker-host` if none exists, and restarts
itself under the new group, because a running process cannot join one. `PATH`,
`HOME` and `USER` are passed explicitly so `sudo` does not reset them. The image
keeps `USER ubuntu`, so `docker exec` shells open as `ubuntu` and have the group
too.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `orca-home` | `/home/ubuntu` | The Orca AppImage and its extracted cache, Orca's state and paired devices, agent CLIs and their logins |
| `orca-workspace` | `/workspace` | Repositories the agents work on |

The first start downloads the AppImage (about 250 MB) and Orca extracts it
into `~/.cache` (about 700 MB), so it takes a minute or more before the server
is ready. Later starts reuse both.

## Image

- The AppImage lives at `~/.local/bin/orca-ide`, on the home volume, not in
  the image. The AppImage is the Linux package that updates itself in place;
  in the image it would be stuck at the build-time version, and the `.deb`
  never updates itself at all. On the volume, an update applied from a paired
  client survives a redeploy. To force a fresh download, delete that file and
  restart.
- `APPIMAGE_EXTRACT_AND_RUN=1` starts the AppImage without FUSE, which a
  container does not have. This is the launch upstream tests in Docker.
- The Electron libraries and `xvfb` are the set upstream's headless Docker
  test installs. Orca starts its own Xvfb display when none is set; the dbus
  "Failed to connect to the bus" error at startup is harmless.
- `shm_size: 256m` matches upstream's test containers. Docker's 64 MB default
  is too small for Chromium, which backs Orca's browser panes.
- Orca disables the Electron sandbox by itself when user namespaces are
  unavailable, as in Docker, so the compose file needs no `--no-sandbox`.
- `init: true` reaps orphaned processes. Orca would do that itself as PID 1, but
  it does not run as PID 1 once `entrypoint.sh` restarts it through `sudo`.
- Per-terminal memory limits (`ORCA_TERMINAL_MEMORY_MAX`) need systemd user
  scopes, which the container lacks; Orca skips them.
- The `ubuntu` user has passwordless `sudo`. Anyone who pairs already has a
  shell as that user.

## Workspace tools

Ubuntu's packages are the install method for these, so they live in the image,
as a baseline every fresh deploy has without a setup step:

| Group | Packages |
| --- | --- |
| Build | `build-essential`, `bubblewrap`, `zip`, `unzip` |
| Network and DNS | `iproute2` (`ss`, `ip`), `lsof`, `bind9-dnsutils` (`dig`), `netcat-openbsd` (`nc`), `socat`, `mtr-tiny`, `whois` |
| Search and review | `tree`, `fd-find`, `fzf`, `git-delta`, `bat`, `ripgrep`, `jq` |
| Lint | `shellcheck`, `shfmt`, `yamllint` |
| Database clients | `postgresql-client` (`psql`), `sqlite3`, `redis-tools` (`redis-cli`) |
| Maintenance | `ncdu`, `tmux`, `restic`, `rclone`, `age`, `hyperfine`, `entr`, `7zip` (`7z`) |
| Media and fonts | `ffmpeg`, `fonts-liberation`, `fonts-noto-color-emoji`, `fonts-noto-cjk` |
| Desktop app builds | `pkg-config`, `libwebkit2gtk-4.1-dev`, `libssl-dev`, `libayatana-appindicator3-dev`, `librsvg2-dev`, `libxdo-dev` |

Ubuntu installs `fd` as `fdfind` and `bat` as `batcat`. These track Ubuntu 26.04's
versions, which can lag upstream. Install a newer copy into home when one falls
short.

`gh` and the Docker client with its Compose and Buildx plugins come from their
apt repositories, and `glab` and `sops` from the `.deb` on their latest
release, because Ubuntu's own are behind or missing. A rebuild without the layer
cache picks up new versions.

The desktop app libraries let GTK and WebKitGTK apps, such as Tauri apps, compile
and run their tests. The container has no display for opening a window.

The image has no browser for agents to drive, because Ubuntu 26.04 only ships
Chromium as a snap. The fonts are there so that a browser installed into home
renders CJK and emoji in screenshots.
