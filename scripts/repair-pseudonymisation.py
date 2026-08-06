#!/usr/bin/env python3
"""Repair the pseudonymisation damage in the released SSH log.

The pseudonymiser that anonymised the corpus replaced every occurrence of the
token ``user`` with the pseudonym ``usr21``. That is correct for a username, but
``user`` is also a keyword of the sshd and PAM message grammar, and those
occurrences were rewritten too::

    Invalid user usr01               ->  Invalid usr21 usr01
    Failed password for invalid user ->  Failed password for invalid usr21
    session opened for user X        ->  session opened for usr21 X
    Disconnected from user X         ->  Disconnected from usr21 X

Wazuh's sshd rules key on those literals, so on the released log rule 5710
("Attempt to login using a non-existent user") never matches: 339 events are
reclassified and the whole high-severity class disappears. Reproducing the
paper's baseline from the released data is impossible until the keyword is
restored.

Two substitutions are enough, and neither restores personal data:

1. ``usr21`` is the keyword whenever another token follows it. Where it follows
   an already-restored ``user`` it is a genuine username and is left alone,
   which resolves the ambiguous ``usr21 usr21`` case (keyword, then username).
   ``user`` is a protocol keyword, not anyone's name.

2. ``nobody`` is recoverable because the uid survived pseudonymisation. The 12
   events behind rule 40101 ("System user successfully logged to the system")
   are ``su: session opened for user X(uid=65534) by root``; uid 65534 is
   ``nobody`` by convention, and 40101 matches it through the ``$SYS_USERS``
   list. The uid was already published, so naming the account leaks nothing.

Applied to the log and to the ``full_log`` column of every CSV, since
``merge-llm.sh`` joins Wazuh alerts to the dataset by that exact string.

    python3 scripts/repair-pseudonymisation.py --check      # verify, change nothing
    python3 scripts/repair-pseudonymisation.py --write      # rewrite in place
"""
from __future__ import annotations

import argparse
import csv
import pathlib
import re
import sys

KEYWORD = re.compile(r"(?<!user )\busr21 (?=\S)")
NOBODY = re.compile(r"\busr\d+(?=\(uid=65534\))")

LOG = pathlib.Path("dataset/sample-1000.log")
CSVS = [
    pathlib.Path("dataset/dataset-1000-baseline.csv"),
    *sorted(pathlib.Path("results").glob("results-*/dataset.csv")),
]


def repair(line: str) -> str:
    """Restore the sshd/PAM keyword and the nobody account in one log line."""
    return NOBODY.sub("nobody", KEYWORD.sub("user ", line))


def repair_log(path: pathlib.Path, write: bool) -> int:
    original = path.read_text()
    fixed = "".join(repair(l) for l in original.splitlines(keepends=True))
    if fixed != original and write:
        path.write_text(fixed)
    return sum(1 for a, b in zip(original.splitlines(), fixed.splitlines()) if a != b)


def repair_csv(path: pathlib.Path, write: bool) -> int:
    rows = list(csv.DictReader(path.open()))
    if not rows or "full_log" not in rows[0]:
        return 0
    changed = 0
    for row in rows:
        fixed = repair(row["full_log"])
        if fixed != row["full_log"]:
            row["full_log"] = fixed
            changed += 1
    if changed and write:
        with path.open("w", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    return changed


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true", help="rewrite the files in place")
    ap.add_argument("--check", action="store_true", help="report what would change")
    args = ap.parse_args()
    if not (args.write or args.check):
        ap.error("choose --check or --write")

    total = 0
    for path in [LOG, *CSVS]:
        if not path.exists():
            print(f"  missing: {path}", file=sys.stderr)
            continue
        n = repair_log(path, args.write) if path.suffix == ".log" else repair_csv(path, args.write)
        total += n
        print(f"  {path}: {n} line(s) {'repaired' if args.write else 'would change'}")
    if args.check and total:
        print(f"\n{total} line(s) still carry the pseudonymisation damage.")
        return 1
    print("\nnothing left to repair." if not total else f"\n{total} line(s) repaired.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
