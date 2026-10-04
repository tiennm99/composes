#!/usr/bin/env bash
# Acts on the plan from detect-failed-mirrors.sh. Dry run by default.
#   case A  delete in Gitea, then ask gitea-mirror to retry (re-mirror)
#   case B  delete in Gitea only
#   case D  ask gitea-mirror to retry only
#   cases C and E are never touched
#
# Usage: cleanup-failed-mirrors.sh --login <tea-login> [--apply] [--case A,B,D] [--plan FILE]
# Env:   GITEA_MIRROR_URL, GITEA_MIRROR_API_KEY (needed for retries)
set -euo pipefail

LOGIN=""
APPLY=0
CASES="A,B,D"
PLAN="${TMPDIR:-/tmp}/gitea-mirror-failed-plan.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --login) LOGIN="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --case) CASES="$2"; shift 2 ;;
    --plan) PLAN="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$LOGIN" ] || { echo "--login is required (see: tea login list)" >&2; exit 2; }
[ -f "$PLAN" ] || { echo "plan not found: $PLAN - run detect-failed-mirrors.sh first" >&2; exit 2; }

age_min=$(( ($(date +%s) - $(stat -c %Y "$PLAN")) / 60 ))
[ "$age_min" -le 15 ] || echo "WARNING: plan is $age_min min old - re-run detect-failed-mirrors.sh before applying" >&2

# Cases C and E can never be selected.
TARGETS=$(jq -c --arg cases "$CASES" '
  ($cases | split(",")) as $sel
  | [.[] | select(.case | IN($sel[])) | select(.case | IN("C", "E") | not)] | sort_by(.case, .full_name)' "$PLAN")
SKIPPED=$(jq '[.[] | select(.case | IN("C", "E"))] | length' "$PLAN")
[ "$SKIPPED" -eq 0 ] || echo "Not touched: $SKIPPED repo(s) in cases C and E." >&2

COUNT=$(jq length <<<"$TARGETS")
[ "$COUNT" -gt 0 ] || { echo "No repos match case(s): $CASES"; exit 0; }

if jq -e 'any(.action | test("retry"))' <<<"$TARGETS" >/dev/null &&
   { [ -z "${GITEA_MIRROR_URL:-}" ] || [ -z "${GITEA_MIRROR_API_KEY:-}" ]; }; then
  echo "GITEA_MIRROR_URL and GITEA_MIRROR_API_KEY are required for cases A and D" >&2; exit 2
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ "$APPLY" -eq 0 ]; then
  echo "=== DRY RUN - no changes made ==="
  jq -r '.[] | "# \(.full_name) (case \(.case): \(.reason))",
    (select(.action | test("delete")) | "tea repos delete --login LOGIN --owner \(.owner) --name \(.name) --force"),
    (select(.action | test("retry")) | "POST /api/job/retry-repo {\"repositoryIds\":[\"\(.mirror_id)\"]}"), ""' \
    <<<"$TARGETS" | sed "s/--login LOGIN/--login $LOGIN/"
  echo "$COUNT repo(s) would be actioned. Re-run with --apply to execute."
  exit 0
fi

echo "=== APPLYING to $COUNT repo(s) ==="
RETRY_IDS=()
FAILED=0
while IFS=$'\t' read -r fn owner name action id; do
  if [[ $action == *delete* ]]; then
    if (cd "$WORK" && timeout 120 tea repos delete --login "$LOGIN" --owner "$owner" --name "$name" --force </dev/null >/dev/null 2>&1); then
      echo "  OK   delete $fn"
    else
      echo "  FAIL delete $fn"; FAILED=$((FAILED + 1)); continue
    fi
  fi
  # Retry only after a successful delete, so a live repo is never re-mirrored over.
  [[ $action == *retry* ]] && RETRY_IDS+=("$id")
done < <(jq -r '.[] | [.full_name, .owner, .name, .action, (.mirror_id // "")] | @tsv' <<<"$TARGETS")

if [ "${#RETRY_IDS[@]}" -gt 0 ]; then
  body=$(printf '%s\n' "${RETRY_IDS[@]}" | jq -R . | jq -s '{repositoryIds: .}')
  if curl -fsS --max-time 60 -X POST -H 'Content-Type: application/json' \
      -H @<(printf 'x-api-key: %s\n' "$GITEA_MIRROR_API_KEY") \
      -d "$body" "${GITEA_MIRROR_URL%/}/api/job/retry-repo" >/dev/null; then
    echo "  OK   retry requested for ${#RETRY_IDS[@]} repo(s)"
  else
    echo "  FAIL retry request for ${#RETRY_IDS[@]} repo(s)"; FAILED=$((FAILED + ${#RETRY_IDS[@]}))
  fi
fi

echo "$((COUNT - FAILED)) succeeded, $FAILED failed."
[ "${#RETRY_IDS[@]}" -eq 0 ] || echo "Retried repos re-mirror in the background. Verify with detect-failed-mirrors.sh afterwards."
