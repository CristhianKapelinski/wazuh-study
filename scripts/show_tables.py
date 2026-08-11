#!/usr/bin/env python3
"""Print the paper's result tables, recomputed here, in the paper's own layout.

The verification pass answers "does every number still hold?" with one PASS line
per number. That is a verdict, not a result: it never shows Table 2 or Table 3,
so an evaluator holding the PDF cannot read the outcome off the run. This module
prints both tables, so the run reports what the paper reports and the two can be
compared cell by cell, and states in a few lines what they mean.

Cell values come from ``expected/paper_tables.json`` and are compared at the
paper's printed precision, the same rule verify_values.py applies. A cell that
differs is printed as ``recomputed!=paper`` in place of the value, so a
divergence is visible in the table itself and not only in the tally. Cells that
also appear in ``expected/paper_values.json`` are cross-checked against it first,
so the two files cannot disagree about what the paper says.

Usage: show_tables.py [OUT_DIR]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_values import matches, resolve  # noqa: E402  (same-directory module)

ROOT = Path(__file__).resolve().parent.parent
SEP = "─" * 66


def _load(out: Path, artifact: str, cache: dict) -> dict:
    if artifact not in cache:
        cache[artifact] = json.loads((out / artifact).read_text(encoding="utf-8"))
    return cache[artifact]


def cross_check(tables: dict, values: list) -> list[str]:
    """Report cells whose paper value disagrees with expected/paper_values.json.

    Both files state what the paper printed, so a disagreement is a defect in the
    artifact, not a failed reproduction. Returning the complaints instead of
    exiting lets the caller print them alongside the rest of the run.
    """
    published = {(c["artifact"], c["path"]): c["expect"] for c in values}
    problems = []

    def compare(artifact: str, path: str, paper: str) -> None:
        other = published.get((artifact, path))
        if other is not None and other != paper:
            problems.append(f"{artifact}:{path} is {paper} in paper_tables.json "
                            f"and {other} in paper_values.json")

    for cfg in tables["table2"]["configs"]:
        for cls, metrics in cfg["classes"].items():
            for metric, paper in metrics.items():
                compare(cfg["artifact"], f"classes.{cls}.{metric}", paper)
        for metric, paper in cfg["aggregate"].items():
            compare(cfg["artifact"], metric, paper)
    for mat in tables["table3"]["matrices"]:
        for gold, row in mat["rows"].items():
            for pred, paper in row.items():
                compare(mat["artifact"], f"confusion.{gold}.{pred}", paper)
        omitted = mat.get("omitted")
        if omitted:
            compare(mat["artifact"], omitted["path"], omitted["expect"])
    return problems


def _rate(got: object, paper: str) -> tuple[str, bool]:
    """Render a rate cell, or "got!=paper" when it does not reproduce."""
    ok = matches(got, paper)
    return (f"{float(got):.3f}" if ok else f"{float(got):.3f}!={paper}"), ok


def _count(got: object, paper: str) -> tuple[str, bool]:
    """Render a count cell, or "got!=paper" when it does not reproduce."""
    ok = matches(got, paper)
    return (str(int(got)) if ok else f"{int(got)}!={paper}"), ok


def _grid(corner: str, header: list[str], rows: list[tuple[str, list[str]]],
          label_w: int, width: int) -> list[str]:
    """Lay out one block of a table at a caller-chosen column width.

    A diverging cell is rendered as "recomputed!=paper", which is wider than the
    value it replaces; a fixed column width silently runs those cells into their
    neighbour, exactly when the output matters most. The caller sizes `width` to
    the widest cell across every block of the table, so the blocks stay aligned
    with each other as well as internally.
    """
    out = [f"{corner:<{label_w}}" + "".join(f"{h:>{width}}" for h in header)]
    out += [f"{label:<{label_w}}" + "".join(f"{c:>{width}}" for c in cells)
            for label, cells in rows]
    return out


def table2(tables: dict, out: Path, cache: dict) -> tuple[int, int]:
    """Print the per-class metrics table; return (cells reproduced, cells shown)."""
    spec = tables["table2"]
    ok_n = total = 0

    blocks = []
    for cfg in spec["configs"]:
        data = _load(out, cfg["artifact"], cache)
        agg = []
        for metric, label in (("accuracy", "accuracy"), ("macro_f1", "macro F1"),
                              ("weighted_f1", "weighted F1")):
            text, ok = _rate(resolve(data, metric), cfg["aggregate"][metric])
            agg.append(f"{label} {text}")
            ok_n += ok
            total += 1
        rows = []
        for cls in spec["classes"]:
            cells = []
            for metric in ("precision", "recall", "f1"):
                text, ok = _rate(resolve(data, f"classes.{cls}.{metric}"),
                                 cfg["classes"][cls][metric])
                cells.append(text)
                ok_n += ok
                total += 1
            rows.append((cls, cells))
        blocks.append((cfg["label"], agg, rows))

    header = ["P", "R", "F1"]
    width = max(len(c) for _, _, rows in blocks
                for c in header + [c for _, cells in rows for c in cells]) + 2
    print(f"  {spec['number']}: {spec['caption']}")
    for label, agg, rows in blocks:
        print()
        print(f"    {label}")
        print(f"      {',  '.join(agg)}")
        for line in _grid("class", header, rows, label_w=8, width=width):
            print(f"      {line}")
    return ok_n, total


def table3(tables: dict, out: Path, cache: dict) -> tuple[int, int]:
    """Print the confusion matrices; return (cells reproduced, cells shown)."""
    spec = tables["table3"]
    classes = spec["classes"]
    ok_n = total = 0

    blocks = []
    for mat in spec["matrices"]:
        data = _load(out, mat["artifact"], cache)
        rows = []
        for gold in classes:
            cells = []
            for pred in classes:
                text, ok = _count(resolve(data, f"confusion.{gold}.{pred}"),
                                  mat["rows"][gold][pred])
                cells.append(text)
                ok_n += ok
                total += 1
            rows.append((gold, cells))
        footer = None
        omitted = mat.get("omitted")
        if omitted:
            text, ok = _count(resolve(data, omitted["path"]), omitted["expect"])
            ok_n += ok
            total += 1
            footer = f"plus {text} {omitted['note']}"
        blocks.append((mat["label"], rows, footer))

    width = max(len(c) for _, rows, _ in blocks
                for c in classes + [c for _, cells in rows for c in cells]) + 2
    print(f"  {spec['number']}: {spec['caption']}")
    for label, rows, footer in blocks:
        print()
        print(f"    {label}")
        for line in _grid("gold \\ pred", classes, rows, label_w=12, width=width):
            print(f"      {line}")
        if footer:
            print(f"      {footer}")
    return ok_n, total


def reading(out: Path, cache: dict) -> None:
    """Say what the tables show, in the paper's terms, from this run's numbers."""
    native = _load(out, "native.json", cache)
    llm = _load(out, "runA-v2.json", cache)
    nat_c, llm_c = native["classes"], llm["classes"]
    print("  Reading the tables")
    print(f"    - Recall on `none` ({llm_c['none']['recall']:.3f}) and on `high` "
          f"({llm_c['high']['recall']:.3f}) is identical to the native")
    print("      ruleset's, so the LLM rules lose nothing the baseline caught: the")
    print("      regression is not a coverage failure.")
    print(f"    - They escalate {llm['confusion']['medium']['high']} events the analyst "
          f"labeled `medium` to `high`, against")
    print(f"      {native['confusion']['medium']['high']} for the native ruleset. That one "
          f"cell of Table 3 takes `high`")
    print(f"      precision from {nat_c['high']['precision']:.3f} to "
          f"{llm_c['high']['precision']:.3f}, and with it accuracy "
          f"({native['accuracy']:.3f} to")
    print(f"      {llm['accuracy']:.3f}) and weighted F1 ({native['weighted_f1']:.3f} to "
          f"{llm['weighted_f1']:.3f}). This is the paper's")
    print("      single failure mode, over-escalation of external attempts that failed.")
    print("    - `low` scores 0.000 everywhere because neither ruleset ever predicts")
    print("      `low`: the 92 `low` events are all reported as `medium` or `high`.")


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "out")
    tables = json.loads((ROOT / "expected/paper_tables.json").read_text(encoding="utf-8"))
    values = json.loads((ROOT / "expected/paper_values.json").read_text(encoding="utf-8"))

    problems = cross_check(tables, values)
    if problems:
        print("the expected-value files disagree about what the paper says:", file=sys.stderr)
        for p in problems:
            print(f"  {p}", file=sys.stderr)
        return 1

    cache: dict[str, dict] = {}
    print()
    print(SEP)
    print("  The paper's results, recomputed here. A cell that did not reproduce")
    print("  is printed as `recomputed!=paper` in place of the value.")
    print(SEP)
    ok2, n2 = table2(tables, out, cache)
    print()
    print(SEP)
    ok3, n3 = table3(tables, out, cache)
    print()
    print(SEP)
    ok, n = ok2 + ok3, n2 + n3
    print(f"  {ok} of {n} published cells reproduce exactly "
          f"({ok2}/{n2} in Table 2, {ok3}/{n3} in Table 3)")
    print(SEP)
    reading(out, cache)
    return 0 if ok == n else 1


if __name__ == "__main__":
    raise SystemExit(main())
