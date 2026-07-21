#!/usr/bin/env bash
# Full replay (optional path): for each LLM-generated rule set, reload it into
# the running Wazuh manager, re-inject the same 1,000 events, export the
# per-event levels, and recompute the metrics. Requires the stack to be up
# (./run.sh; see docs/full-replay.md). Takes a few minutes per variant.
#
# Usage: scripts/replay-variants.sh [out_dir]   (default: out-full)
#        MANAGER_HOST=<ssh host> runs against a remote Docker host (default: local)
set -uo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-out-full}"
RUNS=(runA-v2 runB-v2 runC-minimal runD-with-logs)
H="${MANAGER_HOST:-}"
rexec(){ if [ -z "$H" ]; then bash -c "$*"; else ssh "$H" "$*"; fi; }
rcopy(){ if [ -z "$H" ]; then cp "$1" "$2"; else scp -q "$1" "$H:$2"; fi; }

for R in "${RUNS[@]}"; do
  echo "============ $R ============"
  rcopy "results/$R.xml" rules/local_rules.xml
  CT=$(rexec 'docker ps -q -f name=wazuhstudy-wazuh.manager-1')
  [ -n "$CT" ] || { echo "manager is not running — run ./run.sh first"; exit 1; }
  rexec "docker exec $CT sh -c ': > /var/ossec/logs/study/feed.log; : > /var/ossec/logs/archives/archives.json; : > /var/ossec/logs/alerts/alerts.json 2>/dev/null; true'"
  rexec "docker exec $CT /var/ossec/bin/wazuh-control restart" >/dev/null 2>&1
  for i in $(seq 1 30); do
    rexec "docker exec $CT grep -q 'study/feed.log' /var/ossec/logs/ossec.log" 2>/dev/null && break
    sleep 2
  done
  sleep 3
  rexec "docker exec $CT sh -c 'cat /var/ossec/logs/study/sample-1000.log >> /var/ossec/logs/study/feed.log'"
  for i in $(seq 1 30); do
    N=$(rexec "docker exec $CT sh -c 'wc -l < /var/ossec/logs/archives/archives.json 2>/dev/null || echo 0'")
    [ "${N:-0}" -ge 990 ] && break
    sleep 2
  done
  sleep 3
  mkdir -p "$OUT/results-$R"
  cp dataset/dataset-1000-baseline.csv "$OUT/results-$R/dataset.csv"
  MANAGER_HOST="$H" bash scripts/merge-llm.sh "$OUT/results-$R/dataset.csv" > /dev/null
  python3 scripts/metrics.py "$OUT/results-$R/dataset.csv" \
    severidade_manual severidade_wazuh_llm --json "$OUT/results-$R/metrics.json" \
    | tee "$OUT/results-$R/metrics.txt" | head -2
done
echo
echo "Done. Compare $OUT/results-*/dataset.csv against results/results-*/dataset.csv"
echo "and re-run ./reproduce.sh --out <dir> pointing at the fresh CSVs if desired."
