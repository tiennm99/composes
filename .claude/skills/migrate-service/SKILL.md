---
name: migrate-service
description: Move a running Coolify deployment — typically a one-click Service template or a hand-made app — onto the app built from a service directory in this repo, keeping its data. Finds both resources through the Coolify MCP, copies named volumes with docker, and walks env, domain, watch path, deploy and verification. Use when the user wants to migrate, move or switch an old deployment to the composes-repo version. Not for first-time deploys with no data, nor for debugging a service (debug-service).
---

# Migrate a service onto the composes repo

Carry one service's data and settings from an existing Coolify resource (the
**old** one) to the Coolify app built from `<service>/` in this repo (the
**new** one), so the new app resumes exactly where the old one stopped. The
old resource stays intact until the user deletes it; it is the rollback.

## Boundaries

- Never read Coolify's stored env files or any `.env` holding real values, and
  never print secrets. The Coolify MCP shows env key names only; values are
  copied by the user in the Coolify UI.
- Ask before `control` stop/start and before `deploy`. Volume copies overwrite
  the new resource's data: show the dry run and get confirmation before
  `--apply`.
- Delete nothing of the old resource. Deleting it, its volumes, or the backup
  volume happens only when the user asks, after verification.

## 1. Identify both resources

Read `<service>/compose.yml` and `<service>/README.md`. Then
`search_resources` with the service name on every Coolify MCP server
(`miti-jp`, `miti-sg`). The old one is usually a Service (`get_service`,
`list_service_applications`, `list_service_databases`); the new one is an
Application whose `git_repository` is this repo and `base_directory` is
`/<service>`. If the new app does not exist, the user creates it first —
it must have deployed once so its volumes exist.

For each, collect: uuid, server, status, domain (`fqdn` on the old service's
application, `docker_compose_domains` on the new app), `watch_paths`,
`list_storages`, `list_env_keys`.

## 2. Compare layouts before copying

Build a table: old volume and mount path → new volume and mount path. Volumes
are named `<uuid>_<compose-volume-name>`. Check, against the new compose file:

- Paths the old deployment used that the new layout moves (a config file or
  skills dir that was outside a volume, or in a separate volume the new compose
  folds into another). Inspect contents read-only to see where things really
  live:
  `docker run --rm -v <vol>:/v:ro alpine sh -c 'du -sh /v; ls -la /v'`.
- Database images: a raw copy of a data directory needs the same engine major
  version (e.g. `pgvector:pg18` → `pg18`). On a mismatch, stop and dump/restore
  instead.
- Env keys: list keys present on the old resource and missing or differing on
  the new. Flag the keys that must carry the **same value**: encryption keys
  (stored data becomes unreadable otherwise) and database user, password and
  name (they live inside the copied data directory).

## 3. Stop both resources

Confirm with the user, then stop the old and the new resource (`control`
action `stop`, `confirm: true`). The copy refuses to run while any container
mounts a volume it touches.

## 4. Copy volumes

The volumes must be on the Docker host this workspace talks to; check with
`docker volume ls | grep -E '<old-uuid>|<new-uuid>'`. If they are not, the
service runs on another server: give the user the commands to run in that
server's Coolify terminal instead.

```bash
scripts/migrate-volumes.sh --from <old-uuid> --to <new-uuid> [--map old=new ...]
scripts/migrate-volumes.sh --from <old-uuid> --to <new-uuid> [--map old=new ...] --apply
```

Dry run first; show its output. It pairs volumes by name, skips empty source
volumes, and lists unmatched ones — use `--map` when a name differs, or note
the volume as intentionally dropped. With `--apply`, each target volume is
archived into the volume `migrate-backup-<new-uuid>`, emptied, then filled
from the source; it prints `OK` when entry counts match, `DIFF` otherwise.
A file that must land in a subdirectory of another volume is a one-off
`docker run ... cp -a` after the script, shown to the user first.

Mount only Docker volumes or host paths in `docker run -v`. This workspace is
itself a container: a workspace path given to `-v` resolves on the host, not
here, so backups go into a volume.

## 5. Settings in the Coolify UI (user)

Give the user one checklist:

- Env values to copy from old to new, with the must-match keys from step 2
  marked. Any optional variable the old one used that the new compose keeps
  commented out needs uncommenting in `<service>/compose.yml`.
- Domain: remove it from the old resource, then set it on the new app's
  container, keeping the port suffix (`https://host:PORT`).
- Watch path on the new app: `<service>/**`.

## 6. Deploy and verify

Once the user confirms the settings, `deploy` the new app (ask first). Then
check the deployment finished (`list_deployments`, `get_deployment` with
`include_log_summary`), the status is healthy, `get_logs` shows no auth,
decrypt or migration errors, and the domain answers. Ask the user to confirm
their data is there in the app itself.

## 7. Wrap up

Report what moved and where the backup volume is. Leave the old resource
stopped. When the user is satisfied, they may ask to delete the old resource
(in Coolify, with its volumes) and `migrate-backup-<new-uuid>`.

If the service's README describes setup in a way the migration proved wrong,
update it.

## Resources

- `scripts/migrate-volumes.sh` — pairs, backs up and copies named volumes
  between two Coolify resources; dry run by default.
