# TODO

## Names that differ from the upstream Docker guide

Renaming a volume on a running deployment orphans its data, so each rename
needs a volume migration (the `migrate-service` skill), not just an edit.

- [ ] `owncloud` — upstream names its volumes `oc_files`, `mysql` and `redis`;
      here they are `owncloud-data`, `owncloud-mysql-data` and
      `owncloud-redis-data`.
- [ ] `litellm` — upstream's database service is `db` with volume
      `postgres_data`; here it is `postgres` with `pg-data`.
- [ ] `openclaw` — upstream's service is `openclaw-gateway`; here it is
      `openclaw`. Upstream uses bind mounts, so the volume names are free.
- [ ] `gitea` — Gitea's install guide names the app service `server`; here it
      is `gitea`. Confirm against the current guide before renaming.

## README contradiction

- [ ] `code-server-lsio/README.md` says the `universal-docker` mod adds `abc` to
      the Docker socket's group, so `docker` works without `sudo`.
      `webtop/README.md` says `abc` is not in that group and must use `sudo`.
      Both use the same mod; check which is true and fix the other.
