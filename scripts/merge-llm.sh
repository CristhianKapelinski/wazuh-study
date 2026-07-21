#!/usr/bin/env bash
# Fill the 'severidade_wazuh_llm' column of an EXISTING baseline CSV using the
# current Wazuh classification (with the LLM-generated rules loaded).
# Preserves 'severidade_manual' and every other column.
#
# Rows are matched by full_log (Wazuh event ids change on every reprocess; the
# raw log line does not).
#
# Usage: scripts/merge-llm.sh [csv]   (default: dataset/dataset-1000-baseline.csv)
#        MANAGER_HOST=<ssh host> runs against a remote Docker host (default: local)
set -euo pipefail
cd "$(dirname "$0")/.."

CSV="${1:-dataset/dataset-1000-baseline.csv}"
[ -f "$CSV" ] || { echo "CSV not found: $CSV"; exit 1; }
H="${MANAGER_HOST:-}"
rexec(){ if [ -z "$H" ]; then bash -c "$*"; else ssh "$H" "$*"; fi; }
CT=$(rexec 'docker ps -q -f name=wazuhstudy-wazuh.manager-1')
[ -n "$CT" ] || { echo "manager is not running"; exit 1; }
TMP=$(mktemp)

# current Wazuh classification (with LLM rules) keyed by full_log
rexec "docker exec $CT cat /var/ossec/logs/archives/archives.json" \
  | python3 -c '
import sys, json
def sev(l):
    if l is None: return "nenhum"
    return "critico" if l>=13 else "alto" if l>=9 else "medio" if l>=5 else "baixo"
m = {}
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try: a = json.loads(line)
    except json.JSONDecodeError: continue
    fl = a.get("full_log", "").replace("\n", " ")
    lvl = a.get("rule", {}).get("level")
    m[fl] = sev(int(lvl) if lvl is not None else None)
json.dump(m, open(sys.argv[1], "w"))
print(f"{len(m)} events classified by Wazuh+LLM", file=sys.stderr)
' "$TMP"

# merge into the CSV, preserving severidade_manual
python3 - "$CSV" "$TMP" <<'PY'
import sys, csv, json
csv_path, sev_path = sys.argv[1], sys.argv[2]
sev = json.load(open(sev_path))
rows = list(csv.DictReader(open(csv_path)))
fields = rows[0].keys() if rows else []
filled = 0
for r in rows:
    s = sev.get(r.get("full_log", ""))
    if s is not None:
        r["severidade_wazuh_llm"] = s; filled += 1
with open(csv_path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(fields)); w.writeheader(); w.writerows(rows)
print(f"  {filled}/{len(rows)} rows with severidade_wazuh_llm filled")
PY
rm -f "$TMP"
echo "==> $CSV updated"
