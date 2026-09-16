# alloy

[Grafana Alloy](https://grafana.com/docs/alloy/latest/) shipping host and
container telemetry to Grafana Cloud, with remote config from Grafana Fleet
Management.

One container runs both the `node_exporter` (host) and `cadvisor` (container)
collectors. The Alloy config is embedded inline via Compose `configs:`, so
there is no `config.alloy` on disk, and every setting comes from a shell
variable rather than a `.env` file.

Uses `docker-compose.yml`, and sets `restart: unless-stopped` and
`container_name: alloy` — unlike the platform-managed services described in the
[root README](../README.md).

## What it collects

| Source | Component | Notes |
|---|---|---|
| Host metrics | `prometheus.exporter.unix` | CPU, memory, load, disk I/O, filesystem, network, uname, boot time, systemd, vmstat, sockstat — the default collector set minus `ipvs/btrfs/infiniband/xfs/zfs` |
| Container metrics | `prometheus.exporter.cadvisor` | CPU, memory, fs usage/limit, network, `last_seen` |
| Container logs | `loki.source.docker` | All running containers, labeled `container`, `stream`, `instance` |
| Journal logs | `loki.source.journal` | systemd journal, labeled `unit`, `boot_id`, `transport`, `level` |
| File logs | `loki.source.file` | `/var/log/syslog`, `/var/log/messages`, `/var/log/*.log` |
| Remote config | `remotecfg` | Polls Grafana Fleet Management every 60s |

Metric filtering copies the `keep`-lists from the upstream Grafana Cloud
integrations verbatim ([Linux Node](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-linux-node/#metrics),
[Docker](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-docker/#metrics)).
Logs are unfiltered.

Where rsyslog mirrors journald into `/var/log/syslog` — the Debian and Ubuntu
default — the journal and file pipelines double-ship the same lines. Drop one
source on those hosts; the file-based one is the redundant one on systemd-only
stacks.

## Environment

All nine are required; `docker compose up` fails fast if any is unset.

| Variable | Purpose |
| --- | --- |
| `ALLOY_HOSTNAME` | Container hostname, and the Loki/Prometheus `instance` label |
| `REMOTECFG_URL` | Fleet Management endpoint |
| `REMOTECFG_ID` | Fleet Management agent id |
| `REMOTECFG_USER` | Fleet Management user id |
| `PROM_URL` / `PROM_USER` | Prometheus remote-write endpoint and user id |
| `LOKI_URL` / `LOKI_USER` | Loki push endpoint and user id |
| `GRAFANA_TOKEN` | One Cloud Access Policy token, scopes `metrics:write` + `logs:write` + `fleet-management:read` |

Find the values under Grafana Cloud → your stack → **Details** on each data
source, and under Fleet Management. The same token serves `remotecfg`,
Prometheus and Loki basic-auth.

```bash
export ALLOY_HOSTNAME=miti-jp REMOTECFG_ID=miti-jp ...
docker compose up -d
```

Run the same file on every host, changing `ALLOY_HOSTNAME` and `REMOTECFG_ID`
per host. Filter in Grafana with `instance=~"..."`.

## Privileges

Runs `privileged: true` with `network_mode: host`, matching the upstream
Grafana Cloud docker integration. Host networking is what lets
`prometheus.exporter.unix` report the host's real interfaces (`eth0`…) instead
of the container's veth pair. To tighten this, see the upstream Alloy docker
integration docs.

## Mounts

| Mount | Why |
|---|---|
| `/proc:/rootproc:ro` | node-exporter cpu/mem/load, via `procfs_path` |
| `/sys:/sys:ro` | node-exporter and cadvisor cgroups |
| `/:/rootfs:ro` | filesystem collector, via `rootfs_path` |
| `/dev/disk/:/dev/disk:ro` | node-exporter diskstats device labels |
| `/var/run/docker.sock` | `discovery.docker` and `loki.source.docker` |
| `/var/lib/docker:ro` | cadvisor container metadata |
| `/var/log:/var/log:ro` | `loki.source.journal` and `loki.source.file` |
| `/etc/machine-id:ro` | Stable host id for the journal reader |
| `alloy-data` | WAL and remotecfg cache |

## Notes

- [Upstream sources of truth](docs/upstream-sources-of-truth.md) — what this
  follows, what is in scope, how to audit dashboard metric needs.
- [Coolify SSH session noise](docs/known-noise-coolify-ssh-sessions.md) — only
  relevant on Coolify-managed hosts.
