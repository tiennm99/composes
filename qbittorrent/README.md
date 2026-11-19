# qbittorrent

[qBittorrent](https://www.qbittorrent.org) from the
[LinuxServer image](https://docs.linuxserver.io/images/docker-qbittorrent),
with the [VueTorrent](https://github.com/VueTorrent/VueTorrent) web UI added
through its LinuxServer mod.

## Setup

1. Open `TORRENTING_PORT` (default `6881`), TCP and UDP, to the internet in
   the host's firewall.
2. Map the domain to port `8080` and deploy.
3. Log in as `admin` with the temporary password printed in the container
   log, then set your own under Settings > WebUI. Until you do, a new
   temporary password is made on every restart.
4. In the same tab, turn on "Use alternative WebUI" with the path
   `/vuetorrent`, and turn on "Enable reverse proxy support".

## Variables

| Variable | Meaning |
| --- | --- |
| `TORRENTING_PORT` | Peer port, published on the host for TCP and UDP |
| `TZ` | Time zone |

## Storage

- `qbittorrent-config` holds `/config`: settings, the torrent list and resume
  data, and the VueTorrent files the mod installs.
- `qbittorrent-downloads` holds `/downloads`, the default save path. Copy
  files out over SSH (rsync or SFTP) from the volume's path on the host.

## Why it is set up this way

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
