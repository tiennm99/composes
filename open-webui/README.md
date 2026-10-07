# open-webui

[Open WebUI](https://docs.openwebui.com): a chat UI for OpenAI-compatible and
Ollama model providers, with users, chat history, documents and RAG.

One container, serving on port `8080`. It stores everything in SQLite and a
local vector database under `/app/backend/data`.

## Setup

1. Set `WEBUI_SECRET_KEY`.
2. Map the domain to port `8080` and deploy.
3. Open the domain. The first account to sign up becomes the admin.
4. Add model connections in **Admin Settings → Connections**.

Health check: `GET /`, also the compose healthcheck.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `WEBUI_SECRET_KEY` | — | Signs login tokens and encrypts stored secrets |
| `BYPASS_MODEL_ACCESS_CONTROL` | `true` | Every user sees every model |
| `OPENAI_API_BASE_URL` / `OPENAI_API_KEY` | optional | OpenAI-compatible connection seeded on first start |
| `OLLAMA_BASE_URL` | optional | Ollama connection seeded on first start |

`WEBUI_SECRET_KEY` is required. Without it, `start.sh` generates a key into
`/app/backend/.webui_secret_key`, outside the data volume, so every
recreated container gets a new key: everyone is logged out, and anything
encrypted with the old key can no longer be read.

`BYPASS_MODEL_ACCESS_CONTROL` is on because this is a single-person instance:
models do not need to be shared with users one by one.

The connection variables are optional because Open WebUI keeps its
connections in the database. They seed it only on first start, so once
connections exist the admin UI is where they change.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `open-webui-data` | `/app/backend/data` | `webui.db`, uploads, the vector database, and model cache |

## Image

`ghcr.io/open-webui/open-webui:latest` is the latest release. Upstream
publishes no major tag; `main` is built from every commit on the development
branch, so `latest` is the stable moving tag.
