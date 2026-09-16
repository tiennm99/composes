# ollama

[Ollama](https://ollama.com) LLM server. CPU-only.

Uses `docker-compose.yml`, publishes `11434`, and sets
`restart: unless-stopped` and `container_name: ollama` — unlike the
platform-managed services described in the [root README](../README.md).

## Usage

```sh
docker compose exec ollama ollama pull llama3.2
docker compose exec ollama ollama run llama3.2
```

The API is on `http://localhost:11434`:

```sh
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

For GPU, add `deploy.resources.reservations.devices` for the NVIDIA runtime —
see the [Ollama Docker docs](https://hub.docker.com/r/ollama/ollama).

## Storage

`ollama` at `/root/.ollama` — pulled models and manifests.
