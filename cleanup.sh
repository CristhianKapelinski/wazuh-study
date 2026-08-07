#!/usr/bin/env bash
# Removes everything a run of this artifact created, inside the clone and outside it.
# It never touches anything tracked by git, and never removes the clone itself.
#
#   ./cleanup.sh --dry-run   list what would be removed, delete nothing
#   ./cleanup.sh             remove it
set -euo pipefail
cd "$(dirname "$0")"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

total=0
gone() {   # gone <path> <what it is>
  local p="$1" what="$2" sz
  [ -e "$p" ] || return 0
  # du exits non-zero on the files the containers wrote as root, and under
  # `set -o pipefail` that status would abort the cleanup before anything is removed --
  # the size is cosmetic, so losing it must never cost the removal below.
  sz=$(du -sm "$p" 2>/dev/null | cut -f1) || sz=""
  sz=${sz:-0}
  total=$((total + sz))
  printf '  %-42s %5s MB  %s\n' "$p" "$sz" "$what"
  [ "$DRY" = "1" ] || rm -rf "$p"
}

# DATA_DIR lives outside the clone and is named in .env, which make-env.sh generated.
DATA_DIR=""
[ -f .env ] && DATA_DIR="$(sed -n 's/^DATA_DIR=//p' .env | tail -1)"

echo "Removing what a run of this artifact leaves behind:"

if command -v docker >/dev/null; then
  ids="$(docker ps -aq --filter 'name=wazuhstudy-' 2>/dev/null || true)"
  if [ -n "$ids" ]; then
    n=$(printf '%s\n' "$ids" | wc -l)
    printf '  %-42s %5s      %s\n' "$n container(s) wazuhstudy-*" "-" "the study stack"
    [ "$DRY" = "1" ] || docker rm -f $ids >/dev/null || true
  fi
fi

gone stack                     "the generated compose stack and its certificates"
# The certificate generator writes into stack/config as root, so the plain rm above may
# leave it behind. Same trick run.sh uses: borrow root from a throwaway container.
if [ -e stack ] && [ "$DRY" = "0" ]; then
  docker run --rm -v "$PWD:/p" alpine rm -rf /p/stack
fi
gone _upstream                 "the wazuh-docker checkout"
gone out                       "verification output"
gone out-full                  "live replay output"
gone out-live                  "verification of the live replay"
gone .env                      "the generated credentials"
if [ -n "$DATA_DIR" ]; then
  gone "$DATA_DIR" "the engine state, outside the clone"
  if [ -e "$DATA_DIR" ] && [ "$DRY" = "0" ]; then
    docker run --rm -v "$DATA_DIR:/d" alpine sh -c 'rm -rf /d/..?* /d/.[!.]* /d/*' >/dev/null 2>&1 || true
    rmdir "$DATA_DIR" 2>/dev/null || true
  fi
fi

echo
if [ "$DRY" = "1" ]; then
  echo "Dry run: nothing was removed. ${total} MB would be freed."
else
  echo "Done. ${total} MB freed. The committed dataset and results are untouched."
fi
