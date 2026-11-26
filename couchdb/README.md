# couchdb

[Apache CouchDB](https://couchdb.apache.org) from the official image, set up as
the server for the [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync)
Obsidian plugin.

## Setup

1. Set `COUCHDB_USER` and `COUCHDB_PASSWORD`.
2. Map the domain to port `5984` and deploy.
3. Check it answers: `curl -u "$COUCHDB_USER:$COUCHDB_PASSWORD" https://<couchdb>.example.com/_up`
   returns `{"status":"ok",...}`.
4. In Obsidian, install Self-hosted LiveSync and point it at
   `https://<couchdb>.example.com` with the same login and a database name such
   as `obsidiannotes`. The plugin's setup creates the database.

Port `5984` serves plain HTTP and must sit behind the proxy: Obsidian on
mobile only connects over HTTPS with a valid certificate.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `COUCHDB_USER` / `COUCHDB_PASSWORD` | — | Admin login, used by the plugin too |

Both are required. Every request needs a login (`require_valid_user`), so the
database is not readable without them.

## Configuration

`livesync.ini` carries the server settings that LiveSync's own provisioning
script applies through the REST API: single node, login required on every
request, CORS for the Obsidian desktop and mobile origins, and large documents
and requests. Baking them into the image makes a fresh deploy ready with no
init step. The file goes to `etc/default.d/`, which leaves the image's own
`local.ini` untouched; anything changed later through the API lands in
`etc/local.d/`, which loads last and wins over it.

Cloudflare's proxy caps one request at 100 MB, below `max_http_request_size`.
LiveSync splits notes and attachments into small chunks, so normal syncing
stays far under it.

## Storage

| Volume | Mount | Holds |
| --- | --- | --- |
| `couchdb-data` | `/opt/couchdb/data` | Databases |
| `couchdb-config` | `/opt/couchdb/etc/local.d` | Settings written by the entrypoint and the API |

## Image

`couchdb:3` is the official moving tag for CouchDB 3.
