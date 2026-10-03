#!/usr/bin/env bash
# Deletes the `archived-*` repositories gitea-mirror left in Gitea after their
# GitHub source disappeared, together with gitea-mirror's tracking row.
# Dry run by default.
#
# Usage: cleanup-archived-repos.sh --login <tea-login> --owners a,b,c [--apply]
# Env:   GITEA_MIRROR_URL, GITEA_MIRROR_API_KEY
set -euo pipefail

LOGIN=""
OWNERS=""
APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --login) LOGIN="$2"; shift 2 ;;
    --owners) OWNERS="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$LOGIN" ] && [ -n "$OWNERS" ] || { echo "--login and --owners are required" >&2; exit 2; }
[ -n "${GITEA_MIRROR_URL:-}" ] && [ -n "${GITEA_MIRROR_API_KEY:-}" ] ||
  { echo "GITEA_MIRROR_URL and GITEA_MIRROR_API_KEY are required" >&2; exit 2; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
tea_api() { (cd "$WORK" && timeout 60 tea api --login "$LOGIN" "$@" </dev/null); }
mirror_api() {
  curl -fsS --max-time 60 -H @<(printf 'x-api-key: %s\n' "$GITEA_MIRROR_API_KEY") "$@"
}

# Archived copies in the given owners, from Gitea.
: > "$WORK/gitea.json"
for owner in ${OWNERS//,/ }; do
  page=1
  while :; do
    tea_api "/repos/search?q=archived-&owner=$owner&limit=50&page=$page" | jq '.data' > "$WORK/p.json"
    [ "$(jq length "$WORK/p.json")" -gt 0 ] || break
    jq -c --arg o "$owner" '.[] | select(.owner.login == $o and (.name | startswith("archived-")))' "$WORK/p.json" >> "$WORK/gitea.json"
    page=$((page + 1))
  done
done

# Keep only those gitea-mirror itself archived: its row points at that location.
mirror_api "${GITEA_MIRROR_URL%/}/api/github/repositories" > "$WORK/app.json"
PLAN=$(jq -s --slurpfile app "$WORK/app.json" '
  ($app[0].repositories | map(select((.mirroredLocation // "") != "")
     | {key: (.mirroredLocation | ascii_downcase), value: .}) | from_entries) as $m
  | map(($m[.full_name | ascii_downcase]) as $a
        | {full_name, owner: .owner.login, name, size_MB: ((.size / 1024 * 10 | round) / 10),
           mirror_id: ($a.id // null), source: ($a.fullName // null)})' "$WORK/gitea.json")

echo "=== ARCHIVED REPOS ==="
jq -r '.[] | if .mirror_id then "DELETE  \(.full_name)  (\(.size_MB) MB, source \(.source))"
             else "SKIP    \(.full_name)  (not archived by gitea-mirror)" end' <<<"$PLAN"
TARGETS=$(jq -c '[.[] | select(.mirror_id)]' <<<"$PLAN")
COUNT=$(jq length <<<"$TARGETS")
[ "$COUNT" -gt 0 ] || { echo "Nothing to delete."; exit 0; }

if [ "$APPLY" -eq 0 ]; then
  echo "$COUNT repo(s) would be deleted from Gitea and gitea-mirror. Re-run with --apply to execute."
  exit 0
fi

echo "=== APPLYING to $COUNT repo(s) ==="
IDS=()
while IFS=$'\t' read -r fn owner name id; do
  if (cd "$WORK" && timeout 120 tea repos delete --login "$LOGIN" --owner "$owner" --name "$name" --force </dev/null >/dev/null 2>&1); then
    echo "  OK   delete $fn"; IDS+=("$id")
  else
    echo "  FAIL delete $fn"
  fi
done < <(jq -r '.[] | [.full_name, .owner, .name, .mirror_id] | @tsv' <<<"$TARGETS")

# Drop the tracking rows of the deleted copies, so they are not re-mirrored.
if [ "${#IDS[@]}" -gt 0 ]; then
  body=$(printf '%s\n' "${IDS[@]}" | jq -R . | jq -s '{ids: .}')
  if mirror_api -X DELETE -H 'Content-Type: application/json' -d "$body" \
      "${GITEA_MIRROR_URL%/}/api/repositories" >/dev/null; then
    echo "  OK   removed ${#IDS[@]} gitea-mirror row(s)"
  else
    echo "  FAIL removing gitea-mirror rows"
  fi
fi
