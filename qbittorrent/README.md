# qbittorrent

[qBittorrent](https://www.qbittorrent.org) from the
[LinuxServer image](https://docs.linuxserver.io/images/docker-qbittorrent),
with the [VueTorrent](https://github.com/VueTorrent/VueTorrent) web UI added
through its LinuxServer mod. The `Dockerfile` adds `webui-login.sh`, which
sets the web UI login from the environment.

## Setup

1. Open `TORRENTING_PORT` (default `6881`), TCP and UDP, to the internet in
   the host's firewall.
2. Set `WEBUI_USERNAME` and `WEBUI_PASSWORD`, map the domain to port `8080`
   and deploy.
3. Log in, and under Settings > WebUI turn on "Use alternative WebUI" with
   the path `/vuetorrent`, and turn on "Enable reverse proxy support".

## Variables

| Variable | Meaning |
| --- | --- |
| `WEBUI_USERNAME` | Web UI login name |
| `WEBUI_PASSWORD` | Web UI password, in plain text; avoid `$` in it |
| `TORRENTING_PORT` | Peer port, published on the host for TCP and UDP |
| `TZ` | Time zone |

## Storage

- `qbittorrent-config` holds `/config`: settings, the torrent list and resume
  data, and the VueTorrent files the mod installs.
- `qbittorrent-downloads` holds `/downloads`, the default save path. Copy
  files out over SSH (rsync or SFTP) from the volume's path on the host.

## Why it is set up this way

- **Login from the environment:** qBittorrent has no setting for it, so
  `webui-login.sh` runs from the image's `/custom-cont-init.d` before
  qBittorrent starts. It hashes the password the way qBittorrent stores it
  (PBKDF2-SHA512) and writes both values into `qBittorrent.conf`, replacing
  any login changed in the UI. A `$` in the password would be read by compose
  as a variable.
- **Published peer port:** other peers must reach the client directly, which
  the web proxy cannot carry. The port number is the same inside and out, so
  the client announces the right one.
- **LinuxServer image:** VueTorrent ships a mod for it that installs and
  updates the UI on start; other images need it unpacked by hand.
- **VueTorrent behind qBittorrent's own login:** the UI is served by
  qBittorrent itself, so its WebUI password protects both.
- **Reverse proxy support:** without it, qBittorrent sees every visitor as the
  proxy's address, so failed logins from anyone would ban everyone.
- **One volume for downloads:** downloads share the host's disk with every
  other service, and qBittorrent has no total-size limit. Watch free space,
  and set seeding limits in its settings.
