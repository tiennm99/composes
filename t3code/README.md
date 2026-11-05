# t3code

[T3 Code](https://github.com/pingdotgg/t3code) server, which runs coding agents
and is controlled from its web, desktop and mobile apps. Upstream ships no
Docker image, so a local `Dockerfile` builds one from `ubuntu:26.04`, and
`entrypoint.sh` runs upstream's installer into `$HOME` on first start.

The container is a workspace: code lives in `/workspace`, and the image carries
build tools, command-line utilities, and the `gh`, `glab`, `sops` and `docker`
CLIs. Language toolchains are installed into home, below.

T3 Code is reached through a public domain, so a client needs no VPN. See
[Exposure](#exposure).

## Setup

1. Point an HTTPS domain at port `3773`, then deploy.
2. Open a shell in the `t3code` container and create a link for your device:

   ```sh
   t3 auth pairing create --base-url https://t3code.example.com --ttl 10m
   ```

3. Open the printed `Pair URL` in a browser, or paste it into **Add environment**
   in the desktop or mobile app. Use a fresh link for each device.
4. Install and log in to the agent CLIs you want from that shell, for example:

   ```sh
   curl -fsSL https://claude.ai/install.sh | bash
   claude auth login
   ```

   Restart the app so the server detects a new CLI.
5. Set **Settings → Threads → New threads → Permissions**. New threads default
   to **Full access**.

Add repositories under `/workspace`.

## Toolchains

Only `/home/ubuntu` and `/workspace` survive a redeploy, so install toolchains
into home from a terminal in the container. Each command below was tested in the
image, in this order. Open a new terminal afterwards so the `PATH` changes apply.

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
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity for agents and terminals. |
| `SERVICE_HOSTNAME` | Container hostname, shown as the machine name in the apps and the prompt. |
| `T3CODE_TELEMETRY_ENABLED` | Set to `false` to stop product usage events and relay traces. Enabled by default. |

`HOST` is set to `SERVICE_HOSTNAME` because Coolify injects `HOST=0.0.0.0`,
which zsh would otherwise show as the prompt's host name. T3 Code does not read
it.

## Exposure

The pairing code is the only barrier in front of the port. Pairing gives whoever
holds the link a shell in the container, with passwordless `sudo`, and through
the Docker socket root on the host. See [Docker access](#docker-access).

`--host 0.0.0.0` is set because the server otherwise stays on loopback in its
container, out of the proxy's reach. The server builds its URLs from `Host` and
`X-Forwarded-Proto`, which the proxy passes through.

As tested on 0.1.7:

- A code is 12 characters and works once. A code from `t3 auth pairing create`
  expires after its `--ttl`.
- Wrong codes get `401` with no lockout, at least over 40 attempts in a row.
- A browser session lasts 30 days and survives a restart. Revoke access under
  **Settings → Sharing & access**, or with `t3 auth session list` and
  `t3 auth session revoke <id>`.
- Every start logs a new working code, so treat the deploy log as secret too. The
  logged URL uses the container's private address, which is why setup creates a
  link with `--base-url`. `t3 pair` has no such flag and prints the same private
  address.
- The web client and `/.well-known/t3/environment` answer without a code. The
  latter shows `SERVICE_HOSTNAME`, the server version, and the OS and architecture.

Treat a `Pair URL` as a password while it is unused.

T3 Connect is not set up. Its documented setup, `t3 up`, runs a systemd user
service, which the container lacks.

## Docker access

The host's Docker socket is bind-mounted at `/var/run/docker.sock`. Containers
started through it are siblings on the host, so bind mounts in them resolve
against host paths.

**Access to the socket is root on the host.** T3 Code is public and anyone who
pairs gets a shell, so a leaked pairing code gives root on the host and on
everything it runs. The `:ro` flag is not a boundary: it marks the socket file
read-only, but clients reach the Docker API by connecting to it. To drop this
access, remove the mount; `entrypoint.sh` skips its socket step when there is no
socket.

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
| `t3code-home` | `/home/ubuntu` | The `t3` CLI and its downloaded versions, T3 Code's state and paired devices, agent CLIs and their logins |
| `t3code-workspace` | `/workspace` | Repositories the agents work on |

## Image

- The CLI lives at `~/.local/bin/t3`, a symlink into `~/.t3/runtime/versions` on
  the home volume, so an update survives a redeploy. To update, run `t3 update`
  in a shell, then restart the app. The running server keeps the old version
  until it restarts.
- `shm_size: 256m` replaces Docker's 64 MB default, which is too small for a
  browser installed into home. The image carries fonts for its screenshots, but
  not Chromium's own libraries, so such a browser needs those added first.
- `init: true` reaps the agent and terminal processes the server leaves behind,
  since the server would otherwise be PID 1.
- The `ubuntu` user has passwordless `sudo`. Anyone who pairs already has a shell
  as that user.

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
apt repositories, and `glab` and `sops` from the `.deb` on their latest release,
because Ubuntu's own are behind or missing. A rebuild without the layer cache
picks up new versions.

The desktop app libraries let GTK and WebKitGTK apps, such as Tauri apps, compile
and run their tests. The container has no display for opening a window.
