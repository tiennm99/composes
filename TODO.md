# TODO

## Supporting service and volume names

Supporting containers take a role name — `db` for a database, `cache` for
Redis-like stores — and volumes are `<service>-<what it holds>`. Renaming a
volume on a running deployment orphans its data, so each rename needs a volume
migration (the `migrate-service` skill), not just an edit. A service rename
also changes the hostname other containers reach it by. Update the service
README in the same change.

- [ ] `litellm` — service `postgres` → `db` and volume `pg-data` → `db-data`;
      service `redis` → `cache` and volume `redis-data` → `cache-data`. Point
      `DATABASE_URL` at `db` and `REDIS_HOST` at `cache`.
- [ ] `owncloud` — service `mariadb` → `db` and volume `owncloud-mysql-data` →
      `db-data`; service `redis` → `cache` and volume `owncloud-redis-data` →
      `cache-data`. Point `OWNCLOUD_DB_HOST` at `db` and `OWNCLOUD_REDIS_HOST`
      at `cache`.
- [ ] `goclaw` — service `postgres` → `db` and volume `postgres-data` →
      `db-data`. Point the host in `GOCLAW_POSTGRES_DSN` at `db`.
- [ ] `couchbase` — volume `couchbase_data` → `couchbase-data`.
- [ ] `open-webui` — volume `open-webui` → `open-webui-data`.
