# alloy-docker-compose

One-file [Grafana Alloy](https://grafana.com/docs/alloy/latest/) setup that ships host (linux) and container (docker) telemetry to Grafana Cloud, plus pulls remote config from Grafana Fleet Management.

- **Single container** running both `node_exporter` (host) and `cadvisor` (containers) collectors.
- **Config embedded inline** via Compose `configs:` — no sidecar `config.alloy` file on disk.
- **Env-driven** — nine shell variables, no `.env` file.
- **Remote config** via `remotecfg` block (Grafana Fleet Management).

## What it collects

| Source | Component | Notes |
|---|---|---|
| Host metrics | `prometheus.exporter.unix` | CPU, memory, load, disk I/O, filesystem, network, uname, boot time |
| Container metrics | `prometheus.exporter.cadvisor` | CPU, memory, fs usage/limit, network, `last_seen` |
| Container logs | `loki.source.docker` | all running containers, labeled with `container`, `stream`, `instance` |
| System logs | `loki.source.journal` (via `journal_module`) | systemd journal with `unit`, `boot_id`, `transport`, `level` labels |
| Remote config | `remotecfg` | polls Grafana Fleet Management every 60s |

`keep`-filter on metric names trims the firehose down to the standard Grafana Cloud integration dashboards (node-exporter + docker).

## Quick start

```bash
export ALLOY_HOSTNAME=miti-jp                                                                      # also used as Loki/Prometheus instance label
export REMOTECFG_URL=https://fleet-management-prod-013.grafana.net
export REMOTECFG_ID=miti-jp                                                                        # fleet-management agent id
export REMOTECFG_USER=1431677                                                                      # fleet-management user id
export PROM_URL=https://prometheus-prod-XX-<region>.grafana.net/api/prom/push
export PROM_USER=<prometheus-user-id>
export LOKI_URL=https://logs-prod-XXX.grafana.net/loki/api/v1/push
export LOKI_USER=<loki-user-id>
export GRAFANA_TOKEN=glc_...                                                                       # one Cloud Access Policy token, scopes: metrics:write + logs:write + fleet-management:read

docker compose up -d
```

Find the `PROM_*` / `LOKI_*` / `REMOTECFG_*` values under Grafana Cloud → your stack → **Details** on each data source / Fleet Management. The same token is reused for `remotecfg`, Prometheus, and Loki basic-auth.

Any unset required variable makes `docker compose up` fail fast.

## Multi-host

Same compose file on every host — change `ALLOY_HOSTNAME` and `REMOTECFG_ID` per host. Filter in Grafana with `instance=~"..."`.

## Security note

Runs `privileged: true` + `network_mode: host`, matching the upstream Grafana Cloud docker integration. `network_mode: host` is required so `prometheus.exporter.unix` reports the host's real network interfaces (eth0…) instead of the alloy container's veth pair. If you need least-privilege, see the upstream Alloy docker integration docs and tighten capabilities.

## Mounts

| Mount | Why |
|---|---|
| `/proc:/rootproc:ro` | node-exporter cpu/mem/load (referenced via `procfs_path`) |
| `/sys:/sys:ro` | node-exporter + cadvisor cgroups |
| `/:/rootfs:ro` | filesystem collector (referenced via `rootfs_path`) |
| `/dev/disk/:/dev/disk:ro` | node-exporter diskstats device labels |
| `/var/run/docker.sock` | `discovery.docker` + `loki.source.docker` |
| `/var/lib/docker:ro` | cadvisor container metadata |
| `/var/log/journal:ro` | `loki.source.journal` |
| `/etc/machine-id:ro` | stable host id for the journal reader |
| `alloy-data` (named volume) | WAL + remotecfg cache |

## Known noise (special cases)

- [Coolify SSH session spam](docs/known-noise-coolify-ssh-sessions.md) — only relevant if Coolify manages the host. Safe to ignore otherwise.

## License

Apache 2.0 — see [LICENSE](LICENSE).
