# selkies

[Selkies](https://github.com/selkies-project/selkies) desktop container: the
project's own reference image, a minimal Ubuntu LXQt desktop in the browser
with Firefox and Google Chrome and nothing else. Further applications are
installed later from the sidebar's Apps panel or with `proot-apps install
<app>` in a terminal.

## Setup

1. Set `PASSWD`.
2. Map the domain to port `8080` and deploy.
3. Open the domain and log in as `ubuntu` / `PASSWD`.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `PASSWD` | — | Web login password for user `ubuntu`, and that account's password inside the desktop |
| `TZ` | `Asia/Ho_Chi_Minh` | Desktop timezone |

`PASSWD` is required. The image's own default, `mypasswd`, is published
upstream.

`SELKIES_ENABLE_HTTPS=false` is fixed in `compose.yml`. The image serves HTTPS
with a self-signed certificate by default; the proxy terminates TLS instead,
so the container serves plain HTTP behind it.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `selkies-home` | `/home/ubuntu` | Home directory: desktop settings, browser profiles, CLI logins, apps installed through the Apps panel or `proot-apps` |
| `selkies-workspace` | `/workspace` | Code and files you work on |

The `Dockerfile` exists only to make `/workspace` writable. The image runs as
uid 1000 and does not ship `/workspace`, so a named volume there would come up
`root:root`. Creating the directory in the image, owned by `1000:1000`, fixes
that: Docker seeds an empty named volume from the image directory, ownership
included.

Software installed with `apt` (or `sudo`) lives in the container and is lost
when it is recreated. Apps from the Apps panel or `proot-apps` live under
`~/proot-apps/` in the home volume and persist.

The Apps panel needs `ptrace`, which Docker's default seccomp profile allows.
On a host that denies it, Selkies hides the panel.

## Resources

`shm_size: 2gb` is upstream's value; the browsers abort on heavy pages at
Docker's 64 MB default.

No GPU is passed in, so encoding runs on the CPU.

## Image

`latest-ubuntu26.04` is upstream's moving tag for the newest release on
Ubuntu 26.04. Upstream publishes no tag without a distribution suffix.
