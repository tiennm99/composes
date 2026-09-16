# couchbase

[Couchbase Server](https://www.couchbase.com), single node.

Uses `docker-compose.yml`, publishes ports, and sets `restart: unless-stopped`
and `container_name: db` — unlike the platform-managed services described in
the [root README](../README.md).

## Networking

| Ports | Purpose |
| --- | --- |
| `8091-8097` | Cluster manager, views, query, search, analytics, eventing |
| `18091-18097` | The same, over TLS |
| `11207`, `11210` | Data service (TLS, plain) |
| `11280`, `9123` | Internal services |

The admin console is on `8091`. Complete the first-run setup there.

## Storage

`couchbase_data` at `/opt/couchbase/var` — data, indexes, config, logs.
