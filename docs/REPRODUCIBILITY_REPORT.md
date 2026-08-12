# Reproducibility report

Known data notes and the verification of every number printed in the paper.
The verification is executed by `./reproduce.sh` (checks in
`expected/paper_values.json`).

## Known data notes (hand-written)

1. **One spurious manager self-event in the archive capture.** The raw metric
   CSVs exported from `archives.json` contain one row whose `full_log` is
   `ossec: Manager started.` (Wazuh's own startup message), which is not one of
   the 1,000 injected events. `scripts/metrics.py` excludes manager self-events
   (prefix `ossec:`), so every reported number is computed over exactly the
   1,000 sampled events (accuracy 0.633 native, `none` support 644, cell
   none→low 270).
2. **One duplicated log line is genuine.** `dataset/sample-1000.log` contains
   the same `Failed password` line twice; the duplication exists in the raw
   collected logs, so both occurrences are kept as two events (999 distinct
   lines, 1,000 events).
3. **Ablation variability.** Runs A and B are byte-identical in classification.
   The two ablations (minimal, with-logs) differ from A/B by a single event
   (one extra medium→high escalation), shifting accuracy/weighted-F1 by at
   most 0.001 and per-class cells by at most 0.004; the paper reports the
   ranges.
4. **Per-run labeled CSVs restored.** The per-run CSVs carrying the
   `severidade_wazuh_llm` column (`results/results-*/dataset.csv`) were dropped
   in a repository cleanup; they are restored from git history and committed as
   the run of record. The `severidade_wazuh_llm` column of
   `dataset/dataset-1000-baseline.csv` is intentionally empty (that file is the
   native baseline).
5. **Not recomputable from this artifact:** the sampling extraction (needs the
   private raw logs, ~325k lines) and the anonymization mapping (needs the
   originals). Both are documented in `docs/methodology.md`; the frozen,
   anonymized sample is the committed source of truth.

## Verification results

What `./reproduce.sh` prints on the committed dataset, transcribed:

```
52 pass / 0 fail / 0 skip
```

Every number asserted in the paper (per-class precision/recall/F1, accuracy,
macro/weighted F1, class supports, all confusion-matrix cells for the native
and LLM-A configurations, ablation deltas, and the headline drops of 4.4 pp
accuracy / 3.1 pp weighted F1) is recomputed from the committed CSVs and
matches the printed value at the paper's own precision.
