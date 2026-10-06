# Docker logs re-sent on restart

Applies to `alloy/compose.yml`. Checked against Alloy v1.20.1.

## Symptom

Every time Alloy restarts, `loki.write` logs one rejected batch:

```
final error sending batch, no retries left, dropping data ... status=400
13 errors like: entry for stream '{container="coolify-realtime", ...}'
has timestamp too old: 2026-09-18T17:00:51Z, oldest acceptable timestamp is: ...
```

The same containers, the same timestamps and the same counts show up on every
restart.

## Cause

`loki.source.docker` saves each container's read position as a Unix timestamp
in **seconds** (`internal/component/loki/source/docker/tailer.go`,
`t.positions.Put(..., ts.Unix())`). On start it asks the Docker API for logs
`since` that second, and Docker includes the second itself. So every restart
re-reads every line written in the container's last logged second.

For a busy container those lines are recent, and Loki silently discards them
as exact duplicates. For an idle container whose last line is more than 7 days
old, Grafana Cloud Loki rejects them with `timestamp too old` instead.
Positions are kept in the `alloy-data` volume, so they are not being lost.
Re-reading that last second is simply how the component works.

## Fix

`loki.process "logs_integrations_docker"` sits between `loki.source.docker` and
`loki.write` and drops lines older than `168h` with `stage.drop`. Those lines
would be rejected by Loki anyway, so nothing that would have been stored is
lost. The drops are counted under `loki_process_dropped_lines_total{reason="too_old"}`.
