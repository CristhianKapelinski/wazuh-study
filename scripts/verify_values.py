#!/usr/bin/env python3
"""Compare recomputed metrics against every number printed in the paper.

Each check in the expected-values file names a results artifact, a dotted path
inside its JSON, the value as printed in the paper, and where the paper states
it. A computed value passes when it matches the paper's value at the paper's
own printed precision. A missing artifact file yields SKIP (so partial runs
verify in isolation); a present artifact missing the key yields FAIL.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys


def resolve(obj: object, dotted: str) -> object:
    for key in dotted.split("."):
        obj = obj[key]  # type: ignore[index]
    return obj


# Tolerance for a value that was re-measured through the engine on this machine. The
# engine does not classify the 1,000 events bit-identically across runs: replaying
# runC-minimal moved two events, which is 0.002 of accuracy. These bounds are a little
# over twice that, and they apply ONLY to the variants a live replay actually produced.
# Everything read from the committed run stays exact, so a real regression still fails.
LIVE_RATE_TOL = 0.005
LIVE_COUNT_TOL = 5


def matches(computed: object, expect: str, tolerant: bool = False) -> bool:
    if "." in expect:
        if tolerant:
            return abs(float(computed) - float(expect)) <= LIVE_RATE_TOL + 1e-12
        decimals = len(expect.split(".")[1])
        return f"{float(computed):.{decimals}f}" == expect
    if tolerant:
        return abs(int(computed) - int(expect)) <= LIVE_COUNT_TOL  # type: ignore[arg-type]
    return str(int(computed)) == expect  # type: ignore[arg-type]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results", required=True, help="directory with recomputed JSONs")
    ap.add_argument("--expected", default="expected/paper_values.json")
    ap.add_argument("--tolerant", default="", help="comma-separated artifacts re-measured "
                                                  "live, compared within a declared tolerance")
    args = ap.parse_args()

    checks = json.loads(pathlib.Path(args.expected).read_text())
    tolerant_artifacts = {a for a in args.tolerant.split(",") if a}
    cache: dict[str, object] = {}
    passed = failed = skipped = 0
    for c in checks:
        artifact = pathlib.Path(args.results) / c["artifact"]
        if not artifact.exists():
            skipped += 1
            print(f"SKIP {c['id']} ({c['artifact']} absent)")
            continue
        if c["artifact"] not in cache:
            cache[c["artifact"]] = json.loads(artifact.read_text())
        try:
            computed = resolve(cache[c["artifact"]], c["path"])
        except (KeyError, TypeError):
            failed += 1
            print(f"FAIL {c['id']}: key {c['path']} missing in {c['artifact']}")
            continue
        tol = c["artifact"] in tolerant_artifacts
        if matches(computed, c["expect"], tol):
            passed += 1
            marca = " ~live" if tol else ""
            print(f"PASS{marca} {c['id']}: {c['expect']} ({c['source']})")
        else:
            failed += 1
            print(f"FAIL {c['id']}: paper={c['expect']} computed={computed} ({c['source']})")

    print(f"\n{passed} pass / {failed} fail / {skipped} skip")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
