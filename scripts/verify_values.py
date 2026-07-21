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


def matches(computed: object, expect: str) -> bool:
    if "." in expect:
        decimals = len(expect.split(".")[1])
        return f"{float(computed):.{decimals}f}" == expect
    return str(int(computed)) == expect  # type: ignore[arg-type]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results", required=True, help="directory with recomputed JSONs")
    ap.add_argument("--expected", default="expected/paper_values.json")
    args = ap.parse_args()

    checks = json.loads(pathlib.Path(args.expected).read_text())
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
        if matches(computed, c["expect"]):
            passed += 1
            print(f"PASS {c['id']}: {c['expect']} ({c['source']})")
        else:
            failed += 1
            print(f"FAIL {c['id']}: paper={c['expect']} computed={computed} ({c['source']})")

    print(f"\n{passed} pass / {failed} fail / {skipped} skip")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
