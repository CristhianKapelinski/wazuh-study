#!/usr/bin/env python3
"""Print the verification as a framed block with a verdict.

Both paths through this artifact end here: the fast one, which recomputes from the
labeled CSVs committed next to the paper, and the live one, which replays the events
through the Wazuh engine on this machine first. They differ only in where the CSVs came
from, and the block says which it was, because an evaluator should never have to work
out whether the numbers in front of them were measured or replayed.

Usage: show_claim.py OUT_DIR SOURCE_DIR PASS FAIL SKIP
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BAR = "═" * 66
SEP = "─" * 66

# The three headline values of the paper, and where each is published.
HEADLINE = [
    ("accuracy lost to the baseline (pp)", "drop_accuracy_pp", "4.4", "Abstract / Sec. 5.2"),
    ("weighted F1 lost (pp)", "drop_weighted_f1_pp", "3.1", "Abstract / Sec. 5.2"),
    ("runs A and B identical", "runs_ab_identical", "True", "Sec. 5.2"),
]


def main() -> int:
    out = Path(sys.argv[1])
    source = Path(sys.argv[2])
    npass, nfail, nskip = (int(x) for x in sys.argv[3:6])

    summary = json.loads((out / "summary.json").read_text(encoding="utf-8"))

    print()
    print(BAR)
    print("  Claim: the LLM-augmented ruleset trails the native baseline, and the")
    print("         two identical runs agree")
    print(SEP)
    failed = 0
    for label, key, paper, where in HEADLINE:
        got = str(summary.get(key))
        ok = got == paper
        failed += not ok
        print(f"  {label:<36}: {got:<7} (paper {paper:<5})".ljust(62)
              + ("OK" if ok else "FAIL") + f"   [{where}]")
    print(SEP)
    print(f"  {'every published value':<36}: {npass} pass / {nfail} fail / {nskip} skip")
    print(SEP)
    live = source.name != "results"
    if live:
        print(f"  {'source of these numbers':<36}: re-measured through the Wazuh engine")
        print(f"  {'':<36}  on this machine ({source}/)")
    else:
        print(f"  {'source of these numbers':<36}: recomputed from the committed labeled")
        print(f"  {'':<36}  CSVs ({source}/); run ./claim.sh to measure live")
    elapsed = os.environ.get("SIEM_CLAIM_ELAPSED")
    if elapsed:
        print(f"  {'wall clock on this machine':<36}: {elapsed} s")
    print(SEP)
    total = npass + nfail
    bad = failed or nfail
    print(f"  RESULT: {'FAIL' if bad else 'OK'}   "
          f"({npass}/{total} published values match the paper)")
    print(BAR)
    print()
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
