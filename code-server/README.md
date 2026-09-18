# code-server

[VS Code in the browser](https://github.com/linuxserver/docker-code-server),
from the LinuxServer image, set up as a full remote dev box.

Comes with Go, Node.js 24, Python 3, and zsh via LinuxServer mods, plus `gh`,
`git`, `glab`, `unzip` and `zip` through `INSTALL_PACKAGES`. Git
author/committer identity is injected from `.env`.

## Docker access

The `universal-docker` mod installs the Docker CLI but no daemon, so the host
socket is bind-mounted at `/var/run/docker.sock` to give it something to talk
to. Containers started from inside are siblings on the host, not children --
bind mounts in them resolve against host paths, so a path under `/config` will
not exist unless the same path exists on the host.

The socket is owned by the host's `docker` group, which the `abc` user inside
the container is not a member of; run `docker` under `sudo` (the `SUDO_PASSWORD`
is the same `PASSWORD`) or add the group by hand. Handing a container the
socket is equivalent to giving it root on the host -- that is accepted here
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
rather than calling `gethostname()` -- so the prompt reads `0`, the first
dot-separated field of `0.0.0.0`. code-server itself never reads `HOST` -- it
binds `[::]:8443` -- so overriding it only affects the prompt. bash is
unaffected; its `\h` uses the real hostname.

It is not called `HOSTNAME`, the obvious name, because Compose interpolation
lets the deploying shell's environment win over the `.env` file, and `HOSTNAME`
is set in every container -- including the one Coolify itself runs in. The
container would silently take Coolify's hostname instead of this value.

## Networking

Listens on `8443`. No ports are published — point the domain at that port in
Coolify or Dokploy. See the [root README](../README.md) for why.

## Storage

Everything lives in the `code-server-config` named volume mounted at `/config`;
the default workspace is `/config/workspace`. Removing the volume wipes your
files, settings, and extensions.
