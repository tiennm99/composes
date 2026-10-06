# code-server

[VS Code in the browser](https://github.com/coder/code-server), from Coder's
official `codercom/code-server` image.

The image ships code-server on Debian with `git`, `zsh`, `curl`, `sudo` and a
few editors. The `Dockerfile` adds `build-essential`, `bubblewrap`, `zip`,
`unzip` and the headers Ruby builds against, makes zsh the login shell, and
wraps the entrypoint so `coder` can use the Docker socket. Language toolchains
and CLIs are installed into home, below.

## Toolchains

Only `/home/coder` and `/workspace` survive a redeploy, so install toolchains
and CLIs into home from the editor's terminal. Each command below was tested in
the image. Open a new terminal afterwards so the `PATH` changes apply.

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

Ruby, with rbenv and its ruby-build plugin, each cloned with git as their
READMEs document ([rbenv](https://github.com/rbenv/rbenv#basic-git-checkout),
[ruby-build](https://github.com/rbenv/ruby-build#clone-as-rbenv-plugin-using-git)).
Debian's `ruby` package is 3.3, several releases behind. Rubies are compiled into
`~/.rbenv/versions` against the headers the `Dockerfile` installs.
`rbenv init` adds itself to the login shell's startup file, `~/.zprofile`:

```sh
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
~/.rbenv/bin/rbenv init
eval "$(~/.rbenv/bin/rbenv init - zsh)"
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
V=$(rbenv install -l 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | tail -1)
rbenv install "$V" && rbenv global "$V"
```

To get newer Ruby versions listed, `git -C "$(rbenv root)"/plugins/ruby-build pull`.

Docker Compose and Buildx, as CLI plugins in `~/.docker/cli-plugins`, the
manual install from the
[Compose docs](https://docs.docker.com/compose/install/linux/#install-the-plugin-manually)
and the [Buildx README](https://github.com/docker/buildx#manual-download).
Nothing installs them together with the client: Docker's static archive holds
only the client and daemon, and the packages that bundle all three are apt
packages, which land outside home. The client itself is below:

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
mkdir -p ~/.local
curl -fsSL "https://go.dev/dl/$V.linux-$(dpkg --print-architecture).tar.gz" | tar -C ~/.local -xzf -
echo 'export PATH="$HOME/.local/go/bin:$HOME/go/bin:$PATH"' >> ~/.bashrc
```

To upgrade Go, `rm -rf ~/.local/go` and run the same commands again, without
the `echo` line.

Docker CLI, GitHub CLI, GitLab CLI and jq, as the release binaries each
project publishes, into `~/.local/bin`:

- Docker: [static binaries](https://docs.docker.com/engine/install/binaries/),
  documented for `/usr/bin`. Only the client is taken; the daemon is the
  host's, through the socket.
- GitHub CLI: the `.tar.gz` on [cli.github.com](https://cli.github.com/), with
  no documented location.
- GitLab CLI: the binary from the
  [releases page](https://gitlab.com/gitlab-org/cli/-/releases), with no
  documented location.
- jq: the binary from the
  [releases page](https://github.com/jqlang/jq/releases), with no documented
  location.

```sh
mkdir -p ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
ARCH=$(dpkg --print-architecture)

V=$(curl -fsSL https://download.docker.com/linux/static/stable/$(uname -m)/ | grep -o 'docker-[0-9.]*\.tgz' | sort -V | tail -1)
curl -fsSL "https://download.docker.com/linux/static/stable/$(uname -m)/$V" | tar -C ~/.local/bin -xzf - --strip-components=1 docker/docker

V=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest | sed 's|.*/v||')
curl -fsSL "https://github.com/cli/cli/releases/download/v$V/gh_${V}_linux_$ARCH.tar.gz" | tar -C ~/.local/bin -xzf - --strip-components=2 "gh_${V}_linux_$ARCH/bin/gh"

V=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://gitlab.com/gitlab-org/cli/-/releases/permalink/latest | sed 's|.*/v||')
curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v$V/downloads/glab_${V}_linux_$ARCH.tar.gz" | tar -C ~/.local/bin -xzf - --strip-components=1 bin/glab

V=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/jqlang/jq/releases/latest | sed 's|.*/||')
curl -fsSL "https://github.com/jqlang/jq/releases/download/$V/jq-linux-$ARCH" -o ~/.local/bin/jq && chmod +x ~/.local/bin/jq
```

To upgrade one, run the `ARCH=` line and that tool's two lines again; the
new binary overwrites the old one.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASSWORD` | Web UI login. Required. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |
| `SERVICE_HOSTNAME` | Container hostname, and the name the shell prompt shows (also passed as `HOST`) |

Generate a password with `openssl rand -base64 24`.

The compose file refuses to start without `PASSWORD`. If it is unset, code-server
generates a random password into `~/.config/code-server/config.yaml`, which you
can only read from inside the container.

The `coder` user has passwordless `sudo`, as the image sets it up. Anyone who
can log in to the editor is root in the container.

`SERVICE_HOSTNAME` is used twice: as the container's `hostname:` and as the
`HOST` variable inside it. Coolify injects `HOST=0.0.0.0` into every compose
app, and zsh seeds `$HOST` and the `%m`/`%M` prompt escapes from that variable
rather than calling `gethostname()`, so a zsh prompt reads `0`. code-server
itself never reads `HOST`; it binds through `--bind-addr`. bash is unaffected;
its `\h` uses the real hostname.

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

The image's entrypoint opens `.`, its working directory. `working_dir:
/workspace` makes that the folder code-server opens.

The `Dockerfile` also makes `/workspace` writable. The image does not
ship that directory, so a named volume mounted there comes up `root:root`,
and `coder` (uid `1000`) cannot write to it. Creating the directory in the
image, owned by `1000:1000`, fixes that without a runtime step, because Docker
seeds an empty named volume from the image's directory, ownership included.
The home volume needs no such step, because the image already ships
`/home/coder` owned by `coder`.

`build-essential`, `bubblewrap`, `zip` and `unzip` are in the `Dockerfile`
rather than home because their projects publish no standalone binaries;
Debian's packages are the install method, and they land outside home.
`build-essential` supplies the `gcc` and `make` that native builds expect:
node-gyp addons, Python sdists, Rust crates using `cc`, and Ruby built by
rbenv. `libffi-dev`, `libssl-dev`, `libyaml-dev` and `zlib1g-dev` are the
headers a rbenv-built Ruby needs for its `fiddle`, `openssl`, `psych` and
`zlib` extensions; without them `rbenv install` fails or leaves those out.

The image leaves `coder` with `/bin/bash` as its login shell. The editor's
terminal opens zsh regardless, but tools that read the login shell from
`/etc/passwd` or `$SHELL` get bash, so the `Dockerfile` sets it to zsh.

## Image

`codercom/code-server:latest` is the Debian 13 build and moves with every
release. Upstream publishes no major tag.
