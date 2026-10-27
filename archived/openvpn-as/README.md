# openvpn-as

[OpenVPN Access Server](https://openvpn.net/access-server/).

Uses `docker-compose.yml`, publishes ports, and sets `restart: unless-stopped`
and `container_name: openvpn-as` — unlike the platform-managed services
described in the [root README](../README.md).

Needs `/dev/net/tun` plus the `MKNOD` and `NET_ADMIN` capabilities to create
the VPN interface.

## Networking

| Port | Purpose |
| --- | --- |
| `943` | Admin and client web UI |
| `443` | OpenVPN over TCP |
| `1194/udp` | OpenVPN over UDP |

Admin UI at `https://<host>:943/admin`. The initial credentials are printed to
the container logs on first start.

## Storage

`openvpn-as-data` at `/openvpn` — config, certificates, user database.
