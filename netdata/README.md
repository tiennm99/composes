# netdata-docker-compose

Docker Compose setup to run the [Netdata](https://www.netdata.cloud) monitoring agent.

## Quick start

```bash
docker compose up -d
```

Access the dashboard at `http://localhost:19999`.

## Customization

Set your Netdata Cloud claim token to link the agent to your cloud account:

```bash
NETDATA_CLAIM_TOKEN=your-token docker compose up -d
```

Key defaults you may want to override in `docker-compose.yml`:

| Setting | Default | Notes |
|---------|---------|-------|
| Dashboard port | `19999` | Map to a different host port if needed |
| Volumes | `/proc`, `/sys`, host root | Required for full host metrics |

## Related

- [alloy-docker-compose](https://github.com/tiennm99/alloy-docker-compose) — Grafana Alloy collector (ships metrics to Grafana Cloud)
- [grafana-git-sync](https://github.com/tiennm99/grafana-git-sync) — sync Grafana dashboards to git
- [ollama-docker-compose](https://github.com/tiennm99/ollama-docker-compose) — Ollama LLM server compose setup

## License

Apache-2.0 — see [LICENSE](LICENSE).
