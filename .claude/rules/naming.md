# Naming

## File naming

Every service uses `compose.yml` — the current Compose spec name, and the
shorter one. Not `docker-compose.yml`.

## Names

A service directory is named after the software it runs. When two services
package the same software, the one that is not upstream's own image takes a
suffix naming its source — `code-server-lsio` for LinuxServer's code-server —
so both can coexist. The suffix is a directory name only, forced by the
conflict; it is not a name to copy anywhere else.

Prefer each tool's official image, for the main service and for every
supporting container alike. Upstream's official compose file or Docker guide
is a starting point, not a spec: adapt it to the conventions in these rules
rather than copying its layout and names as they are.

Inside `compose.yml`, the main service is named after its image —
`code-server`, not `code-server-lsio`. Where the image's repository name is not
the software's (`traffmonetizer/cli_v2`), use the software's name
(`traffmonetizer`). A supporting container is named for its
role, so the software behind it can be swapped without renaming: `db` for any
database, `cache` for Redis, Valkey or Memcached, and a short role name such as
`dockerproxy` for anything else (see the examples below). Swapping Redis for
Valkey, MySQL for MariaDB, or one SQL database for PostgreSQL then leaves every
name, hostname and volume as it is.

Role names in use or likely, as examples only — any short name that says what
the container does is fine, and this list does not limit the choice:

| Role name | Typical software |
| --- | --- |
| `db` | PostgreSQL, MySQL, MariaDB, MongoDB, pgvector |
| `cache` | Redis, Valkey, Memcached, KeyDB, Dragonfly |
| `queue` / `broker` | RabbitMQ, NATS, Kafka |
| `search` | Elasticsearch, OpenSearch, Meilisearch, Typesense |
| `vector` | Qdrant, Weaviate, Milvus, when separate from `db` |
| `storage` | MinIO, SeaweedFS, Garage — S3-compatible object storage |
| `worker` | The app's own image running background jobs |
| `scheduler` / `cron` | The app's own image running timed jobs |
| `migrate` / `init` | One-off setup jobs that run and exit |
| `dockerproxy` | `tecnativa/docker-socket-proxy` |
| `proxy` | A reverse proxy inside the app, such as nginx or Caddy |
| `mail` / `smtp` | Mailpit, a Postfix relay |
| `browser` | Headless Chrome (browserless), for agents |
| `tunnel` | cloudflared |
| `backup` | A database dump or volume backup running alongside |

A volume is named `<service>-<what it holds>`, after the service that mounts it
and its mount point or meaning — `code-server-home`, `code-server-workspace`,
`db-data`, `cache-data`.

Services declare no networks. Coolify creates one per app and attaches every
container to it, so there is nothing to add. Should a service ever need its own,
it is named after the main service: `code-server-network`.
