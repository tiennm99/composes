# ollama-docker-compose

Minimal Docker Compose setup for running [Ollama](https://ollama.com) locally — exposes the API on `:11434` with a named volume so pulled models persist across restarts.

> The "optionally with a web UI" phrase from the description is **not yet wired**. Open Web UI sidecar can be added — see [Roadmap](#roadmap).

## Quick start

```bash
docker compose up -d
```

Ollama API → `http://localhost:11434`.

Pull a model:

```bash
docker compose exec ollama ollama pull llama3.2
```

Chat from CLI:

```bash
docker compose exec ollama ollama run llama3.2
```

Smoke test via API:

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

## What's inside

| Field | Value |
|---|---|
| Image | `ollama/ollama` (latest) |
| Port | `11434:11434` |
| Volume | `ollama:/root/.ollama` (models, manifests) |
| Restart policy | `unless-stopped` |

## GPU

To enable GPU, add `deploy.resources.reservations.devices` for the NVIDIA runtime — see the [Ollama Docker docs](https://hub.docker.com/r/ollama/ollama). CPU-only by default.

## Roadmap

- Add Open Web UI sidecar (`ghcr.io/open-webui/open-webui:main`) on `:3000` wired to this Ollama instance.

## License

Apache-2.0
