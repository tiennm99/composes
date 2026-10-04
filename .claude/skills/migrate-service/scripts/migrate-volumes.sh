#!/usr/bin/env bash
# Copies the named volumes of an old Coolify resource into the matching volumes
# of the new one. Volumes match by the name after the "<uuid>_" prefix. Dry run
# by default.
#
# Usage: migrate-volumes.sh --from <old-uuid> --to <new-uuid> [--map old=new ...] [--apply]
#        --map pairs volumes whose names differ, e.g. --map db-data=postgres-data.
# With --apply, each target volume is first archived into the volume
# migrate-backup-<new-uuid>, then emptied and filled with the source contents.
set -euo pipefail

FROM=""
TO=""
APPLY=0
declare -A MAP=()
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --map) MAP["${2%%=*}"]="${2#*=}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$FROM" ] && [ -n "$TO" ] || { echo "--from and --to are required" >&2; exit 2; }
[[ "$FROM$TO" =~ ^[a-z0-9]+$ ]] || { echo "uuids must be lowercase alphanumeric" >&2; exit 2; }

IMG=alpine
vols() { docker volume ls --format '{{.Name}}' | sed -n "s/^$1_//p" | sort; }
stats() { docker run --rm -v "$1":/v:ro "$IMG" sh -c 'echo "$(du -sk /v | cut -f1)K $(find /v | wc -l) entries"'; }
in_use() { docker ps --filter "volume=$1" --format '{{.Names}}'; }

OLD=$(vols "$FROM")
NEW=$(vols "$TO")
[ -n "$OLD" ] || { echo "no volumes named ${FROM}_* on this Docker host" >&2; exit 1; }
[ -n "$NEW" ] || { echo "no volumes named ${TO}_* on this Docker host; deploy the new resource once first" >&2; exit 1; }

# Source suffix -> target suffix.
declare -A PAIRS=()
echo "=== VOLUME PAIRS ==="
for o in $OLD; do
  n="${MAP[$o]:-$o}"
  if [ -z "$(docker run --rm -v "${FROM}_$o":/v:ro "$IMG" find /v -mindepth 1 -maxdepth 1)" ]; then
    echo "EMPTY      ${FROM}_$o  (nothing to copy)"
  elif ! grep -qx "$n" <<<"$NEW"; then
    echo "UNMATCHED  ${FROM}_$o  ($(stats "${FROM}_$o")); pass --map $o=<target> if its data is needed"
  else
    PAIRS[$o]="$n"
    echo "COPY       ${FROM}_$o  ($(stats "${FROM}_$o"))  ->  ${TO}_$n  ($(stats "${TO}_$n"))"
  fi
done
for n in $NEW; do
  matched=0
  for o in "${!PAIRS[@]}"; do [ "${PAIRS[$o]}" = "$n" ] && matched=1; done
  [ $matched = 1 ] || echo "UNTOUCHED  ${TO}_$n"
done

busy=""
for o in "${!PAIRS[@]}"; do
  for v in "${FROM}_$o" "${TO}_${PAIRS[$o]}"; do
    c=$(in_use "$v"); [ -z "$c" ] || busy+="  $v used by: $c"$'\n'
  done
done
if [ -n "$busy" ]; then
  printf 'Containers still mount these volumes; stop both resources first:\n%s' "$busy" >&2
  exit 1
fi

if [ $APPLY = 0 ]; then
  echo "${#PAIRS[@]} volume(s) would be overwritten. Re-run with --apply to execute."
  exit 0
fi

BACKUP="migrate-backup-$TO"
STAMP=$(date +%Y%m%d-%H%M%S)
docker volume create "$BACKUP" >/dev/null
echo "=== APPLYING (backups in volume $BACKUP) ==="
for o in "${!PAIRS[@]}"; do
  src="${FROM}_$o"; dst="${TO}_${PAIRS[$o]}"
  docker run --rm -v "$dst":/v:ro -v "$BACKUP":/b "$IMG" tar czf "/b/$STAMP-${PAIRS[$o]}.tgz" -C /v .
  docker run --rm -v "$src":/from:ro -v "$dst":/to "$IMG" \
    sh -c 'find /to -mindepth 1 -delete && cp -a /from/. /to/'
  s=$(stats "$src"); d=$(stats "$dst")
  if [ "${s#* }" = "${d#* }" ]; then echo "  OK   $src -> $dst  ($d)"
  else echo "  DIFF $src ($s) -> $dst ($d)"; fi
done
