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
RUNS=(${REPLAY_RUNS:-runA-v2 runB-v2 runC-minimal runD-with-logs})
H="${MANAGER_HOST:-}"
rexec(){ if [ -z "$H" ]; then bash -c "$*"; else ssh "$H" "$*"; fi; }
rcopy(){ if [ -z "$H" ]; then cp "$1" "$2"; else scp -q "$1" "$H:$2"; fi; }

for R in "${RUNS[@]}"; do
  echo "============ $R ============"
  rcopy "results/$R.xml" rules/local_rules.xml
  CT=$(rexec 'docker ps -q -f name=wazuhstudy-wazuh.manager-1')
  [ -n "$CT" ] || { echo "manager is not running — run ./run.sh first"; exit 1; }
  rexec "docker exec $CT sh -c ': > /var/ossec/logs/study/feed.log; : > /var/ossec/logs/archives/archives.json; : > /var/ossec/logs/alerts/alerts.json; : > /var/ossec/logs/ossec.log; true'"
  rexec "docker exec $CT /var/ossec/bin/wazuh-control restart" >/dev/null 2>&1
  # An invalid rule file does not degrade the run: the new wazuh-analysisd fails
  # to start and the OLD one keeps running, still holding the PREVIOUS variant's
  # rules. The replay then reports numbers that silently belong to the run
  # before it, which is why two consecutive variants can come out identical.
  # Check that Wazuh accepted the file before trusting anything downstream.
  # Restarting from a healthy manager takes seconds; restarting right after a
  # refused rule file takes longer, because the manager has to clean up first.
  # Wait on wall clock, and print progress so the step cannot be mistaken for a
  # hang.
  READY=""; DEADLINE=$(( $(date +%s) + 300 ))
  while [ "$(date +%s)" -lt "$DEADLINE" ]; do
    if rexec "docker exec $CT grep -q 'CRITICAL: (1220)' /var/ossec/logs/ossec.log" 2>/dev/null; then READY="refused"; break; fi
    # Not `... | grep -q`: grep exits at the first match, the producer dies of
    # SIGPIPE and `set -o pipefail` then reports the whole pipeline as failed,
    # so the check never succeeds. Count inside the container instead.
    if [ "$(rexec "docker exec $CT sh -c '/var/ossec/bin/wazuh-control status | grep -c \"analysisd is running\" || true'" 2>/dev/null | tr -d '[:space:]')" = "1" ]; then READY="up"; break; fi
    printf '\r  waiting for wazuh-analysisd (%ss)' "$(( 300 - DEADLINE + $(date +%s) ))" >&2
    sleep 3
  done
  printf '\r%*s\r' 46 "" >&2
  sleep 3
  if [ "$READY" = "refused" ] || rexec "docker exec $CT grep -q 'CRITICAL: (1220)' /var/ossec/logs/ossec.log" 2>/dev/null; then
    echo "  FAILED: Wazuh refused $R.xml, so the rules were not loaded."
    rexec "docker exec $CT grep -E 'ERROR|CRITICAL' /var/ossec/logs/ossec.log | tail -3" 2>/dev/null | sed 's/^/    /'
    echo "    Any result here would belong to the previous variant, so this one is skipped."
    echo "    This is a property of the generated rules, not of your machine."
    # Leave the manager healthy for the next variant: with the refused file still
    # in place it will not come back, and every later variant would fail too.
    rexec "docker exec $CT sh -c 'printf \"<group name=\\\"local,\\\">\\n  <rule id=\\\"100000\\\" level=\\\"0\\\">\\n    <if_sid>1002</if_sid>\\n    <description>placeholder</description>\\n  </rule>\\n</group>\\n\" > /var/ossec/etc/rules/local_rules.xml'"
    rexec "docker exec $CT /var/ossec/bin/wazuh-control restart" >/dev/null 2>&1
    for i in $(seq 1 60); do
      [ "$(rexec "docker exec $CT sh -c '/var/ossec/bin/wazuh-control status | grep -c \"analysisd is running\" || true'" 2>/dev/null | tr -d '[:space:]')" = "1" ] && break
      sleep 3
    done
    continue
  fi
  if [ "$READY" != "up" ]; then
    echo "  FAILED: wazuh-analysisd did not come up within 5 min with $R.xml; skipping this variant."
    continue
  fi
  rexec "docker exec $CT sh -c 'cat /var/ossec/logs/study/sample-1000.log >> /var/ossec/logs/study/feed.log'"
  # The engine has to finish the WHOLE feed before the alerts are read. Waiting for 990
  # of the 1,000 events and then sleeping a fixed 3 s left the remainder in flight, and
  # whether they landed depended on how fast the host was: the same replay of the same
  # events produced 46 escalations on one machine and 52 on another, so the claim passed
  # or failed by hardware. Wait for every event, and for the count to stop moving, since
  # reaching the total only means the last event was archived, not that its alert was
  # written.
  EXPECTED=$(rexec "docker exec $CT sh -c 'wc -l < /var/ossec/logs/study/sample-1000.log'" | tr -dc 0-9)
  EXPECTED=${EXPECTED:-1000}
  N=0; prev=-1; stable=0
  for i in $(seq 1 90); do
    N=$(rexec "docker exec $CT sh -c 'wc -l < /var/ossec/logs/archives/archives.json 2>/dev/null || echo 0'" | tr -dc 0-9)
    N=${N:-0}
    if [ "$N" -ge "$EXPECTED" ]; then
      if [ "$N" = "$prev" ]; then
        stable=$((stable + 1))
        [ "$stable" -ge 2 ] && break
      else
        stable=0
      fi
    fi
    prev="$N"
    sleep 2
  done
  # A partial drain is a measurement of something other than the published run, so it is
  # stated rather than folded silently into the metrics below.
  if [ "$N" -lt "$EXPECTED" ]; then
    echo "  WARNING: only $N of $EXPECTED events were archived before the 3-minute timeout."
    echo "           The metrics below are measured on a PARTIAL replay and will not match"
    echo "           the paper. Re-run this variant on a less loaded machine."
  fi
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
