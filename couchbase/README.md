# couchbase

[Couchbase Server](https://www.couchbase.com), single node, defined in
`compose.yml`.

## Images

`couchbase:community` runs Community Edition, free in production for clusters
of up to five nodes, without XDCR. The untagged image is Enterprise Edition,
free only for development and testing; production needs a paid subscription.
Upstream publishes no moving major tag for Community, so `community` tracks
the newest Community release (8.0.x at the time of writing) and moves to the
next major when one ships.

## Networking

Clients connect to Couchbase directly on its ports, not through a domain on the
proxy, so it publishes them on the host:

| Ports | Purpose |
| --- | --- |
| `8091-8097` | Cluster manager, views, query, search, analytics, eventing |
| `18091-18097` | The same, over TLS |
| `11207`, `11210` | Data service (TLS, plain) |
| `11280`, `9123` | Internal services |

The admin console is on `8091`. Complete the first-run setup there.

## Storage

`couchbase-data` at `/opt/couchbase/var` — data, indexes, config, logs.
