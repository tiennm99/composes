# ollama-docker-compose

Docker Compose setup for running [Ollama](https://ollama.com) (optionally with a web UI) locally.

## Quick start

```bash
docker compose up -d
```

Ollama API at `http://localhost:11434`. Pull a model:

```bash
docker compose exec ollama ollama pull llama3.2
```

## License

Apache-2.0
