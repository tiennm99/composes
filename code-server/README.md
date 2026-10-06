# code-server

[VS Code in the browser](https://github.com/coder/code-server), from Coder's
official `codercom/code-server` image.

The image ships code-server on Debian with `git`, `zsh`, `curl`, `sudo` and a
few editors. The `Dockerfile` adds `bubblewrap`, `zip` and `unzip`. Language
toolchains and CLIs are installed into home, below.

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

Docker CLI, GitHub CLI and GitLab CLI, as the release binaries each project
publishes, into `~/.local/bin`:

- Docker: [static binaries](https://docs.docker.com/engine/install/binaries/),
  documented for `/usr/bin`. Only the client is taken; the daemon is the
  host's, through the socket.
- GitHub CLI: the `.tar.gz` on [cli.github.com](https://cli.github.com/), with
  no documented location.
- GitLab CLI: the binary from the
  [releases page](https://gitlab.com/gitlab-org/cli/-/releases), with no
  documented location.

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
```

To upgrade one, run the `ARCH=` line and that tool's two lines again; the
new binary overwrites the old one.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASSWORD` | Web UI login. Required. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |
| `SERVICE_HOSTNAME` | Container hostname, and the name the shell prompt shows |

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

The socket belongs to the host's `docker` group, which `coder` is not in.
Run it as `sudo ~/.local/bin/docker`: sudo needs no password in this image,
but it resets `PATH`, hence the full path. Access to the socket is root on the
host, which is accepted here because this is a single-user dev box.

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

`bubblewrap`, `zip` and `unzip` are in the `Dockerfile` rather than home
because their projects publish no standalone binaries; Debian's packages are
the install method, and they land outside home.

## Image

`codercom/code-server:latest` is the Debian 13 build and moves with every
release. Upstream publishes no major tag.
