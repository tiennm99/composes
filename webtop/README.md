# webtop

[Webtop](https://docs.linuxserver.io/images/docker-webtop): a full Ubuntu
XFCE desktop in the browser, from the LinuxServer image, streamed by Selkies.

Comes with Go, Node.js 24, Python 3 and zsh via LinuxServer mods, the
`code-server-npmglobal` mod so `npm install -g` lands under `/config` and
persists, plus `bubblewrap`, `gh`, `git`, `glab`, `unzip` and `zip` through
`INSTALL_PACKAGES`. The `code-server-*` mods carry that name upstream but are
plain Ubuntu installers that work on any LinuxServer Ubuntu image.

Mods install into each new container, so the first start after a recreate
takes a few minutes longer before the desktop answers.

## Setup

1. Set `PASSWORD`.
2. Map the domain to port `3000` and deploy.
3. Open the domain and log in with `CUSTOM_USER` / `PASSWORD`.

Port `3000` serves plain HTTP and must sit behind the proxy, which adds HTTPS.
The image's own HTTPS port `3001`, with a self-signed certificate, is unused.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `CUSTOM_USER` / `PASSWORD` | `miti99` / — | Login for the web desktop |
| `TZ` | `Asia/Ho_Chi_Minh` | Desktop timezone |
| `TITLE` | optional | Browser tab title |

`PASSWORD` is required: without it the image serves the desktop, with a
shell and `sudo`, to anyone who opens the domain.

`PUID`/`PGID` are pinned to `1000` in `compose.yml`; the `Dockerfile` depends
on that (see Storage).

## Docker access

The `universal-docker` mod installs the Docker CLI but no daemon, so the host
socket is bind-mounted at `/var/run/docker.sock`. Containers started from
inside are siblings on the host, not children: bind mounts in them resolve
against host paths, so a path under `/config` will not exist unless the same
path exists on the host.

The socket belongs to the host's `docker` group, which `abc` is not in; run
`docker` under `sudo` (the password is `PASSWORD`). Handing a container the
socket is equivalent to giving it root on the host, accepted here because this
is a single-user desktop. The `:ro` flag only marks the socket file read-only;
it does not restrict the Docker API.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `webtop-config` | `/config` | Home directory: desktop settings, browser profiles, CLI logins, apps installed with `proot-apps` |
| `webtop-workspace` | `/workspace` | Code and files you work on |

The `Dockerfile` exists only to make `/workspace` writable. The image's init
chowns `/config` to the `abc` user but not other paths, so a named volume on
`/workspace` would come up `root:root`. Creating the directory in the image,
owned by `1000:1000`, fixes that: Docker seeds an empty named volume from the
image directory, ownership included.

Software installed with `apt` lives in the container and is lost when it is
recreated. Anything that must survive goes under `/config`, through
`proot-apps` or a user-level install.

## Resources

`shm_size: 1gb` is upstream's recommendation for every desktop image; browsers
and the video encoder run out of shared memory at Docker's 64 MB default.

## Image

`ubuntu-xfce` is LinuxServer's moving tag for the Ubuntu XFCE flavour.
