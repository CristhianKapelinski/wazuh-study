#!/usr/bin/env bash
# Reproduce every number in the paper from the committed data (no Docker, ~10 s).
#   ./reproduce.sh [--out DIR]
# Recomputes the native and LLM-augmented metrics from the committed labeled
# CSVs, then verifies each recomputed value against the value printed in the
# paper (expected/paper_values.json). Exit 0 only when every check passes.
# The optional full Wazuh replay is documented in docs/full-replay.md.
set -euo pipefail
cd "$(dirname "$0")"

# --from points the per-run CSVs at a directory other than the committed `results/`,
# which is how the live path feeds its freshly labeled CSVs through the same
# verification instead of duplicating it.
OUT="out"; SRC="results"
while [ $# -gt 0 ]; do
  case "$1" in
    --out)  OUT="${2:?usage: ./reproduce.sh [--out DIR] [--from DIR]}"; shift 2 ;;
    --from) SRC="${2:?usage: ./reproduce.sh [--out DIR] [--from DIR]}"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
mkdir -p "$OUT"
_T0=$(date +%s)

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
# Wazuh refuses three of the four generated rule sets, so a live replay produces a fresh
# CSV only for the variants it could load. The others fall back to the committed one and
# are named here and in the final block, so the evaluator always knows which numbers were
# measured on their machine and which were replayed.
LIVE=0; REUSED=0; REUSED_LIST=""
for RUN in runA-v2 runB-v2 runC-minimal runD-with-logs; do
  CSV="$SRC/results-$RUN/dataset.csv"
  if [ -f "$CSV" ]; then
    LIVE=$((LIVE + 1))
  else
    CSV="results/results-$RUN/dataset.csv"
    REUSED=$((REUSED + 1)); REUSED_LIST="$REUSED_LIST $RUN"
    [ -f "$CSV" ] || { echo "missing both $SRC/results-$RUN/dataset.csv and $CSV" >&2; exit 1; }
  fi
  python3 scripts/metrics.py "$CSV" \
    severidade_manual severidade_wazuh_llm --json "$OUT/$RUN.json" > "$OUT/$RUN.txt"
done
[ -n "$REUSED_LIST" ] && echo "   not re-measured (Wazuh refused the rule set):$REUSED_LIST"
python3 scripts/summarize.py "$OUT"

echo "== verifying against the paper =="
set +e
VERIFY="$(python3 scripts/verify_values.py --results "$OUT")"; VRC=$?
set -e
echo "$VERIFY"
read -r P F S <<EOF
$(printf '%s\n' "$VERIFY" | sed -n 's/^\([0-9]*\) pass \/ \([0-9]*\) fail \/ \([0-9]*\) skip.*/\1 \2 \3/p' | tail -1)
EOF
SIEM_CLAIM_ELAPSED="$(( $(date +%s) - _T0 ))" \
  python3 scripts/show_claim.py "$OUT" "$SRC" "${P:-0}" "${F:-0}" "${S:-0}" "$LIVE" "$REUSED" || VRC=1
exit "$VRC"
