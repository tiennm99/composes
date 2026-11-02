# guacamole

[Apache Guacamole](https://guacamole.apache.org/): remote desktops (RDP, VNC,
SSH) in the browser, with users and connections stored in PostgreSQL.

## Services

| Service | Image | Internal port | Domain |
| --- | --- | --- | --- |
| `init` | `guacamole/guacamole:1.6.0` | none | none |
| `db` | `postgres:18-alpine` | 5432 | none |
| `guacd` | `guacamole/guacd:1.6.0` | 4822 | none |
| `guacamole` | `guacamole/guacamole:1.6.0` | 8080 | the web UI |

`init` writes Guacamole's PostgreSQL schema to the `db-init` volume and
exits; `db` starts after it and runs the schema once, on an empty data
directory. `guacamole` waits for `db` to pass its health check.

## Running on a desktop instead of Coolify

To reach the desktop the stack runs on, run it there with plain
`docker compose` and add a gitignored `compose.override.yml` next to
`compose.yml` that publishes the UI on loopback only:

```yaml
services:
  guacamole:
    ports:
      - "127.0.0.1:8080:8080"
```

A tunnel on that host (for example cloudflared, behind an access policy) then
points at `http://localhost:8080`.

## Variables

| Variable | Feeds | Notes |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | `db`, `guacamole` | Defaults to `guacamole`; `db` has no published port. |

## Usage

1. Open the UI and log in as `guacadmin` / `guacadmin`.
2. Create your own administrator, log in as it, and delete `guacadmin`.
3. Add connections. For an RDP server on the Docker host, use hostname
   `host.docker.internal`; `guacd` maps it to the host gateway.

For GNOME Remote Desktop, set security mode to NLA, turn on "Ignore server
certificate", and leave the graphics pipeline enabled: GNOME closes
connections from clients that do not offer it.

## Choices

- **`1.6.0`, pinned exactly.** It is the first release with the RDP Graphics
  Pipeline that GNOME Remote Desktop requires. Upstream publishes no major
  tag, and its `latest` tag is a development build from the main branch,
  amd64 only, so it does not run on ARM hosts.
- **`postgres:18-alpine`.** The major stays pinned, because a new major
  cannot read an existing data directory without a dump and restore. From 18
  the image keeps its data in `/var/lib/postgresql/18/docker`, so `db-data`
  mounts at `/var/lib/postgresql`.
- **`init` sets `restart: "no"`.** It is a one-off job; `unless-stopped`
  would rerun it after every exit.
- **Served at `/`** (`WEBAPP_CONTEXT=ROOT`) instead of upstream's
  `/guacamole/` path.

## Storage

| Volume | Holds |
| --- | --- |
| `db-init` | The generated schema script, rewritten by `init` on every start |
| `db-data` | PostgreSQL data, under `18/docker` |
