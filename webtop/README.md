# webtop

[Webtop](https://docs.linuxserver.io/images/docker-webtop): a full Ubuntu
XFCE desktop in the browser, from the LinuxServer image, streamed by Selkies.

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
