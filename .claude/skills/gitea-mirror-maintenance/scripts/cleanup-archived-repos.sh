#!/usr/bin/env bash
# Deletes the Gitea mirrors whose GitHub source is gone, when that source
# belonged to the user, together with gitea-mirror's tracking row. Mirrors of
# third-party sources are kept. Dry run by default.
#
# Usage: cleanup-archived-repos.sh --login <tea-login> [--owners a,b,c] [--apply]
#        --owners defaults to the gh user plus every org it administers.
# Env:   GITEA_MIRROR_URL, GITEA_MIRROR_API_KEY; gh logged in to GitHub
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
[ -n "$LOGIN" ] || { echo "--login is required" >&2; exit 2; }
[ -n "${GITEA_MIRROR_URL:-}" ] && [ -n "${GITEA_MIRROR_API_KEY:-}" ] ||
  { echo "GITEA_MIRROR_URL and GITEA_MIRROR_API_KEY are required" >&2; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in" >&2; exit 2; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
tea_api() { (cd "$WORK" && timeout 120 tea api --login "$LOGIN" "$@" </dev/null); }
mirror_api() {
  curl -fsS --max-time 120 -H @<(printf 'x-api-key: %s\n' "$GITEA_MIRROR_API_KEY") "$@"
}

# The user's own GitHub namespaces.
if [ -z "$OWNERS" ]; then
  OWNERS=$( { gh api user --jq .login
              gh api --paginate user/memberships/orgs --jq '.[] | select(.role == "admin") | .organization.login'; } | paste -sd, -)
fi
echo "Owners: $OWNERS"
jq -Rc 'split(",") | map(ascii_downcase)' <<<"$OWNERS" > "$WORK/owners.json"

# Every pull mirror in Gitea, with the GitHub path it pulls from.
: > "$WORK/gitea.jsonl"
page=1
while :; do
  tea_api "/repos/search?limit=50&page=$page&sort=id&order=asc" | jq -c '.data[]' > "$WORK/p.jsonl"
  [ -s "$WORK/p.jsonl" ] || break
  jq -c 'select(.mirror and ((.original_url // "") | test("^https://github.com/"; "i")))
         | {full_name, owner: .owner.login, name, size,
            src: (.original_url | sub("^https://github.com/"; ""; "i") | sub("\\.git$"; ""))}' \
    "$WORK/p.jsonl" >> "$WORK/gitea.jsonl"
  page=$((page + 1))
done
jq -s 'unique_by(.full_name)' "$WORK/gitea.jsonl" > "$WORK/gitea.json"

# Sources GitHub answers 404 for; any other failure counts as alive.
jq -r '.[].src' "$WORK/gitea.json" | sort -fu | xargs -P 8 -I{} sh -c \
  'out=$(gh api "repos/{}" --silent 2>&1) || case "$out" in
     *"rate limit"*) echo "LIMITED {}" ;; *"HTTP 404"*) echo "GONE {}" ;; esac' > "$WORK/probe" || true
if grep -q '^LIMITED ' "$WORK/probe"; then
  echo "GitHub rate limit hit on $(grep -c '^LIMITED ' "$WORK/probe") probe(s); re-run after it resets (gh api rate_limit)" >&2
  exit 1
fi
sed -n 's/^GONE //p' "$WORK/probe" | jq -Rsc 'split("\n") | map(select(length > 0) | ascii_downcase)' > "$WORK/gone.json"

mirror_api "${GITEA_MIRROR_URL%/}/api/github/repositories" > "$WORK/app.json"
PLAN=$(jq --slurpfile owners "$WORK/owners.json" --slurpfile gone "$WORK/gone.json" --slurpfile app "$WORK/app.json" '
  map(select((.src | ascii_downcase) as $s | $gone[0] | index($s)))
  | map((.src | ascii_downcase) as $s | .full_name as $fn
        | . + {mine: ((.src | split("/")[0] | ascii_downcase) as $o | $owners[0] | index($o) != null),
               size_MB: ((.size / 1024 * 10 | round) / 10),
               rows: [$app[0].repositories[]
                      | select(((.mirroredLocation // "") | ascii_downcase) == ($fn | ascii_downcase)
                               or (.fullName | ascii_downcase) == $s) | .id]})' "$WORK/gitea.json")

echo "=== MIRRORS OF DELETED GITHUB REPOS ==="
jq -r '.[] | if .mine then "DELETE  \(.full_name)  (\(.size_MB) MB, source \(.src), \(.rows | length) row(s))"
             else "KEEP    \(.full_name)  (third-party source \(.src))" end' <<<"$PLAN"
TARGETS=$(jq -c '[.[] | select(.mine)]' <<<"$PLAN")
COUNT=$(jq length <<<"$TARGETS")
[ "$COUNT" -gt 0 ] || { echo "Nothing to delete."; exit 0; }

if [ "$APPLY" -eq 0 ]; then
  echo "$COUNT repo(s) would be deleted from Gitea and gitea-mirror. Re-run with --apply to execute."
  exit 0
fi

echo "=== APPLYING to $COUNT repo(s) ==="
IDS=()
while IFS=$'\t' read -r fn owner name rows; do
  if (cd "$WORK" && timeout 120 tea repos delete --login "$LOGIN" --owner "$owner" --name "$name" --force </dev/null >/dev/null 2>&1); then
    echo "  OK   delete $fn"
    [ -n "$rows" ] && IFS=, read -ra r <<<"$rows" && IDS+=("${r[@]}")
  else
    echo "  FAIL delete $fn"
  fi
done < <(jq -r '.[] | [.full_name, .owner, .name, (.rows | join(","))] | @tsv' <<<"$TARGETS")

# Drop the tracking rows of the deleted copies, so they are not re-mirrored.
if [ "${#IDS[@]}" -gt 0 ]; then
  body=$(printf '%s\n' "${IDS[@]}" | jq -R . | jq -sc '{ids: unique}')
  if mirror_api -X DELETE -H 'Content-Type: application/json' -d "$body" \
      "${GITEA_MIRROR_URL%/}/api/repositories" >/dev/null; then
    echo "  OK   removed ${#IDS[@]} gitea-mirror row(s)"
  else
    echo "  FAIL removing gitea-mirror rows"
  fi
fi
