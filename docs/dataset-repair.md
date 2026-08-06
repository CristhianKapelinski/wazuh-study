# Repair of the pseudonymised log

Internal note on a defect in the anonymisation of `dataset/sample-1000.log`, found while
re-running the full replay on a second machine, and on the repair applied to the released
files. Nothing here changes a number in the paper.

## What was wrong

The pseudonymiser replaced every occurrence of the token `user` with the pseudonym `usr21`.
That is right for a username, but `user` is also a keyword of the sshd and PAM message
grammar, and those occurrences were rewritten as well:

```
Invalid user usr01                    ->  Invalid usr21 usr01
Failed password for invalid user root ->  Failed password for invalid usr21 root
session opened for user X(uid=...)    ->  session opened for usr21 X(uid=...)
Disconnected from user X              ->  Disconnected from usr21 X
```

Wazuh's sshd rules match on those literals. On the released log, rule 5710 ("Attempt to login
using a non-existent user") never fires: 339 events are reclassified, rule 40101 loses its 12
events, and the whole high-severity class disappears from a fresh run. Measured against the
committed baseline, 173 of 1001 rows (17.3%) came out different, and the native macro F1 fell
from 0.4864 to 0.3142.

So the released data could not reproduce the paper's own baseline, even though the code, the
Wazuh version (4.14.5) and the configuration were the ones the paper describes.

## The repair

Two substitutions, in [`scripts/repair-pseudonymisation.py`](../scripts/repair-pseudonymisation.py):

```python
s = re.sub(r'(?<!user )\busr21 (?=\S)', 'user ', s)
s = re.sub(r'\busr\d+(?=\(uid=65534\))', 'nobody', s)
```

**The keyword.** `usr21` is the keyword whenever another token follows it. Where it follows an
already-restored `user` it is a genuine username and is left alone, which resolves the
ambiguous `usr21 usr21` case: keyword first, username second.

**The account.** The 12 events behind rule 40101 are `su: session opened for user X(uid=65534)
by root`. The uid survived pseudonymisation, and 65534 is `nobody` by convention; rule 40101
matches it through Wazuh's `$SYS_USERS` list. Restoring the name brings those 12 events back.

Applied to the log and to the `full_log` column of every CSV, because `merge-llm.sh` joins
Wazuh alerts to the dataset by that exact string: repairing only the log would break the join.
2,252 lines were rewritten across the six files, and `expected/checksums.sha256` was
regenerated.

## Why this does not weaken the anonymisation

Neither substitution restores personal data. `user` is a protocol keyword, not anyone's name.
`nobody` is a standard unprivileged system account, and the uid that identifies it (65534) was
already published in the log. Every real username stays pseudonymised.

## Result

After the repair, a fresh run of the pipeline on a second machine reproduces the committed
baseline:

| | committed | fresh run |
|---|---|---|
| accuracy | 0.6330 | 0.6330 |
| macro F1 | 0.4864 | 0.4864 |
| weighted F1 | 0.6952 | 0.6952 |

Rule counts match one for one: 5710 x339, 5715 x198, 5502 x36, 5501 x34, 40101 x12. Two rows
of 1001 still differ, in a symmetric `medio`/`alto` swap: rule 5712 is a composite rule with a
`timeframe`, so which event in a burst carries the correlated alert depends on arrival order.

`python3 scripts/repair-pseudonymisation.py --check` exits non-zero if the damage is ever
reintroduced.

## Unrelated defects found in the same session

Independent of the data, and fixed in [`scripts/replay-variants.sh`](../scripts/replay-variants.sh):

- `wazuh-control restart` does **not** reload the ruleset. The replay used it between variants,
  so a variant silently kept the previous rules. That is why `runA-v2` and `runB-v2` hold
  byte-identical results, and `runC-minimal` and `runD-with-logs` likewise. The script now
  restarts the container.
- A rule file Wazuh refuses does not degrade the run, it kills `wazuh-analysisd`. The replay
  then reported `0 events classified` with no reason given. The script now checks for
  `CRITICAL: (1220)` and for a live analysisd, and stops the variant with the error Wazuh
  printed.

Three of the four generated rule sets are refused by Wazuh 4.14.5: `runA-v2` and
`runD-with-logs` carry a duplicated CIDR (`203.0.113.0/24|203.0.113.0/24`), `frequency="1"`
(the attribute must exceed 1) and an invalid `dstuser` option; `runB-v2` carries the duplicated
CIDR. The rule files are the model's output and the object of study, so they are **not** edited
here: a generated rule set that a current Wazuh will not load is a property of the generation,
and the replay now reports it as such.
