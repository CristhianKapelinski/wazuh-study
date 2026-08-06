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

# Fail with the command that fixes it, not with a traceback three steps later.
command -v python3 >/dev/null || {
  echo "need: python3 (3.8 or newer). Debian/Ubuntu: sudo apt-get install -y python3" >&2
  echo "      Fedora/RHEL: sudo dnf install -y python3   Arch: sudo pacman -S python" >&2
  exit 1; }
python3 - <<'PYCHECK' || exit 1
import sys
if sys.version_info < (3, 8):
    sys.exit(f"need: python3 >= 3.8, found {sys.version.split()[0]}")
PYCHECK

# sha256sum is GNU coreutils; macOS and some minimal images ship shasum instead.
if command -v sha256sum >/dev/null; then SHA="sha256sum"
elif command -v shasum >/dev/null;   then SHA="shasum -a 256"
else echo "need: sha256sum (GNU coreutils) or shasum" >&2; exit 1; fi

echo "== verifying dataset checksums =="
$SHA -c expected/checksums.sha256

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
