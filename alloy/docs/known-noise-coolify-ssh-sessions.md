# Known Noise: Coolify SSH Session Spam

> **Skip this doc** if you don't use [Coolify](https://coolify.io/) to manage the host. This is a special case for our setup, not a general issue.

## Symptom

Grafana Loki shows a constant stream of `info`-level lines on the **Linux Node** dashboard:

```
Session closed
New session NNNNN of user root.
```

Labels: `instance=<host>`, `job=integrations/node_exporter`, `level=info`, `unit=systemd-logind.service` (or `session-NNN.scope`).

Rate observed on a Coolify-managed host: **~300 sessions/hour ≈ 5/min**, in bursts of 2–3 within the same second.

## Cause

The Coolify host SSHes into each managed server every minute to check reachability and collect Docker container state. Each SSH connect → PAM `session opened` + `session closed` → systemd-logind writes it to the journal → `loki.source.journal` ships it to Grafana Cloud.

The **misleading part**: the label `job=integrations/node_exporter` makes it look like node_exporter emitted the log. It didn't. node_exporter only produces metrics — the journal-log pipeline reuses that label so the logs land on the same dashboard.

## Exact Coolify call flow (verified against source)

`coollabsio/coolify` v4.x — `app/Console/Kernel.php` and `app/Jobs/ServerManagerJob.php`:

1. **`ServerManagerJob` runs every minute** (self-hosted) or every 5 minutes (Cloud).
2. Per managed server, per cycle, it dispatches:

| Job | What it does over SSH | Skip condition |
|---|---|---|
| `ServerConnectionCheckJob` | Opens SSH, runs reachability probe | `isSentinelEnabled() && isSentinelLive()` |
| `ServerCheckJob` | Opens SSH, runs `docker container ls --format json` + proxy/log-drain checks | Sentinel "in sync" — last push within `sentinel_push_interval_seconds × 3` (min 120s) |
| `ServerStorageCheckJob` | Opens SSH, reads filesystem usage | Daily cron only (`0 23 * * *`), and only when Sentinel out of sync |
| `ServerPatchCheckJob` | Opens SSH, checks patch info | Weekly only (`0 0 * * 0`) |
| `CheckAndStartSentinelJob` | Opens SSH to (re)start the Sentinel container | Daily only |

= **roughly 2–3 SSH connects per minute per server** when Sentinel is OFF (matches the 5/min × bursts pattern in our journal).

3. The only built-in throttle is `shouldSkipDueToBackoff` — it backs off to every 3 / 6 / 12 minutes only **after the server has been marked unreachable** several times. There is **no UI setting to slow checks on a healthy server**.

## How to confirm on your host

```bash
# Top sources of SSH sessions in the last hour
sudo journalctl _COMM=sshd --since "1 hour ago" \
  | grep "Accepted" | grep -oE "from [0-9.]+" | sort | uniq -c | sort -rn | head

# Match the SSH key fingerprint to its owner — replace fingerprint
while read -r line; do
  fp=$(echo "$line" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')
  [[ "$fp" == "SHA256:<paste-fingerprint-here>" ]] && echo "MATCH: $line"
done < /root/.ssh/authorized_keys
```

If the matching key's comment is `coolify` → this doc applies.

## Fixes (pick one)

### Option A — drop the noise at Alloy (host stays as-is)

Edit the `loki.process "default"` block inside `journal_module` in `docker-compose.yml`:

```alloy
loki.process "default" {
    forward_to = argument.forward_to.value

    stage.drop {
        expression = "(session opened|session closed|New session|Removed session) .*"
    }
}
```

Restart: `docker compose up -d --force-recreate alloy`.

Trade-off: also loses visibility of legitimate human SSH logins. Narrow to `unit="systemd-logind.service"` or to a specific source IP if you want to keep auditing real users.

### Option B — eliminate the SSH polling at Coolify (recommended root-cause fix)

Enable **Sentinel** on the managed server. Sentinel is a small `coolify-sentinel` container that *pushes* metrics to the Coolify API. When it's healthy, `ServerManagerJob` **skips both `ServerConnectionCheckJob` and `ServerCheckJob`** for that server — SSH polling stops.

**Steps in the Coolify UI:**

1. Go to **Servers → `<your server>` → Configurations → General**.
2. Toggle **Sentinel** on. Optionally toggle **Metrics** in the same section if you want CPU/mem/disk pushed too.
3. Save. Coolify will deploy the `coolify-sentinel` container on the target server.
4. Wait ~2 minutes. Verify on the server: `docker ps | grep coolify-sentinel`.
5. Re-check the journal — SSH session rate should drop to occasional (daily Sentinel restart, weekly patch check, on-demand deploys), not ~5/min.

**Tunable:** `sentinel_push_interval_seconds` in the server's settings controls push cadence and the SSH-skip window (skip if last push within `× 3`, min 120s). Lower = fresher metrics, slightly more API traffic from Sentinel.

**Caveats:** Sentinel is flagged "experimental" in the Coolify docs. Metrics collection is **not** available for Docker Compose / Service-Template-based deployments — but Sentinel itself (connectivity + container status) still works.

## Why we don't ship a filter by default

The base setup is meant to be a generic Grafana Cloud Linux/Docker integration. Coolify-specific filtering belongs in a host-specific overlay, not in the shared compose file.

## References

- Coolify Sentinel docs: <https://coolify.io/docs/knowledge-base/server/sentinel>
- DeepWiki — Server Monitoring: <https://deepwiki.com/coollabsio/coolify/3.5-server-monitoring-(sentinel-and-metrics)>
- Source: [`app/Console/Kernel.php`](https://github.com/coollabsio/coolify/blob/v4.x/app/Console/Kernel.php), [`app/Jobs/ServerManagerJob.php`](https://github.com/coollabsio/coolify/blob/v4.x/app/Jobs/ServerManagerJob.php), [`app/Jobs/ServerCheckJob.php`](https://github.com/coollabsio/coolify/blob/v4.x/app/Jobs/ServerCheckJob.php)
