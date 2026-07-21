# wazuh-study: Context-Aware SIEM Rule Generation with LLMs

Replication package for the SBSeg 2026 paper *"Context-Aware SIEM Rule
Generation with LLMs: A Preliminary Study with Wazuh on SSH Authentication
Logs"* (Main Track, short paper). An LLM conditioned only on an organization
profile writes Wazuh local rules; over a fixed set of 1,000 real SSH
authentication events, the LLM-augmented configuration **lowers accuracy by
4.4 percentage points** (weighted F1 by 3.1) relative to the native ruleset,
with the regression concentrated in a single failure mode. The package
contains the anonymized dataset, the prompts, the four generated rule sets,
the per-run labeled CSVs, and the scripts that recompute and verify every
number printed in the paper.

> Paper: P. Schafhauzer, C. Kapelinski, M. Pohlmann, D. Kreutz. SBSeg 2026.

## README structure

| Section | Description |
|---|---|
| [Considered badges](#considered-badges) | Which seals this artifact targets and why |
| [Basic information](#basic-information) | Reference machine and requirements |
| [Dependencies](#dependencies) | Pinned software and data inputs |
| [Security concerns](#security-concerns) | What runs where |
| [Installation](#installation) | Clone; nothing else for the main path |
| [Minimal test](#minimal-test) | One command, < 1 s |
| [Experiments](#experiments) | Claim-by-claim reproduction |
| [LICENSE](#license) | MIT |

## Considered badges

- **Disponível (SeloD):** the artifact is public at a stable URL with an open
  license.
- **Funcional (SeloF):** `./reproduce.sh` runs the whole evaluation pipeline
  end to end on the committed data in under a second, with no network or Docker.
- **Sustentável (SeloS):** small typed Python modules with one responsibility
  each, documented layout, pinned inputs (`expected/checksums.sha256`).
- **Reprodutível (SeloR):** every number printed in the paper (52 checks:
  metrics, supports, confusion-matrix cells, headline deltas) is recomputed
  from the committed data and compared at the paper's own precision;
  `./reproduce.sh` exits 0 only when all pass.

## Basic information

| Item | Value |
|---|---|
| OS | Linux (any distribution with Python 3) |
| Runtime | Python ≥ 3.10 (standard library only) |
| RAM / disk | < 200 MB RAM, < 50 MB disk |
| GPU | not needed |
| Optional full replay | Docker + compose, ~4 GB RAM, ~5 GB disk |
| Reference machine | AMD Ryzen 5 8600G, 30 GB RAM |

## Dependencies

- **Main path:** Python 3 standard library only; no packages to install.
- **Data inputs:** all committed and pinned by SHA-256
  (`expected/checksums.sha256`): the frozen anonymized sample
  (`dataset/sample-1000.log`, 1,000 events), the labeled baseline CSV, the
  four per-run labeled CSVs, and the four LLM-generated rule sets.
- **Optional full replay:** Docker with the compose plugin; `run.sh` fetches
  the official `wazuh-docker` stack pinned at **v4.14.5**.

## Security concerns

- The main path only reads committed CSVs and writes to `out/`; no network,
  no containers, no credentials.
- The optional full replay runs a local Wazuh stack whose dashboard binds to
  `127.0.0.1` only, with credentials you set in a local `.env` (never
  committed).
- The dataset is anonymized (RFC 5737 IPs, surrogate usernames/hostnames,
  synthetic fingerprints); see `docs/methodology.md`.

## Installation

```bash
git clone https://github.com/CristhianKapelinski/wazuh-study.git
cd wazuh-study
```

Nothing else to install for the main path.

## Minimal test

One command exercises the full pipeline (checksum verification → metric
recomputation → verification against the paper), about 0.2 s on the reference
machine:

```bash
./reproduce.sh
```

Expected final output:

```
52 pass / 0 fail / 0 skip
```

with one `PASS <check-id>` line per verified paper value, and exit code 0.

## Experiments

**Main claim (the paper's headline): the LLM-augmented configuration loses
4.4 pp of accuracy and 3.1 pp of weighted F1 to the native baseline, and runs
A/B are identical.**

- Description: recomputes native and LLM metrics from the committed labeled
  CSVs and verifies all 52 paper values, including the headline deltas.
- Execution: `./reproduce.sh` (< 1 s)
- Expected resources: < 200 MB RAM, < 10 MB written to `out/`.
- Expected result: `52 pass / 0 fail / 0 skip`; `out/summary.json` contains
  `"drop_accuracy_pp": 4.4, "drop_weighted_f1_pp": 3.1,
  "runs_ab_identical": true`; `out/summary.csv` reproduces Table 2's
  aggregate columns.

Every other number in the paper is a field of the same run: per-class
precision/recall/F1 in `out/native.json` and `out/run*.json`, and the
confusion matrices (Table 3) in their `confusion` fields. Pre-computed
reference outputs are committed in `results/` for inspection without
re-running.

**Optional (slow) full replay:** re-execute the Wazuh engine itself over the
same 1,000 events for each rule set (measures live on your machine; it never
reuses the committed reference CSVs). Requires Docker; ~5-10 min for the
stack plus ~3-5 min per variant. See `docs/full-replay.md`.

## Repository layout

```
reproduce.sh              main path: recompute + verify every paper number
expected/                 paper values (52 checks) + SHA-256 pins
dataset/                  frozen anonymized sample + labeled baseline CSV
prompts/                  the three prompt variants sent to the LLM
results/                  run of record: 4 rule sets, per-run labeled CSVs, metrics
scripts/                  metrics.py, verify_values.py, summarize.py, replay helpers
docs/                     methodology, labels rationale, org profile,
                          full-replay guide, REPRODUCIBILITY_REPORT.md
run.sh, Makefile, manager/, rules/   optional full-replay stack
```

## LICENSE

[MIT](LICENSE).
