#!/usr/bin/env bash
# Collapses the Gitea mirrors and gitea-mirror rows left behind by GitHub
# renames, transfers and case changes onto the repository's current name.
# Dry run by default.
#
# Usage: cleanup-renamed-repos.sh --login <tea-login> [--apply]
# Env:   GITEA_MIRROR_URL, GITEA_MIRROR_API_KEY; gh logged in to GitHub
set -euo pipefail

LOGIN=""
APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --login) LOGIN="$2"; shift 2 ;;
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

# Every pull mirror in Gitea, with the GitHub path it pulls from.
: > "$WORK/gitea.jsonl"
page=1
while :; do
  tea_api "/repos/search?limit=50&page=$page&sort=id&order=asc" | jq -c '.data[]' > "$WORK/p.jsonl"
  [ -s "$WORK/p.jsonl" ] || break
  jq -c 'select(.mirror and ((.original_url // "") | test("^https://github.com/"; "i")))
         | {full_name, size, src: (.original_url | sub("^https://github.com/"; ""; "i") | sub("\\.git$"; ""))}' \
    "$WORK/p.jsonl" >> "$WORK/gitea.jsonl"
  page=$((page + 1))
done
jq -s 'unique_by(.full_name)' "$WORK/gitea.jsonl" > "$WORK/gitea.json"

# Every gitea-mirror row sourced from GitHub.
mirror_api "${GITEA_MIRROR_URL%/}/api/github/repositories" |
  jq '[.repositories[] | select(.sourceProvider == "github")
       | {id, fullName, mirroredLocation: (.mirroredLocation // ""), status}]' > "$WORK/rows.json"

# Resolve every source path to GitHub's current id and name; renames redirect.
jq -r '.[].src' "$WORK/gitea.json" > "$WORK/srcs"
jq -r '.[].fullName' "$WORK/rows.json" >> "$WORK/srcs"
sort -fu "$WORK/srcs" | xargs -P 8 -I{} sh -c \
  'r=$(gh api "repos/{}" --jq "{src: \"{}\", id, current: .full_name}" 2>/dev/null) && echo "$r"' \
  > "$WORK/resolved.jsonl" || true

# Group by GitHub id. Keep the Gitea copy at the current name (exact, else
# case-insensitive, then renamed); drop every other copy and every row whose
# name is not exactly current. Groups with no copy at the current name are
# left untouched.
PLAN=$(jq -n --slurpfile res "$WORK/resolved.jsonl" --slurpfile g "$WORK/gitea.json" --slurpfile r "$WORK/rows.json" '
  ($res | map({key: (.src | ascii_downcase), value: .}) | from_entries) as $m
  | [($g[0][] | ($m[.src | ascii_downcase]) as $x | select($x) | {kind: "repo", gid: $x.id, current: $x.current, name: .full_name, size}),
     ($r[0][] | ($m[.fullName | ascii_downcase]) as $x | select($x) | {kind: "row", gid: $x.id, current: $x.current, name: .fullName, id})]
  | group_by(.gid)
  | map(. as $grp | $grp[0].current as $cur
      | ([$grp[] | select(.kind == "repo")]) as $repos
      | (([$repos[] | select(.name == $cur)] + [$repos[] | select((.name | ascii_downcase) == ($cur | ascii_downcase))])[0]) as $keep
      | select($keep)
      | {current: $cur,
         rename: (if $keep.name != $cur then $keep.name else null end),
         delete_repos: [$repos[] | select(.name != $keep.name) | {name, size_MB: ((.size / 1024 * 10 | round) / 10)}],
         delete_rows: [$grp[] | select(.kind == "row" and .name != $cur) | {id, name}]}
      | select(.rename or (.delete_repos | length > 0) or (.delete_rows | length > 0)))')
SKIPPED=$(jq -n --slurpfile res "$WORK/resolved.jsonl" --slurpfile g "$WORK/gitea.json" '
  ($res | map(.src | ascii_downcase)) as $ok
  | [$g[0][] | select((.src | ascii_downcase) as $s | $ok | index($s) | not) | .full_name]')

echo "=== RENAMED REPOS ==="
jq -r '.[] | "\(.current)",
  (if .rename then "  RENAME     \(.rename) -> \(.current)" else empty end),
  (.delete_repos[] | "  DELETE     \(.name)  (\(.size_MB) MB)"),
  (.delete_rows[] | "  DROP ROW   \(.name)")' <<<"$PLAN"
echo "=== SKIPPED: GitHub source not found ($(jq length <<<"$SKIPPED")) ==="
jq -r '.[] | "  \(.)"' <<<"$SKIPPED"
read -r NREN NDEL NROW < <(jq -r '[(map(select(.rename)) | length), (map(.delete_repos | length) | add // 0), (map(.delete_rows | length) | add // 0)] | @tsv' <<<"$PLAN")
echo "$NREN rename(s), $NDEL Gitea repo deletion(s), $NROW gitea-mirror row deletion(s)."
[ $((NREN + NDEL + NROW)) -gt 0 ] || { echo "Nothing to do."; exit 0; }
[ "$APPLY" -eq 1 ] || { echo "Re-run with --apply to execute."; exit 0; }

echo "=== APPLYING ==="
while IFS=$'\t' read -r from to; do
  if tea_api -X PATCH -f "name=${to#*/}" "/repos/$from" >/dev/null 2>&1; then
    echo "  OK   rename $from -> $to"
  else
    echo "  FAIL rename $from -> $to"
  fi
done < <(jq -r '.[] | select(.rename) | [.rename, .current] | @tsv' <<<"$PLAN")

while read -r fn; do
  if (cd "$WORK" && timeout 120 tea repos delete --login "$LOGIN" --owner "${fn%%/*}" --name "${fn#*/}" --force </dev/null >/dev/null 2>&1); then
    echo "  OK   delete $fn"
  else
    echo "  FAIL delete $fn"
  fi
done < <(jq -r '.[].delete_repos[].name' <<<"$PLAN")

if [ "$NROW" -gt 0 ]; then
  body=$(jq -c '{ids: [.[].delete_rows[].id]}' <<<"$PLAN")
  if mirror_api -X DELETE -H 'Content-Type: application/json' -d "$body" \
      "${GITEA_MIRROR_URL%/}/api/repositories" >/dev/null; then
    echo "  OK   dropped $NROW gitea-mirror row(s)"
  else
    echo "  FAIL dropping gitea-mirror rows"
  fi
fi

# Re-import from GitHub so each current name has its own row.
if mirror_api -X POST -H 'Content-Type: application/json' -d '{}' "${GITEA_MIRROR_URL%/}/api/sync" >/dev/null; then
  echo "  OK   gitea-mirror re-imported GitHub repositories"
else
  echo "  FAIL gitea-mirror re-import; run Import from the dashboard"
fi

# Link the re-imported rows of renamed repos to their existing Gitea copy.
if [ "$NREN" -gt 0 ]; then
  ids=$(mirror_api "${GITEA_MIRROR_URL%/}/api/github/repositories" |
    jq -c --argjson want "$(jq -c '[.[] | select(.rename) | .current]' <<<"$PLAN")" \
      '[.repositories[] | select(.fullName as $f | $want | index($f)) | .id]')
  if [ "$(jq length <<<"$ids")" -gt 0 ] &&
     mirror_api -X POST -H 'Content-Type: application/json' -d "{\"repositoryIds\": $ids}" \
       "${GITEA_MIRROR_URL%/}/api/job/mirror-repo" >/dev/null; then
    echo "  OK   relinked $(jq length <<<"$ids") renamed repo row(s)"
  else
    echo "  WARN renamed repos not relinked yet; the scheduler links them on its next run"
  fi
fi
