#!/usr/bin/env python3
"""Aggregate per-run metric JSONs into a summary table and headline deltas.

Writes ``summary.csv`` (one row per configuration) and ``summary.json`` with
the paper's headline deltas: the accuracy and weighted-F1 drop, in percentage
points, of the base LLM configuration (run A) relative to the native ruleset.
"""
from __future__ import annotations

import csv
import json
import pathlib
import sys

RUNS = ["native", "runA-v2", "runB-v2", "runC-minimal", "runD-with-logs"]


def main() -> None:
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "out")
    metrics = {r: json.loads((out / f"{r}.json").read_text()) for r in RUNS}

    with open(out / "summary.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["run", "n", "accuracy", "macro_f1", "weighted_f1"])
        for r in RUNS:
            m = metrics[r]
            w.writerow([r, m["n"], f"{m['accuracy']:.4f}",
                        f"{m['macro_f1']:.4f}", f"{m['weighted_f1']:.4f}"])

    native, llm = metrics["native"], metrics["runA-v2"]
    summary = {
        "drop_accuracy_pp": round((native["accuracy"] - llm["accuracy"]) * 100, 1),
        "drop_weighted_f1_pp": round((native["weighted_f1"] - llm["weighted_f1"]) * 100, 1),
        "runs_ab_identical": metrics["runA-v2"] == metrics["runB-v2"],
    }
    (out / "summary.json").write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
