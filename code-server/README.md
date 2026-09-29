# code-server

[VS Code in the browser](https://github.com/linuxserver/docker-code-server),
from the LinuxServer image, set up as a full remote dev box.

Comes with Go, Node.js 24, Python 3 and zsh via LinuxServer mods, the
`code-server-npmglobal` mod so `npm install -g` lands under `/config` and persists,
plus `bubblewrap`, `gh`, `git`, `glab`, `unzip` and `zip` through
`INSTALL_PACKAGES`. Git author/committer identity is injected from `.env`.

## Docker access

The `universal-docker` mod installs the Docker CLI but no daemon, so the host
socket is bind-mounted at `/var/run/docker.sock` to give it something to talk
to. Containers started from inside are siblings on the host, not children --
bind mounts in them resolve against host paths, so a path under `/config` will
not exist unless the same path exists on the host.

The socket is owned by the host's `docker` group, which the `abc` user inside
the container is not a member of; run `docker` under `sudo` (the `SUDO_PASSWORD`
is the same `PASSWORD`) or add the group by hand. Handing a container the
socket is equivalent to giving it root on the host — that is accepted here
because this is a single-user dev box.

The mount carries `:ro`, which is not a security boundary: it only marks the
socket file read-only, while the Docker API is reached by connecting to the
socket, which a read-only mount does not stop. Full API access, and with it
root on the host, remains. Restricting that would need a socket proxy or a
separate rootless daemon.

## Environment

| Variable | Purpose |
| --- | --- |
| `SERVICE_HOSTNAME` | Container hostname, and the name the shell prompt shows. |
| `PASSWORD` | Web UI login, also the in-container sudo password. **A blank value disables authentication entirely.** |
| `GIT_NAME` / `GIT_EMAIL` | Git author and committer identity |

Generate a password with `openssl rand -base64 24`.

`SERVICE_HOSTNAME` is used twice: as the container's `hostname:` and as the
`HOST` variable inside it. Coolify injects `HOST=0.0.0.0` into every compose
app, and zsh seeds `$HOST` and the `%m`/`%M` prompt escapes from that variable
rather than calling `gethostname()` — so the prompt reads `0`, the first
dot-separated field of `0.0.0.0`. code-server itself never reads `HOST` — it
binds `[::]:8443` — so overriding it only affects the prompt. bash is
unaffected; its `\h` uses the real hostname.

`PUID`/`PGID` are pinned to `1000` in `compose.yml`; the `Dockerfile` depends
on that (see [Storage](#storage)).

## Networking

Listens on `8443`; point the domain at it.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `code-server-config` | `/config` | Home directory: settings, extensions, shell history, CLI logins |
| `code-server-workspace` | `/workspace` | Code you work on |

`DEFAULT_WORKSPACE` points at `/workspace`. It only chooses the folder
code-server opens; it does not move anything.

The `Dockerfile` exists only to make `/workspace` writable. The image
hard-codes what it hands to the `abc` user — `init-adduser` takes `/app`,
`/config` and `/defaults`, `init-code-server` takes `/config/workspace` by
literal path — and reads `DEFAULT_WORKSPACE` only to decide which folder to
open. A named volume on `/workspace` is therefore never chowned, comes up
`root:root`, and the editor cannot write a single file into it.

Creating the directory in the image, owned by `1000:1000`, fixes it without any
runtime step: Docker seeds an empty named volume from the image directory,
ownership included, so `/workspace` arrives owned by `abc`.

The alternative was a `chown` script in `/custom-cont-init.d`, the image's own
init hook. It was rejected because it needs a bind mount from the repository
into the container, and because the hook silently skips any script that has
lost its executable bit — a read-only workspace with nothing obvious to blame.
Baking `1000:1000` into the image costs the ability to change `PUID` at
runtime, which is free here because `compose.yml` pins it.
