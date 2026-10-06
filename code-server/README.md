# code-server

[VS Code in the browser](https://github.com/coder/code-server), from Coder's
official `codercom/code-server` image.

The image ships code-server on Debian with `git`, `zsh`, `curl`, `sudo` and a
few editors. The `Dockerfile` adds `build-essential`, `bubblewrap`, `zip` and
`unzip`, and wraps the entrypoint so it starts in `/workspace` and `coder` can
use the Docker socket. Language toolchains and CLIs are installed into home,
below.

## Toolchains

Only `/home/coder` and `/workspace` survive a redeploy, so install toolchains
and CLIs into home from the editor's terminal. Each command below was tested in
the image, in this order. Open a new terminal afterwards so the `PATH` changes
apply.

The terminal is zsh, and the image ships no `~/.zshrc`. Create it first, with
`~/.local/bin` on `PATH` for the binaries below:

```sh
mkdir -p ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

### Official install methods

These follow the project's own documented install, which already targets home.

Node.js, with nvm, the method marked recommended for Linux on the
[Node.js download page](https://nodejs.org/en/download). nvm, Node and global
npm packages all live in `~/.nvm`:

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
. "$HOME/.nvm/nvm.sh"
nvm install 24
```

Python, with uv, from the
[uv installation guide](https://docs.astral.sh/uv/getting-started/installation/)
and [Python install guide](https://docs.astral.sh/uv/guides/install-python/).
uv puts itself in `~/.local/bin` and prebuilt Pythons in
`~/.local/share/uv/python`. python.org itself documents only distro packages
and source builds, both of which land outside home:

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
. "$HOME/.local/bin/env"
uv python install 3.13
```

Rust, with rustup, from the [install page](https://rustup.rs/). The toolchain
lives in `~/.rustup`, and `cargo` with the tools it installs in `~/.cargo/bin`;
rustup adds itself to `~/.zshenv`. `-y` accepts the default install:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
```

Docker Compose and Buildx, as CLI plugins in `~/.docker/cli-plugins`, the
manual install from the
[Compose docs](https://docs.docker.com/compose/install/linux/#install-the-plugin-manually)
and the [Buildx README](https://github.com/docker/buildx#manual-download). The
Docker client itself is below:

```sh
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p "$DOCKER_CONFIG/cli-plugins"
ARCH=$(dpkg --print-architecture)

V=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/docker/compose/releases/latest | sed 's|.*/||')
curl -fsSL "https://github.com/docker/compose/releases/download/$V/docker-compose-linux-$(uname -m)" -o "$DOCKER_CONFIG/cli-plugins/docker-compose"

V=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/docker/buildx/releases/latest | sed 's|.*/||')
curl -fsSL "https://github.com/docker/buildx/releases/download/$V/buildx-$V.linux-$ARCH" -o "$DOCKER_CONFIG/cli-plugins/docker-buildx"

chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose" "$DOCKER_CONFIG/cli-plugins/docker-buildx"
```

To upgrade them, run the same commands again.

### Suggested by AI, may not be the optimal way

These use each project's official download, but no official doc covers
installing it into home: the location and the latest-version lookup are
improvised. Debian's own packages are no alternative, being several releases
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

Docker CLI and GitHub CLI, as the release binaries each project publishes,
into `~/.local/bin`:

- Docker: [static binaries](https://docs.docker.com/engine/install/binaries/),
  documented for `/usr/bin`. Only the client is taken; the daemon is the
  host's, through the socket.
- GitHub CLI: the `.tar.gz` on [cli.github.com](https://cli.github.com/), with
  no documented location.

```sh
ARCH=$(dpkg --print-architecture)

V=$(curl -fsSL https://download.docker.com/linux/static/stable/$(uname -m)/ | grep -o 'docker-[0-9.]*\.tgz' | sort -V | tail -1)
curl -fsSL "https://download.docker.com/linux/static/stable/$(uname -m)/$V" | tar -C ~/.local/bin -xzf - --strip-components=1 docker/docker

V=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest | sed 's|.*/v||')
curl -fsSL "https://github.com/cli/cli/releases/download/v$V/gh_${V}_linux_$ARCH.tar.gz" | tar -C ~/.local/bin -xzf - --strip-components=2 "gh_${V}_linux_$ARCH/bin/gh"
```

To upgrade one, run the `ARCH=` line and that tool's two lines again; the
new binary overwrites the old one.

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
| `PASSWORD` | Web UI login. Required. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |
| `SERVICE_HOSTNAME` | Container hostname |
| `CODE_SERVER_APP_NAME` | Optional. Name in the title bar and welcome page; defaults to `code-server`. |

Generate a password with `openssl rand -base64 24`.

The compose file refuses to start without `PASSWORD`. If it is unset, code-server
generates a random password into `~/.config/code-server/config.yaml`, which you
can only read from inside the container.

The `coder` user has passwordless `sudo`, as the image sets it up. Anyone who
can log in to the editor is root in the container.

## Docker access

The host's Docker socket is bind-mounted at `/var/run/docker.sock`. The image
ships no Docker CLI; install the client into home as above. Containers
started through it are siblings on the host, not children, so bind mounts in
them resolve against host paths.

The socket belongs to the host's `docker` group, whose GID differs from host
to host and is not exported anywhere a compose file could read it, so a fixed
`group_add:` would break on another host. Instead `entrypoint.sh` runs first
at startup: it reads the GID off the socket, adds `coder` to a group with that
GID (creating `docker-host` if none exists) and restarts the image's own
entrypoint under the new group. `docker` then works for `coder` without sudo,
in the editor's terminal and in `docker exec` shells alike. Access to the
socket is root on the host, which is accepted here because this is a
single-user dev box.

The wrapper keeps the image's `USER 1000`, so `docker exec` still opens a
shell as `coder`, and gets root through the image's passwordless sudo. A
running process cannot join a group, so it re-execs through `sudo -E setpriv
--init-groups`, which loads the new group; `PATH` and `USER` are passed
explicitly because sudo resets both. sudo stays as PID 1 and forwards stop
signals to code-server. On a container restart `coder` is already in the
group, and the wrapper hands straight to the image's entrypoint. Without a
socket mounted it does nothing.

The `:ro` flag is not a security boundary. It marks the socket file read-only,
but clients reach the Docker API by connecting to the socket, which a
read-only mount does not stop.

## Networking

Listens on `8080`; point the domain at it.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `code-server-home` | `/home/coder` | Home directory: settings, extensions, shell history, CLI logins |
| `code-server-workspace` | `/workspace` | Code you work on |

The image's entrypoint opens `.`, its working directory. `entrypoint.sh`
changes into `DEFAULT_WORKSPACE`, set to `/workspace` in `compose.yml`, before
starting it, so that is the folder code-server opens and where new terminals
start. Changing the variable moves both without editing the compose file's
structure. `docker exec` shells are not affected and start in the image's
`/home/coder`.

The `Dockerfile` also makes `/workspace` writable. The image does not
ship that directory, so a named volume mounted there comes up `root:root`,
and `coder` (uid `1000`) cannot write to it. Creating the directory in the
image, owned by `1000:1000`, fixes that without a runtime step, because Docker
seeds an empty named volume from the image's directory, ownership included.
The home volume needs no such step, because the image already ships
`/home/coder` owned by `coder`.

`build-essential`, `bubblewrap`, `zip` and `unzip` are in the `Dockerfile`
rather than home because their projects publish no standalone binaries;
Debian's packages are the install method, and they land outside home. The base
image ships none of them. `build-essential` supplies the `gcc` and `make` that
native builds expect: the linker `cargo` calls, node-gyp addons and Python
sdists.

Everything else lives in home rather than the image, so the image build stays
small and a redeploy does not reinstall or upgrade tools behind your back;
upgrading is the same commands run again.

## Shell

`SHELL=/bin/zsh` in `compose.yml` picks the shell. The editor's terminal takes
its default from `$SHELL` first and only falls back to the login shell in
`/etc/passwd`, so the variable is enough, and switching to another shell the
image ships means changing one line rather than rebuilding. `sudo -E` in
`entrypoint.sh` keeps the variable; without it sudo would replace it with
root's `/bin/bash`. The value is written literally, not read from `.env`,
because every deploying shell exports its own `SHELL`, which interpolation
would pick up first.

## Image

`codercom/code-server:latest` is the Debian 13 build and moves with every
release. Upstream publishes no major tag.
