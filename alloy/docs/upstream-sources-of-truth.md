# Upstream Sources of Truth

## Hard rule: official sources only

> **Only use official sources** when deciding what metrics, labels, log pipelines, dashboards, or rules this repo ships. **Never** consult or copy from third-party repos, blog posts, community Gists, or personal exports — even if the names match.
>
> If an answer can't be found in an official source, document the gap rather than fill it with unofficial data. **Non-negotiable.**

### What counts as an official source

| Tier | Source | Use for |
|---|---|---|
| 1 | `https://grafana.com/docs/grafana-cloud/...` (Grafana Cloud integration reference pages) | Alloy snippet, scrape config, label conventions, drop/keep rules |
| 2 | `github.com/grafana/...` (Grafana Labs org repos) | Mixin libsonnet/jsonnet, `dashboards_out/*.json`, alerting rules |
| 3 | `github.com/prometheus/...` (Prometheus org repos) | Upstream node_exporter mixin, prom-mixin libraries |
| 4 | The Grafana Cloud stack's own running dashboards (via authenticated API) | Authoritative answer for "what does my live integration use" |

### What doesn't count (do not use)

- Personal forks, Terraform exports, ops-team copies of integration dashboards.
- `grafana.com/grafana/dashboards/<id>` community submissions, unless explicitly published by the `grafana` user.
- AI summaries of dashboards.
- Stale snapshots in unrelated repos that happen to contain `job=integrations/...` strings.

## Principle

Alloy here ships **only what the integration dashboards need** — not the full firehose of every metric/log line node_exporter and cadvisor can produce. The goal is dashboards that work out-of-the-box on Grafana Cloud, without paying for unused active series.

When the upstream integration changes (adds a metric, drops a panel, renames a label), this repo follows. Local additions outside that scope go into a separate, named, documented overlay.

## Upstream references

The two reference pages this repo's `docker-compose.yml` mirrors:

- **Linux Node integration** — <https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-linux-node/>
- **Docker integration** — <https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-docker/>

Where official mixin dashboards exist they're tier-2 corroboration:

- Docker mixin (Grafana Labs): <https://github.com/grafana/jsonnet-libs/blob/master/docker-mixin/dashboards_out/docker.json>
- Node-exporter mixin (Prometheus project): <https://github.com/prometheus/node_exporter/tree/master/docs/node-mixin>

## Mapping our config to upstream

| Block in `docker-compose.yml` | Upstream source |
|---|---|
| `prometheus.exporter.unix` (collectors, mounts, fs/net excludes) | Linux Node integration page → "Configure Alloy" |
| `prometheus.relabel "integrations_node_exporter"` (`keep` allowlist of 157 metrics) | Linux Node integration page → [Metrics](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-linux-node/#metrics) section, verbatim |
| `loki.source.journal "default"` + relabel rules (`unit`, `boot_id`, `transport`, `level`) | Linux Node integration page → log scraping |
| `loki.source.file` for `/var/log/{syslog,messages,*.log}` | Linux Node integration page → file log scraping |
| `prometheus.exporter.cadvisor` (`docker_only = true`) | Docker integration page |
| `prometheus.relabel "integrations_cadvisor"` (`keep` allowlist of 16 metrics) | Docker integration page → [Metrics](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-docker/#metrics) section, verbatim |
| `discovery.docker` + `loki.source.docker` (job/instance/container/stream) | Docker integration page → log scraping |

## What "follow upstream" means in practice

1. **Don't expand the metric set unilaterally.** If a panel in a Grafana Cloud dashboard requires a metric we don't ship, we'd add it — but the trigger is "the integration dashboard needs it, verified from a tier 1–4 source", not "node_exporter exposes it".
2. **Don't filter further than upstream does.** We ship at least what the upstream config does. Tightening (e.g. for cost) goes in a clearly-named overlay or a downstream env-specific config.
3. **Re-check on Alloy/integration major versions.** When bumping `grafana/alloy` image or when the Grafana Cloud integration revs, diff the upstream Alloy snippet against `docker-compose.yml` and update.

## Audit (2026-04-26)

Both keep-lists in `docker-compose.yml` are copied verbatim from the **Metrics** section of each integration page (tier 1):

- **Linux-Node** — 157 raw metrics (`node_*`, `process_max_fds`, `process_open_fds`, `up`). The list also contains `instance:node_num_cpu:sum`, which is a recording-rule output computed server-side by Grafana Cloud's ruler — it's intentionally **not** in the keep-list because the agent doesn't produce it.
- **Docker** — 16 metrics (`container_*`, `machine_memory_bytes`, `machine_scrape_error`, `up`).

Re-verification on 2026-04-26 also confirmed:

- **Alloy image** bumped `v1.10.0` → `v1.16.0` (latest stable, released 2026-04-23).
- **`loki.source.journal` `path`** was previously pinned to `/var/log/journal`; upstream omits the field, letting Alloy default to **both** `/var/log/journal` (persistent) and `/run/log/journal` (volatile). Local now matches — `path` removed.

The Grafana Cloud integration's full dashboard set (the 7 Linux-Node + 2 Docker dashboards) is not publicly hosted. Tier-4 verification (against the live stack via authenticated API) was **not** performed and is the only known gap.

### Re-running the audit

```bash
# Tier 2 — Grafana Labs docker-mixin
curl -sL https://raw.githubusercontent.com/grafana/jsonnet-libs/master/docker-mixin/dashboards_out/docker.json \
  | jq -r '.. | .expr? // empty' \
  | grep -oE 'container_[a-zA-Z0-9_]+|machine_[a-zA-Z0-9_]+' | sort -u

# Tier 3 — Prometheus node-exporter mixin (libsonnet, grep for metric names)
curl -sL https://raw.githubusercontent.com/prometheus/node_exporter/master/docs/node-mixin/lib/prom-mixin.libsonnet \
  | grep -oE 'node_[a-zA-Z0-9_]+|process_[a-zA-Z0-9_]+' | sort -u

# Tier 4 — your own Grafana Cloud stack
GRAFANA_TOKEN=...   # service-account token, dashboards:read
STACK=<your-stack>.grafana.net
curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
  "https://$STACK/api/search?query=Linux+Node&type=dash-db" \
  | jq -r '.[].uid' | while read uid; do
      curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
        "https://$STACK/api/dashboards/uid/$uid" > "$uid.json"
    done
# then jq + grep as above
```

## Out of scope

- Custom dashboards or metrics for app-level monitoring (deploy a separate Alloy config for that).
- Host-specific filtering (e.g. dropping noisy log lines from a particular daemon — see `docs/known-noise-coolify-ssh-sessions.md` for an example).
