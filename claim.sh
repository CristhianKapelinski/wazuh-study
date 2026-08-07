#!/usr/bin/env bash
# The claim, end to end and in one command: bring the pinned Wazuh stack up, replay the
# 1,000 events through the engine once per rule set, and verify the paper's values
# against the CSVs that run just produced rather than against the committed ones.
#
# It ends in the same framed block ./reproduce.sh prints, with the provenance line
# saying the numbers were measured here. Nothing to open in a browser, nothing to read
# off a dashboard.
set -euo pipefail
cd "$(dirname "$0")"

command -v docker >/dev/null || { echo "need: docker (with the compose plugin)" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "need: the docker compose plugin" >&2; exit 1; }

[ -f .env ] || ./scripts/make-env.sh

echo "== [1/3] bringing the stack up and ingesting the 1,000 events =="
./run.sh --fresh

echo
echo "== [2/3] replaying every rule variant through the engine (~3-5 min each) =="
bash scripts/replay-variants.sh out-full

echo
echo "== [3/3] verifying the paper against what the engine just produced =="
./reproduce.sh --out out-live --from out-full
