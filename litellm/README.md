# litellm

[LiteLLM](https://docs.litellm.ai) proxy: one OpenAI-compatible endpoint in
front of many LLM providers, with virtual keys, spend tracking and an admin UI
at `/ui`.

Three containers: `litellm`, `postgres` for keys, teams, budgets and spend
logs, and `redis` for the response cache.

## Setup

1. Set `LITELLM_MASTER_KEY`, `UI_PASSWORD`, `POSTGRES_PASSWORD`,
   `OPENROUTER_API_KEY` and `GEMINI_API_KEY`. Uncomment any other provider key
   whose models you use, in both `compose.yml` and the environment.
2. Map the domain to port `4000` and deploy. Prisma migrations run on start.
3. Open `/ui` and log in with `UI_USERNAME` / `UI_PASSWORD`.

Health check: `GET /health/liveliness`, also the compose healthcheck.

## Models

`config.yaml` holds the model list, the `model_group_alias` routing and the
proxy settings; it is mounted read-only at `/app/config.yaml`. Editing it
redeploys the service. Every provider key in it is an `os.environ/` reference,
so the file carries no secrets.

Models can also be added in the admin UI. `STORE_MODEL_IN_DB` keeps those in
PostgreSQL, so they survive a redeploy without touching the file.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `LITELLM_MASTER_KEY` | — | Admin API key; must start with `sk-` |
| `UI_USERNAME` / `UI_PASSWORD` | `admin` / — | Admin UI login |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `litellm` / — / `litellm` | Database credentials, read by both containers |
| `OPENROUTER_API_KEY` | empty | OpenRouter models, including `openrouter-free`, the alias target |
| `GEMINI_API_KEY` | empty | Gemini chat models and `gemini-embedding-001` |
| `STORE_MODEL_IN_DB` | `True` | Keep UI-added models in PostgreSQL |
| `LITELLM_MODE` | `PRODUCTION` | Skips loading a `.env` inside the container |
| `LITELLM_LOG` | `ERROR` | Log level |
| `TOKENROUTER_API_KEY`, `ORCAROUTER_API_KEY`, `KIMI_API_KEY`, `MINIMAX_API_KEY`, `KILO_API_KEY`, `OPENCODE_API_KEY`, `NVIDIA_NIM_API_KEY`, `OLLAMA_API_KEY` | optional | Keys for the other providers in `config.yaml` |
| `CLOUDFLARE_API_KEY` / `CLOUDFLARE_ACCOUNT_ID` | optional | For the commented-out Cloudflare model |

`LITELLM_MASTER_KEY` and `UI_PASSWORD` fail fast if unset: the master key is
the only thing between the domain and every provider key behind the proxy.

`REDIS_HOST` and `REDIS_PORT` are fixed in `compose.yml`, as properties of this
layout. Redis runs without a password; it is reachable only on the stack's
own network.

OpenRouter and Gemini stay active because the rest of this setup leans on
them: every `model_group_alias` routes to `openrouter-free`, and
`gemini-embedding-001` serves embeddings. The other providers are optional. An
unset key disables only the models that reference it — LiteLLM starts and
passes its health check with every provider key unset — so a provider is
enabled by uncommenting its line, without touching `config.yaml`.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `pg-data` | `/var/lib/postgresql/data` | The database |
| `redis-data` | `/data` | Redis append-only file |

## Images

`ghcr.io/berriai/litellm-database:main-stable` is the variant with the Prisma
client for PostgreSQL built in. `main-stable` is upstream's moving stable tag.

`postgres:16-alpine` and `redis:7-alpine` track their major versions. Moving
PostgreSQL to a new major needs a dump and restore; the data directory does
not carry across majors.

## Resources

`litellm` is capped at 4 GB of memory. Gunicorn runs two workers and recycles
each after 1000 requests, which bounds the slow memory growth of long-lived
LiteLLM workers.
