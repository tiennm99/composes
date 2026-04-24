# alloy-docker-compose

One-file [Grafana Alloy](https://grafana.com/docs/alloy/latest/) setup that ships host and container telemetry to Grafana Cloud — sized for the Free tier.

- **Single container, single file** — no `remotecfg`, no fleet-management, no split `alloy` + `alloy-docker` deployments.
- **Env-driven** — six shell variables, no `.env` file.
- **Least-privilege** — `cap_drop: [ALL]`, no `privileged`, no `pid: host`, UI not published.
- **Free-tier safe** — `keep`-filter on metric names holds a typical 15-container host to ~1,600 of the 10,000 active-series cap.

## What it collects

| Source | Component | Notes |
|---|---|---|
| Host metrics | `prometheus.exporter.unix` | CPU, memory (+MemFree/Available), load, disk I/O + IOPS + saturation, filesystem (size/avail/readonly/inodes), network (bytes/errs/drop), uname, boot time |
| Container metrics | `prometheus.exporter.cadvisor` | CPU, memory (usage + working_set), fs usage/limit, network, `last_seen` |
| Container logs | `loki.source.docker` | all running containers, labeled with `container`, `stream`, `instance` |
| System logs | `loki.source.journal` | systemd journal with `unit` + `level` labels |

60-second scrape interval. Alloy's own logs are *not* excluded — useful for debugging the agent itself.

## Quick start

```bash
export ALLOY_HOSTNAME=<host-name>                # e.g. miti-jp
export PROM_URL=https://prometheus-prod-XX-<region>.grafana.net/api/prom/push
export PROM_USER=<prometheus-user-id>
export LOKI_URL=https://logs-prod-XXX.grafana.net/loki/api/v1/push
export LOKI_USER=<loki-user-id>
export GRAFANA_TOKEN=glc_...                     # Cloud Access Policy, scopes: metrics:write + logs:write

docker compose up -d
```

Find the `PROM_*` / `LOKI_*` values under Grafana Cloud → your stack → **Details** on the Prometheus and Loki data sources. Create one Cloud Access Policy with both `metrics:write` and `logs:write` scopes, then generate a token from it and reuse for both writes.

Any unset required variable makes `docker compose up` fail fast with a clear error.

## Multi-host

The same file works on every host — just export a different `ALLOY_HOSTNAME`. Each instance independently ships to the same Grafana Cloud stack; filter/compare in Grafana with `instance=~"..."`.

## UI access

The UI (port `12345`) is **not** published to the host. To reach it:

```bash
# from another container on the same Docker network:
curl http://alloy:12345/graph

# or expose temporarily for local debugging:
docker compose exec alloy wget -qO- http://localhost:12345/-/ready
```

## Security posture

- Runs as `user: "0:0"` (root) inside the container — required to read `/var/run/docker.sock` (0660 root:docker) and `/var/log/journal/*` (0640 root:systemd-journal).
- All Linux capabilities dropped (`cap_drop: [ALL]`). Root without caps still reads files (DAC bypass) but cannot do privileged syscalls.
- `no-new-privileges:true` on seccomp.
- All host mounts are read-only. Only the `alloy-data` named volume is writable (WAL/positions).
- The UI listens on `0.0.0.0:12345` *inside* the container network only; no `ports:` mapping to the host.

## Free-tier cardinality budget (Grafana Cloud)

- **Metrics**: 10,000 active series hard cap. This config emits ~1,500–1,800 per host (cAdvisor dominates at ~150/container). Two hosts ≈ 32% utilisation.
- **Logs**: 50 GB/month ingestion. `batch_wait=5s`, `batch_size=1MiB` minimise push overhead. Typical home server stays well under.
- **Retention**: 14 days (set by the Free plan, not configurable here).

If you add a third host or scrape extra applications, re-check cardinality before declaring victory.

## Troubleshooting

- **`hostname: required` error from Compose** — you didn't `export ALLOY_HOSTNAME` in the current shell.
- **No system logs in Loki** — host has no persistent journal. Enable with `sudo mkdir -p /var/log/journal && sudo systemd-tmpfiles --create --prefix /var/log/journal && sudo systemctl restart systemd-journald`.
- **Empty panels on "Node Exporter Full" dashboard** — the `keep`-filter trims rarely-used metrics (Shmem, Slab, Active/Inactive memory breakdowns). Add names to the regex in `prometheus.relabel "filter"` to restore specific panels.
- **Docker logs missing for recently-started containers** — discovery refreshes every 5s; wait a few seconds.

## License

Apache 2.0 — see [LICENSE](LICENSE).
