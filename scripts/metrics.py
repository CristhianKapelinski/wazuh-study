#!/usr/bin/env python3
"""Per-class precision/recall/F1 and confusion matrix between two severity columns.

Rows whose ``full_log`` is a Wazuh manager self-event (prefix ``ossec:``) are
excluded: they are artifacts of the archive capture, not part of the 1,000-event
sample (see docs/REPRODUCIBILITY_REPORT.md). CSV labels are in Portuguese
(nenhum/baixo/medio/alto/critico); output uses the paper's English labels.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys

CLASSES = ["nenhum", "baixo", "medio", "alto", "critico"]
ENGLISH = {"nenhum": "none", "baixo": "low", "medio": "medium",
           "alto": "high", "critico": "critical"}
SELF_EVENT_PREFIX = "ossec:"


def confusion(path: str, truth: str, pred: str) -> dict[str, dict[str, int]]:
    """Build the gold-by-prediction confusion matrix from a labeled CSV."""
    cm = {g: {p: 0 for p in CLASSES} for g in CLASSES}
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            if row.get("full_log", "").startswith(SELF_EVENT_PREFIX):
                continue
            g, p = row.get(truth, "").strip(), row.get(pred, "").strip()
            if g not in CLASSES or p not in CLASSES:
                sys.exit(f"unexpected label: truth={g!r} pred={p!r}")
            cm[g][p] += 1
    return cm


def summarize(cm: dict[str, dict[str, int]]) -> dict:
    """Compute accuracy, macro/weighted F1 and per-class metrics from a matrix."""
    n = sum(sum(r.values()) for r in cm.values())
    div = lambda a, b: a / b if b else 0.0
    classes = {}
    for c in CLASSES:
        tp = cm[c][c]
        fp = sum(cm[g][c] for g in CLASSES if g != c)
        fn = sum(cm[c][p] for p in CLASSES if p != c)
        p, r = div(tp, tp + fp), div(tp, tp + fn)
        classes[ENGLISH[c]] = {"precision": p, "recall": r,
                               "f1": div(2 * p * r, p + r), "support": tp + fn}
    return {
        "n": n,
        "accuracy": div(sum(cm[c][c] for c in CLASSES), n),
        "macro_f1": sum(v["f1"] for v in classes.values()) / len(CLASSES),
        "weighted_f1": div(sum(v["f1"] * v["support"] for v in classes.values()), n),
        "classes": classes,
        "confusion": {ENGLISH[g]: {ENGLISH[p]: cm[g][p] for p in CLASSES}
                      for g in CLASSES},
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("csv_path")
    ap.add_argument("truth_column")
    ap.add_argument("pred_column")
    ap.add_argument("--json", metavar="PATH", help="also write metrics as JSON")
    args = ap.parse_args()

    result = summarize(confusion(args.csv_path, args.truth_column, args.pred_column))
    if args.json:
        with open(args.json, "w") as f:
            json.dump(result, f, indent=2)

    print(f"=== {args.truth_column} (gold) vs {args.pred_column} ===")
    print(f"n={result['n']}  accuracy={result['accuracy']:.4f}  "
          f"macro_f1={result['macro_f1']:.4f}  weighted_f1={result['weighted_f1']:.4f}")
    print(f"{'class':<10} {'P':>7} {'R':>7} {'F1':>7} {'support':>8}")
    for name, v in result["classes"].items():
        print(f"{name:<10} {v['precision']:>7.3f} {v['recall']:>7.3f} "
              f"{v['f1']:>7.3f} {v['support']:>8}")
    print("confusion (rows=gold, columns=prediction):")
    names = list(result["confusion"])
    print(f"{'':>10}" + "".join(f"{c:>10}" for c in names))
    for g in names:
        print(f"{g:>10}" + "".join(f"{result['confusion'][g][p]:>10}" for p in names))


if __name__ == "__main__":
    main()
