# Full replay (optional path)

The default reproduction path (`./reproduce.sh`) recomputes every paper number
from the committed labeled CSVs in seconds and needs no Docker. This document
describes the **optional** full path: re-executing the Wazuh engine itself over
the same 1,000 events, for each rule configuration.

## Requirements

- Docker with the compose plugin, ~4 GB free RAM, ~5 GB disk.
- `vm.max_map_count >= 262144` (run.sh raises it, needs sudo once).

## Steps

```bash
cp .env.example .env         # fill the placeholders (any strong local values)
./run.sh --fresh             # ~5-10 min first time: pulls Wazuh 4.14.5, ingests the 1,000 events
scripts/count-alerts.sh      # sanity check: native baseline alerts per rule
scripts/replay-variants.sh   # ~3-5 min per variant: replays the 4 LLM rule sets
```

`replay-variants.sh` writes, per variant, a fresh `out-full/results-<run>/dataset.csv`
with the `severidade_wazuh_llm` column re-measured **live** on this machine
(it never reuses the committed reference CSVs), plus the recomputed metrics.
Compare against the committed run of record in `results/results-<run>/`.

Set `MANAGER_HOST=<ssh-host>` to drive a stack on a remote Docker host.

## Reproducibility notes

- Ingestion is deterministic (`only-future-events=no`; the manager reprocesses
  the frozen sample from line 1 on every clean start).
- Time-window correlation rules (e.g. native 5712) depend on ingestion pacing;
  atomic per-event classification is stable across replays, which is what the
  paper measures. See `docs/methodology.md`, Section 7.
- The dashboard is exposed only on `127.0.0.1` with lab credentials from your
  local `.env` (never committed).
