# karakeep

[Karakeep](https://docs.karakeep.app): a self-hosted bookmark and
read-it-later app that tags and summarizes saved links with an LLM.

Three containers:

- `karakeep`: the web app and background workers, serving on port `3000`.
  It keeps its SQLite database and saved assets under `/data`.
- `browser`: headless Chrome that crawls pages and takes screenshots.
- `search`: Meilisearch, for full-text search.

## Setup

1. Set `NEXTAUTH_SECRET`, `MEILI_MASTER_KEY` and `NEXTAUTH_URL`.
2. Set the AI provider variables (see below).
3. Map the domain to port `3000` and deploy.
4. Open the domain and sign up. The first account becomes the admin.
5. Set `DISABLE_SIGNUPS=true` and redeploy.

Health check: `GET /api/health`, built into the image.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `NEXTAUTH_SECRET` | — | Signs login sessions |
| `NEXTAUTH_URL` | — | Public URL, used in auth redirects and links |
| `MEILI_MASTER_KEY` | — | Meilisearch key, shared by `karakeep` and `search` |
| `DISABLE_SIGNUPS` | `false` | Blocks new accounts, including the first one |
| `OPENAI_API_KEY` | empty | Provider key; empty turns AI tagging off |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | OpenAI-compatible endpoint |
| `INFERENCE_TEXT_MODEL` / `INFERENCE_IMAGE_MODEL` | `gpt-6-luna` / `gpt-4o-mini` | Models for text and image tagging |
| `INFERENCE_LANG` | `english` | Language of the generated tags |
| `INFERENCE_ENABLE_AUTO_SUMMARIZATION` | `false` | Summarize every saved link |
| `CRAWLER_FULL_PAGE_ARCHIVE` | `false` | Store a full offline copy of every page |
| `MAX_ASSET_SIZE_MB` | `50` | Upload size limit |

`DISABLE_SIGNUPS` starts `false` because it also blocks the first sign-up, so
the admin account has to be created before it is turned on.

The AI variables are always passed, so each needs a valid value: Karakeep
refuses to start on an empty `OPENAI_BASE_URL` and sends an empty model name
as-is. Their defaults are OpenAI's endpoint and upstream's default models.
Another provider needs all three changed to its endpoint and model names.
With an explicit base URL, Karakeep does not turn on embedding-based search
by itself.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `karakeep-data` | `/data` | SQLite database, screenshots, archives and uploads |
| `search-data` | `/meili_data` | Meilisearch index, rebuildable from Karakeep |

Back up `karakeep-data`. The search index can be rebuilt from the admin
settings.

## Images

`ghcr.io/karakeep-app/karakeep:release` and `karakeep-chrome:release` are
upstream's stable moving tags; `latest` is built from every commit on `main`.

`getmeili/meilisearch` is pinned to the version upstream's compose file uses.
A newer Meilisearch refuses to open an index written by an older one, so a
moving tag would break search on the next pull. Bump it together with
upstream, setting `MEILI_UPGRADE_DB=true` on `search` for the first start.
