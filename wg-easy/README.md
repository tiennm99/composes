# wg-easy

[wg-easy](https://wg-easy.github.io/wg-easy/latest/) runs a WireGuard VPN
server with a web UI for adding clients and downloading their configs or QR
codes.

## Wiring

- **WireGuard** listens on UDP `INIT_PORT` (51820), published on the host.
  UDP cannot pass through the platform's HTTP proxy or Cloudflare, so this is
  the one port the service publishes, and the host firewall must allow it.
- **Web UI** listens on 51821 inside the container. Give the app a domain on
  that port; the proxy serves it over HTTPS, so `INSECURE` stays unset and
  session cookies stay `Secure`. Access is guarded by wg-easy's own login.
- `/lib/modules` is mounted read-only and `SYS_MODULE` is granted so the
  container can load the host's `wireguard` kernel module. Where the host's
  modules are compressed (`.ko.zst`, as on Ubuntu), the container cannot load
  them: load `wireguard`, `iptable_nat` and `iptable_filter` on the host and
  list them in `/etc/modules-load.d/` so they load at boot. The last two serve
  the legacy iptables rules wg-easy adds inside its own network namespace.

## Variables

The `INIT_*` variables run the first setup unattended, so the setup wizard is
never left open on a public URL. They only take effect on a new installation.

| Variable | Meaning |
| --- | --- |
| `INIT_ENABLED` | Turns the `INIT_*` variables on |
| `INIT_USERNAME`, `INIT_PASSWORD` | First admin account; the password must be long |
| `INIT_HOST` | Endpoint clients connect to: the server's public IP or a DNS-only name, never a proxied one |
| `INIT_PORT` | WireGuard port, also the published host port |
| `DISABLE_IPV6` | `true` on hosts without IPv6 |
| `INIT_DNS` | DNS servers handed to clients |

After the first start, upstream advises removing the setup variables: set
`INIT_ENABLED=false` and clear `INIT_PASSWORD` in the app's environment, then
redeploy. The admin password then lives only in wg-easy's database.

## Storage

`wg-easy-data` at `/etc/wireguard` holds the database, server keys and every
client. Losing it means every client must be set up again.
