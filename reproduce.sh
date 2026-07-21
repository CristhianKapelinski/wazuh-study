#!/usr/bin/env bash
# Reproduce every number in the paper from the committed data (no Docker, ~10 s).
#   ./reproduce.sh [--out DIR]
# Recomputes the native and LLM-augmented metrics from the committed labeled
# CSVs, then verifies each recomputed value against the value printed in the
# paper (expected/paper_values.json). Exit 0 only when every check passes.
# The optional full Wazuh replay is documented in docs/full-replay.md.
set -euo pipefail
cd "$(dirname "$0")"

OUT="out"
[ "${1:-}" = "--out" ] && OUT="${2:?usage: ./reproduce.sh [--out DIR]}"
mkdir -p "$OUT"

echo "== verifying dataset checksums =="
sha256sum -c expected/checksums.sha256

echo "== recomputing metrics =="
python3 scripts/metrics.py dataset/dataset-1000-baseline.csv \
  severidade_manual severidade_wazuh --json "$OUT/native.json" > "$OUT/native.txt"
for RUN in runA-v2 runB-v2 runC-minimal runD-with-logs; do
  python3 scripts/metrics.py "results/results-$RUN/dataset.csv" \
    severidade_manual severidade_wazuh_llm --json "$OUT/$RUN.json" > "$OUT/$RUN.txt"
done
python3 scripts/summarize.py "$OUT"

echo "== verifying against the paper =="
python3 scripts/verify_values.py --results "$OUT"
