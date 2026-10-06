# code-server

[VS Code in the browser](https://github.com/coder/code-server), from Coder's
official `codercom/code-server` image.

The image ships code-server on Debian with `git`, `zsh`, `curl`, `sudo` and a
few editors. The `Dockerfile` adds `build-essential`, `bubblewrap`, `zip`,
`unzip`, the headers Ruby builds against, the Docker CLI with its Compose and
Buildx plugins, and the GitHub CLI, and wraps the entrypoint so it starts in
`/workspace` and `coder` can use the Docker socket. Language toolchains and
other CLIs are installed into home, below.

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

Java, with SDKMAN, from its [install guide](https://sdkman.io/install/).
SDKMAN and every JDK it installs live in `~/.sdkman`; the installer adds itself
to `~/.bashrc` and `~/.zshrc`, and needs the `zip` and `unzip` the `Dockerfile`
installs. `sdk install java` with no version takes SDKMAN's default, the
current Temurin LTS:

```sh
curl -s "https://get.sdkman.io" | bash
. "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java
```

`sdk list java` shows other vendors and versions, and `sdk install gradle` or
`sdk install maven` adds a build tool the same way.

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

jq, the binary from its
[releases page](https://github.com/jqlang/jq/releases), into `~/.local/bin`,
with no documented location:

```sh
mkdir -p ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
ARCH=$(dpkg --print-architecture)

V=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/jqlang/jq/releases/latest | sed 's|.*/||')
curl -fsSL "https://github.com/jqlang/jq/releases/download/$V/jq-linux-$ARCH" -o ~/.local/bin/jq && chmod +x ~/.local/bin/jq
```

To upgrade it, run the same commands again, without the `echo` line; the new
binary overwrites the old one.

## Environment

| Variable | Purpose |
| --- | --- |
| `PASSWORD` | Web UI login. Required. |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |
| `SERVICE_HOSTNAME` | Container hostname, and the name the shell prompt shows (also passed as `HOST`) |
| `CODE_SERVER_APP_NAME` | Optional. Name in the title bar and welcome page; defaults to `code-server`. |

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

The host's Docker socket is bind-mounted at `/var/run/docker.sock`. The
`Dockerfile` installs the client only; the daemon is the host's. Containers
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
Debian's packages are the install method, and they land outside home.
`build-essential` supplies the `gcc` and `make` that native builds expect:
node-gyp addons, Python sdists, Rust crates using `cc`, and Ruby built by
rbenv. `libffi-dev`, `libssl-dev`, `libyaml-dev` and `zlib1g-dev` are the
headers a rbenv-built Ruby needs for its `fiddle`, `openssl`, `psych` and
`zlib` extensions; without them `rbenv install` fails or leaves those out.

The Docker CLI, its Compose and Buildx plugins, and the GitHub CLI come from
Docker's and GitHub's signed apt repositories, which is each vendor's documented
install for Debian. Neither documents an install into home, and Coolify builds
with `--pull`, so they update with each rebuild rather than by hand. The GitLab
CLI is not in the image: GitLab publishes no apt repository, only Homebrew and
a community one.

Copies of `docker`, `gh` or the plugins left in `~/.local/bin` or
`~/.docker/cli-plugins` from an older setup take precedence over the image's
and should be deleted.

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
