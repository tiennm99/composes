#!/usr/bin/env bash
# Read-only audit of Gitea mirrors. Classifies failing mirrors into cases A-E
# and writes a JSON plan for cleanup-failed-mirrors.sh. Changes nothing.
#
# Usage: detect-failed-mirrors.sh --login <tea-login> [--gitea-log FILE] [--out FILE]
# Env:   GITEA_MIRROR_URL, GITEA_MIRROR_API_KEY (gitea-mirror API access)
set -euo pipefail

LOGIN=""
GITEA_LOG=""
OUT="${TMPDIR:-/tmp}/gitea-mirror-failed-plan.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --login) LOGIN="$2"; shift 2 ;;
    --gitea-log) GITEA_LOG="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$LOGIN" ] || { echo "--login is required (see: tea login list)" >&2; exit 2; }
for c in tea jq curl; do command -v "$c" >/dev/null || { echo "missing: $c" >&2; exit 2; }; done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# tea from a neutral directory, with no stdin and a timeout.
tea_api() { (cd "$WORK" && timeout 60 tea api --login "$LOGIN" "$@" </dev/null); }

# Signal 1: every repository the login can see.
echo "Scanning Gitea repositories..." >&2
page=1
while :; do
  tea_api "/repos/search?limit=50&page=$page" | jq '.data' > "$WORK/page-$page.json"
  [ "$(jq length "$WORK/page-$page.json")" -gt 0 ] || break
  page=$((page + 1))
done
jq -s 'add // []' "$WORK"/page-*.json > "$WORK/repos.json"
jq -r '"  \(length) repos, \(map(select(.mirror)) | length) mirrors, \(map(select(.empty)) | length) empty"' "$WORK/repos.json" >&2

# Signal 3: gitea-mirror's own status per repository, keyed by Gitea full name.
echo "Querying gitea-mirror API..." >&2
echo '{}' > "$WORK/app.json"
if [ -n "${GITEA_MIRROR_URL:-}" ] && [ -n "${GITEA_MIRROR_API_KEY:-}" ]; then
  curl -fsS --max-time 60 -H @<(printf 'x-api-key: %s\n' "$GITEA_MIRROR_API_KEY") \
    "${GITEA_MIRROR_URL%/}/api/github/repositories" |
    jq '[.repositories[] | select(.mirroredLocation != null and .mirroredLocation != "")
         | {key: (.mirroredLocation | ascii_downcase),
            value: {id, status, error: ((.errorMessage // "")[0:160])}}] | from_entries' \
    > "$WORK/app.json"
  jq -r '"  \(length) tracked, \([.[] | select(.status == "failed")] | length) failed"' "$WORK/app.json" >&2
else
  echo "  GITEA_MIRROR_URL / GITEA_MIRROR_API_KEY unset - empty repos will be report-only" >&2
fi

# Signal 4: periodic-sync errors from a saved Gitea container log.
: > "$WORK/syncerr.txt"
if [ -n "$GITEA_LOG" ]; then
  grep -oP 'repo: <Repository \d+:\K[^>]+' "$GITEA_LOG" | tr 'A-Z' 'a-z' | sort -u > "$WORK/syncerr.txt" || true
  echo "  $(wc -l < "$WORK/syncerr.txt") repos with sync errors in log" >&2
fi
jq -R -s 'split("\n") | map(select(. != ""))' "$WORK/syncerr.txt" > "$WORK/syncerr.json"

# Signal 2: upstream probe, only for empty public mirrors that may be actioned.
echo "Probing upstreams..." >&2
echo '{}' > "$WORK/probe.json"
jq -r --slurpfile app "$WORK/app.json" '
  .[] | select(.empty and (.private | not) and (.original_url // "") != "")
  | select(($app[0][.full_name | ascii_downcase].status // "") | IN("mirrored", "failed"))
  | "\(.full_name)\t\(.original_url)"' "$WORK/repos.json" |
while IFS=$'\t' read -r fn url; do
  code=$(curl -s -o /dev/null -I -L --max-time 20 -w '%{http_code}' "$url" || echo 000)
  jq --arg k "$fn" --arg v "$code" '. + {($k): $v}' "$WORK/probe.json" > "$WORK/probe.tmp" && mv "$WORK/probe.tmp" "$WORK/probe.json"
done

# Classification.
jq --slurpfile app "$WORK/app.json" --slurpfile probe "$WORK/probe.json" --slurpfile err "$WORK/syncerr.json" '
  ($app[0]) as $app | ($probe[0]) as $probe | ($err[0]) as $err
  | def entry(c; a; why): {
      full_name, owner: .owner.login, name, case: c, action: a,
      size_MB: ((.size / 1024 * 10 | round) / 10), reason: why,
      mirror_status: ($app[.full_name | ascii_downcase].status),
      mirror_id: ($app[.full_name | ascii_downcase].id)
    };
  [ .[] | (.full_name | ascii_downcase) as $fn | ($app[$fn]) as $a
    | if .empty then
        if $a == null then
          entry("E"; "report-only"; "empty but gitea-mirror status unknown - cannot tell a broken shell from a queued clone")
        elif ($a.status | IN("mirrored", "failed") | not) then
          entry("E"; "report-only"; "empty but gitea-mirror status=\($a.status) - in flight or queued, leave alone")
        elif .private then
          entry("A"; "delete+retry"; "empty, status=\($a.status), private upstream not probed - assumed alive")
        elif (($probe[.full_name] // "") | IN("404", "410")) then
          entry("B"; "delete"; "empty, status=\($a.status), upstream HTTP \($probe[.full_name]) gone")
        else
          entry("A"; "delete+retry"; "empty, status=\($a.status), upstream HTTP \($probe[.full_name] // "n/a") - assumed alive")
        end
      elif ($err | index($fn)) then
        entry("C"; "report-only"; "sync error in gitea log but repo has content - retry, never delete")
      elif ($a.status // "") == "failed" then
        entry("D"; "retry"; "repo has content but gitea-mirror status=failed: \($a.error)")
      else empty end
  ]' "$WORK/repos.json" > "$OUT"

# Report.
echo
echo "=== FAILED MIRROR REPORT ==="
if [ "$(jq length "$OUT")" -eq 0 ]; then
  echo "No failing mirrors detected. Nothing to clean up."
else
  jq -r 'sort_by(.case, .full_name)[] | "\(.case)  \(.action)\t\(.full_name)\t\(.size_MB) MB\t\(.reason)"' "$OUT"
  echo
  jq -r 'group_by(.case)[] | "  case \(.[0].case): \(length) repo(s)"' "$OUT"
  jq -r '"  reclaimable: \([.[] | select(.case | IN("A","B")) | .size_MB] | add // 0) MB"' "$OUT"
fi
echo
echo "Plan written to: $OUT"
echo "Nothing was changed. To act on it, run cleanup-failed-mirrors.sh (add --apply to execute)."
