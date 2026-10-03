# Mirror failure taxonomy

Reference detail for `gitea-mirror-maintenance`. Load when a failure does not
fit cases A-E, when adding a detection signal, or when a cleanup run misbehaves.

## Why four signals

Each signal is blind to what the others see. Verified on this stack:

| Signal | Catches | Misses |
|---|---|---|
| API `empty:true` | partial and zero-byte initial migrations | repos with content whose sync is failing |
| upstream probe | deleted or renamed GitHub sources | nothing on its own — it only qualifies other signals |
| gitea-mirror API `status: failed` | interrupted runs after a container restart | failures Gitea never reported back to the app |
| gitea container log | live periodic-sync errors | anything older than the log retention window |

An audit using only the container log found **1** problem repo. The API scan
over the same stack found **8**. The log reflects a retention window, not
history, so it must never be the sole basis for deletion.

## The partial-clone signature

The non-obvious case. A large repo whose migration is interrupted mid-transfer
leaves:

- `empty: true` and `default_branch` set but no refs
- `size` in the hundreds of MB — the packfiles arrived, the refs did not
- `mirror_updated` = `0001-01-01` (never successfully pulled)

Gitea reports it as empty because no commit is reachable. The bytes stay on
disk, unreachable and never garbage-collected. Five such repos held ~2 GB.

`size > 0` therefore does **not** mean a repo is healthy.

## Partial clone vs clone in progress

These are indistinguishable from Gitea's API alone — both are `empty: true`
with `mirror_updated` unset, and a partial clone can sit at `size` 0 just like a
fresh one. The mirror app's `status` column is the only discriminator:

| gitea-mirror status | Meaning | Case |
|---|---|---|
| `mirroring` | actively cloning right now | E — leave alone |
| `imported` | discovered, queued, not yet attempted | E — leave alone |
| `mirrored` | app believes the pull completed | A/B — genuinely broken |
| `failed` | app recorded a failure | A/B if empty, D if populated |

An empty repo that the app calls `mirrored` is a contradiction, and that
contradiction is the reliable failure signal. Verified on this stack: eight
repos with status `mirrored` were empty and genuinely broken, while
`AUTOMATIC1111/stable-diffusion-webui` was empty at status `mirroring` and
completed normally minutes later. Classifying on API fields alone would have
destroyed an in-flight clone of a very large repository.

This also means plans expire. Always re-run detect right before applying.

## Interrupted-mirror errors

Rows carrying:

```
Detected interrupted mirror: status was stuck at "mirroring" (the application
was likely restarted or crashed mid-operation). The status was reset
automatically; the next scheduled run will retry
```

are self-healing. The app already reset them. Do not delete these — verify the
repo in Gitea first. If it has content, it is case D (retry only). If empty,
case A applies.

## Batch API failures

`gitea-mirror` may log a summary such as:

```
Warning: 447 Gitea API requests failed with non-timeout errors.
```

This indicates a batch of migrations died together and usually correlates with
a cluster of case A repos. Use it as a hint that a full API scan is worthwhile,
not as a repo list — it names no repositories.

Do not confuse it with the repair summary, which is informational:

```
Repository repair summary: checked=285, repaired=0, skipped=285, errors=0
```

## Adding a signal

Extend `detect-failed-mirrors.sh`:

1. Collect the signal into a JSON object keyed by lower-cased `owner/name` and
   pass it to the classification `jq` program with `--slurpfile`.
2. Classify into an existing case, or add a case with an explicit `action` of
   `delete`, `delete+retry`, `retry`, or `report-only`.
3. Emit it through `entry(case; action; reason)`, which fills `full_name`,
   `owner`, `name`, `size_MB`, `mirror_status` and `mirror_id`.

`cleanup-failed-mirrors.sh` dispatches purely on the `action` string, so a new
case needs no cleanup change as long as it reuses an existing action. Default
new work to `report-only` until the classification is proven against real data.

## Recovery notes

- **Deleted a repo that should have been kept.** The mirror is gone. Re-mirror
  it from the gitea-mirror UI, or `POST /api/job/retry-repo` with its id. The
  GitHub source is authoritative, so nothing unique is lost for a true mirror.
- **Retried a repo but it never returns.** Check gitea-mirror's activity log in
  its UI, and confirm the repo is not among the disabled ones — the scheduler
  logs `Skipped N disabled GitHub repositories`.
- **Delete fails with 404.** Already gone; the plan is stale. Re-run detect.
- **Delete times out.** `tea` is waiting on stdin. Confirm `--force` is passed
  and stdin is closed (`</dev/null`).
