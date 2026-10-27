# netdata

[Netdata](https://www.netdata.cloud) monitoring agent.

Uses `docker-compose.yml`, and sets `restart: unless-stopped` and
`container_name: netdata` — unlike the platform-managed services described in
the [root README](../README.md).

Runs with `network_mode: host` and `pid: host`, plus `SYS_PTRACE`/`SYS_ADMIN`
and an unconfined AppArmor profile, so it can read host processes and metrics.
The dashboard is therefore on the host's own `19999`, not a published port.

## Environment

| Variable | Purpose |
| --- | --- |
| `NETDATA_CLAIM_TOKEN` | Netdata Cloud claim token. Without it the agent runs standalone. |

```sh
NETDATA_CLAIM_TOKEN=<token> docker compose up -d
```

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `netdataconfig` | `/etc/netdata` | Agent configuration |
| `netdatalib` | `/var/lib/netdata` | Metrics database, claim state |
| `netdatacache` | `/var/cache/netdata` | Cache |

Host paths (`/`, `/proc`, `/sys`, `/var/log`, the Docker socket, dbus) are
mounted read-only for collection.

## Related

- [alloy](../alloy/README.md) — ships metrics to Grafana Cloud instead
