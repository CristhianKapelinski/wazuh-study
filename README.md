# wazuh-study: Context-Aware SIEM Rule Generation with LLMs

Replication package for the SBSeg 2026 paper *"Context-Aware SIEM Rule Generation with LLMs: When Site Profiles Are Not Enough"* (Main Track, short paper). An LLM conditioned only on an organization profile writes Wazuh local rules; over a fixed set of 1,000 real SSH authentication events, the LLM-augmented configuration **lowers accuracy by 4.4 percentage points** (weighted F1 by 3.1) relative to the native ruleset, with the regression concentrated in a single failure mode. The package contains the anonymized dataset, the prompts, the four generated rule sets, the per-run labeled CSVs, and the scripts that recompute and verify every number printed in the paper.

> Authors: Priscila Schafhauzer, Cristhian Kapelinski, Marcio Pohlmann, Diego Kreutz.

> **For the artifact evaluation, this README is the only file you need to read.**

## README structure

| Section | Description |
|---|---|
| [Considered seals](#considered-seals) | Which seals this artifact targets and why |
| [Basic information](#basic-information) | Reference machine and requirements |
| [Dependencies](#dependencies) | Pinned software and data inputs |
| [Security concerns](#security-concerns) | What runs where |
| [Installation](#installation) | Clone; nothing else for the main path |
| [Minimal test](#minimal-test) | One command, under half a second: its five steps, its expected output, and what the 52 checks are |
| [Experiments](#experiments) | What to run in which order, and Claim #1: replay through the Wazuh engine (Docker) |
| [Cleaning up](#cleaning-up) | One command removes what a run created |
| [Citation](#citation) | How to cite the paper |
| [LICENSE](#license) | MIT |

The repository is organized as follows:

```
reproduce.sh              main path: recompute + verify + print the paper's tables
expected/                 paper values (52 checks), the paper's two result
                          tables cell by cell, and SHA-256 pins
dataset/                  frozen anonymized sample + labeled baseline CSV
prompts/                  the three prompt variants sent to the LLM
results/                  run of record: 4 rule sets, per-run labeled CSVs, metrics
scripts/                  metrics.py, verify_values.py, summarize.py, replay helpers
docs/                     methodology, labels rationale, org profile,
                          full-replay guide, REPRODUCIBILITY_REPORT.md
run.sh, Makefile, manager/, rules/   optional full-replay stack
```


## Considered seals

- **Available (SeloD):** the artifact is public at a stable URL with an open license.
- **Functional (SeloF):** `./reproduce.sh` runs the whole evaluation pipeline end to end on the committed data in under a second, with no network or Docker.
- **Sustainable (SeloS):** small typed Python modules with one responsibility each, documented layout, pinned inputs (`expected/checksums.sha256`).
- **Reproducible (SeloR):** every number printed in the paper (52 checks: metrics, supports, confusion-matrix cells, headline deltas) is recomputed from the committed data and compared at the paper's own precision. Both result tables are reprinted cell by cell (63 cells). `./reproduce.sh` exits 0 only when all pass.

## Basic information

| Item | Value |
|---|---|
| OS | Linux (any distribution with Python 3) |
| Runtime | Python ≥ 3.10 (standard library only) |
| RAM / disk | 13 MB peak RAM (measured), < 50 MB disk |
| GPU | not needed |
| Optional full replay | Docker + compose, ~4 GB RAM, ~5 GB disk |
| Reference machine | AMD Ryzen 5 8600G, 30 GB RAM |

## Dependencies

- **Host tools, main path:** `git` (to clone) and `python3` 3.8 or newer. Nothing else; the analysis uses the standard library only.

  ```bash
  sudo apt-get update && sudo apt-get install -y git python3   # Debian, Ubuntu
  sudo dnf install -y git python3                              # Fedora, RHEL
  sudo pacman -Sy --needed git python                          # Arch
  sudo zypper install -y git python3                           # openSUSE
  ```

- **Host tools, Claim #1 (`./claim.sh`):** additionally `docker` **and the compose plugin v2**, the `docker compose` subcommand, not the standalone `docker-compose` binary. The daemon must be running and usable by your user without `sudo`.

  ```bash
  sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2   # Debian, Ubuntu
  sudo usermod -aG docker "$USER" && newgrp docker
  ```

  Package names differ between distributions and releases; on Fedora, Arch and openSUSE, and on older Ubuntu, follow the upstream instructions instead: [Docker Engine](https://docs.docker.com/engine/install/) and [Compose plugin](https://docs.docker.com/compose/install/linux/).

- **Data inputs:** all committed and pinned by SHA-256 (`expected/checksums.sha256`): the frozen anonymized sample (`dataset/sample-1000.log`, 1,000 events), the labeled baseline CSV, the four per-run labeled CSVs, and the four LLM-generated rule sets.
- **Optional full replay:** Docker with the compose plugin; `run.sh` fetches the official `wazuh-docker` stack pinned at **v4.14.5**.

## Security concerns

- The main path only reads committed CSVs and writes to `out/`; no network, no containers, no credentials.
- The optional full replay runs a local Wazuh stack whose dashboard binds to `127.0.0.1` only, with credentials you set in a local `.env` (never committed).
- The dataset is anonymized (RFC 5737 IPs, surrogate usernames/hostnames, synthetic fingerprints); see `docs/methodology.md`.

## Installation

```bash
git clone https://gitlab.com/cristhianavila.aluno/wazuh-study.git
cd wazuh-study
```

## Minimal test

`./reproduce.sh` is both the minimal test and the whole offline evaluation: it verifies the pinned inputs, recomputes every metric from the committed labeled CSVs, checks each recomputed number against the value printed in the paper, and reprints the paper's two result tables from what it has just computed.

```bash
./reproduce.sh          # equivalently: make reproduce
```

| Item | Value |
|---|---|
| Time | **under 0.5 s**: 0.21 s to 0.44 s measured across fifteen runs on the reference machine, the spread being machine load rather than work |
| Peak RAM | 13 MB, measured |
| Written to disk | 12 files, 11 KB in total, all inside `out/` |
| Needs | `python3` 3.8 or newer and `sha256sum` (or `shasum`). No network, no Docker, no `sudo`, no configuration, no arguments |
| Exit code | 0 when every check passes, non-zero as soon as one does not |

### The five steps

Each step announces itself with a `==` header, so a step that fails is identifiable from the screen alone.

| # | Printed header | What happens in it | Time |
|---|---|---|---|
| 1 | none, it is silent when it succeeds | Preflight: `python3` exists and is at least 3.8, and `sha256sum` or `shasum` exists. A missing tool aborts here with the install command for it, instead of failing three steps later inside a script. | 0.03 s |
| 2 | `== verifying dataset checksums ==` | `sha256sum -c expected/checksums.sha256` over the ten pinned inputs: the frozen 1,000-event sample, the labeled baseline CSV, the four per-run labeled CSVs and the four generated rule sets. One `<file>: OK` line each. A mismatch stops the run before any metric is computed, because a changed input would make every later number meaningless. | under 0.01 s |
| 3 | `== recomputing metrics ==` | `scripts/metrics.py` runs five times, once for the native baseline and once per LLM run. Each time it builds the gold-by-prediction confusion matrix from the CSV, dropping the manager's own `ossec:` self-events, and derives accuracy, macro F1, weighted F1 and per-class precision, recall, F1 and support into `out/<run>.json`. One line then names the four runs read from the committed run of record, since this path replays nothing. `scripts/summarize.py` writes `out/summary.csv` and prints the headline deltas as a one-line JSON. | 0.1 s |
| 4 | `== verifying against the paper ==` | `scripts/verify_values.py` walks the 52 entries of `expected/paper_values.json`, printing one `PASS` or `FAIL` line per entry and then the tally. | 0.02 s |
| 5 | none, the output is framed instead | `scripts/show_tables.py` reprints Tables 2 and 3 cell by cell, reports how many published cells reproduced, and reads the result in three bullets. `scripts/show_claim.py` closes with the framed verdict and sets the exit code. | 0.04 s |

### What the `52 pass / 0 fail / 0 skip` line stands for

The tally is not the summary of a hidden test suite. It counts one entry per number the paper prints, all of them listed in `expected/paper_values.json`, and every entry also prints its own line just above the tally, naming the check, the published value and where the paper states it:

```text
PASS native-accuracy: 0.633 (Sec. 5.1)
PASS llmA-cm-medium-high: 45 (Table 3, LLM-A / Sec. 5.2)
```

Each entry names the recomputed JSON to read, the dotted path to the value inside it, the value exactly as printed in the paper, and the paper section or table it comes from. The comparison is made at the paper's own printed precision: `0.633` is compared to three decimals and a count is compared exactly, so a recomputation that drifts in the fourth decimal still passes while a regression in the third does not. The 52 entries cover:

| What is verified | Checks |
|---|---|
| Sample size after the self-event filter, `n = 1000` | 1 |
| Aggregate metrics: accuracy, macro F1, weighted F1 | 13 |
| Per-class precision, recall and F1 | 17 |
| Class supports: none 644, low 92, medium 249, high 15 | 4 |
| Confusion-matrix cells | 15 |
| Headline deltas: 4.4 pp of accuracy, 3.1 pp of weighted F1 | 2 |
| **Total** | **52** |

Per configuration, that is 26 checks on the native ruleset, 16 on LLM run A, 2 on run B, 4 on run C (minimal prompt), 2 on run D (with logs), and 2 on the cross-run summary. The framed verdict at the end restates two of them, the two deltas, and adds one value the list does not carry: whether the metrics of runs A and B come out identical. Separately from the 52, step 5 compares all 63 cells the paper prints in its two tables, 30 in Table 2 and 33 in Table 3.

### Expected output

Verbatim, with the middle of the check list elided:

```text
== verifying dataset checksums ==
dataset/sample-1000.log: OK
dataset/dataset-1000-baseline.csv: OK
results/results-runA-v2/dataset.csv: OK
results/results-runB-v2/dataset.csv: OK
results/results-runC-minimal/dataset.csv: OK
results/results-runD-with-logs/dataset.csv: OK
results/runA-v2.xml: OK
results/runB-v2.xml: OK
results/runC-minimal.xml: OK
results/runD-with-logs.xml: OK
== recomputing metrics ==
   read from the committed run (this path replays nothing): runA-v2 runB-v2 runC-minimal runD-with-logs
{"drop_accuracy_pp": 4.4, "drop_weighted_f1_pp": 3.1, "runs_ab_identical": true}
== verifying against the paper ==
PASS native-n: 1000 (Sec. 3.1, sample size)
PASS native-accuracy: 0.633 (Sec. 5.1)
PASS native-weighted-f1: 0.695 (Sec. 5.1 / Table 2)
PASS native-macro-f1: 0.486 (Table 2)
   [... 47 further PASS lines, one per published value ...]
PASS drop-weighted-f1-pp: 3.1 (Abstract / Sec. 5.2 / Sec. 7)

52 pass / 0 fail / 0 skip

──────────────────────────────────────────────────────────────────
  The paper's results, recomputed here. A cell that did not reproduce
  is printed as `recomputed!=paper` in place of the value.
──────────────────────────────────────────────────────────────────
  Table 2: Per-class metrics: native Wazuh vs. the LLM configuration (runs A/B).

    Native
      accuracy 0.633,  macro F1 0.486,  weighted F1 0.695
      class         P      R     F1
      none      1.000  0.581  0.735
      low       0.000  0.000  0.000
      medium    0.729  0.992  0.840
      high      0.923  0.800  0.857

    LLM (runs A/B)
      accuracy 0.589,  macro F1 0.362,  weighted F1 0.665
      class         P      R     F1
      none      1.000  0.581  0.735
      low       0.000  0.000  0.000
      medium    0.693  0.815  0.749
      high      0.203  0.800  0.324

──────────────────────────────────────────────────────────────────
  Table 3: Confusion matrices (rows: gold; columns: prediction; the near-empty critical column is omitted).

    Native Wazuh
      gold \ pred     none     low  medium    high
      none             374     270       0       0
      low                0       0      92       0
      medium             0       1     247       1
      high               0       3       0      12

    LLM run A
      gold \ pred     none     low  medium    high
      none             374     270       0       0
      low                0       0      90       2
      medium             0       0     203      45
      high               0       3       0      12
      plus 1 in the critical column the paper omits (gold medium)

──────────────────────────────────────────────────────────────────
  63 of 63 published cells reproduce exactly (30/30 in Table 2, 33/33 in Table 3)
──────────────────────────────────────────────────────────────────
  Reading the tables
   [... three bullets reading the result: where the regression is,
        and where it is not ...]

══════════════════════════════════════════════════════════════════
  Claim: the LLM-augmented ruleset trails the native baseline, and the
         two identical runs agree
──────────────────────────────────────────────────────────────────
  accuracy lost to the baseline (pp)  : 4.4     (paper 4.4  ) OK   [Abstract / Sec. 5.2]
  weighted F1 lost (pp)               : 3.1     (paper 3.1  ) OK   [Abstract / Sec. 5.2]
  runs A and B identical              : True    (paper True ) OK   [Sec. 5.2]
──────────────────────────────────────────────────────────────────
  every published value               : 52 pass / 0 fail / 0 skip
──────────────────────────────────────────────────────────────────
  source of these numbers             : recomputed from the committed labeled
                                        CSVs (results/); run ./claim.sh to measure live
  wall clock on this machine          : 0 s
──────────────────────────────────────────────────────────────────
  RESULT: OK   (52/52 published values match the paper)
══════════════════════════════════════════════════════════════════
```

### How the reader knows it worked

Four signals, none of which requires trusting the others:

- Every line of step 4 begins with `PASS`. A value that misses prints `FAIL <check-id>: paper=<published> computed=<recomputed>`, so a failure names the number and the discrepancy rather than only the count.
- The tally reads `52 pass / 0 fail / 0 skip`. A non-zero `skip` would mean a metrics JSON was missing, which on this path means step 3 did not finish.
- The table check reads `63 of 63 published cells reproduce exactly (30/30 in Table 2, 33/33 in Table 3)`, and no cell in the printed tables reads `recomputed!=paper`.
- The last line of the frame reads `RESULT: OK   (52/52 published values match the paper)`, and `echo $?` immediately after the run prints `0`. Any failed check flips this to `RESULT: FAIL` and a non-zero exit status.

The `wall clock on this machine` line inside the frame counts whole seconds, so a run this fast reports `0 s`; use `time ./reproduce.sh` to see the fraction of a second it actually took.

### What the run leaves behind

Everything lands in `out/` and nothing is written outside it: `native.json` plus one `<run>.json` per LLM run, each holding the full recomputed metrics including the confusion matrix, the same content as human-readable `.txt`, `summary.csv` with one row per configuration, and `summary.json` with the headline deltas. `./cleanup.sh` removes the directory, and `./cleanup.sh --dry-run` lists what it would remove first.

## Experiments

The artifact has one claim, and three commands in this order run it end to end. Only the first is needed for the minimal test; the second is the claim itself; the third gives the machine back.

| Order | Command | Time | What to expect from it |
|---|---|---|---|
| 1 | `./reproduce.sh` | under 0.5 s | The minimal test above. Run it first: it proves the inputs are intact and the pipeline works before any container is started, so a later failure can be attributed to the replay and not to the clone. |
| 2 | `./claim.sh` | 105 s, plus about 180 s of image pull on the first run | Claim #1, measured live. Three announced stages, then the same framed verdict as step 1, with the provenance line saying the numbers were measured here. |
| 3 | `./cleanup.sh` | seconds | Removes the containers, the compose stack, the engine state and the generated `.env`, and reports what it freed. `--dry-run` lists it without removing anything. It never touches anything tracked by git. |

### Claim #1 (main): the LLM-augmented ruleset trails the native baseline by 4.4 pp of accuracy and 3.1 pp of weighted F1, and the two identical runs agree

**Paper reference:** Table 2 and Table 3.

**What this runs.** The pinned Wazuh stack is brought up and the same 1,000 events are replayed through the engine once per rule set, producing freshly labeled CSVs on your machine. The paper's 52 values are then verified against those.

```bash
./claim.sh
```

**Its three stages,** each announced on screen, so a long run is never a silent one:

| Stage | Printed header | What happens in it |
|---|---|---|
| 1 | `== [1/3] bringing the stack up and ingesting the 1,000 events ==` | Preflight for `git`, `docker` and the compose plugin, each with the install command for your package manager if it is missing; `.env` generated with random passwords if absent; then `./run.sh --fresh` pulls Wazuh 4.14.5, starts the stack and feeds it the frozen sample from line 1. Ends with a framed box giving the dashboard URL, the credentials and the SSH alert count. |
| 2 | `== [2/3] replaying every rule variant through the engine (~3-5 min each) ==` | For each of the four rule sets: load it, wait for `wazuh-analysisd`, replay the 1,000 events, wait for the whole feed to drain, and write a freshly labeled `out-full/results-<run>/dataset.csv`. A rule set the engine refuses prints `FAILED: Wazuh refused <run>.xml` and is skipped rather than silently inheriting the previous variant's numbers. |
| 3 | `== [3/3] verifying the paper against what the engine just produced ==` | `./reproduce.sh --out out-live --from out-full`, that is exactly the five steps of the minimal test, reading the fresh CSVs instead of the committed ones. |

- **Flags:** none. The `.env` is generated on first run with random passwords; `scripts/make-env.sh --force` replaces it.
- **Expected time:** **105 s measured** on the reference machine with the Wazuh images already pulled, and 1m36s on an RTX 5080 workstation. The first run also pulls about 2 GB of images: 180 s here on a fast link. A slower link dominates the total.
- **Expected resources:** Docker with the compose plugin, ~4 GB RAM, ~5 GB disk.
- **Expected result:** the two result tables, then the framed verdict. Wazuh 4.14.5 loads one of the four generated rule sets, `runC-minimal`; the run names the other three and reads them from the committed run ([`docs/dataset-repair.md`](docs/dataset-repair.md)):

```text
   not re-measured (Wazuh refused the rule set): runA-v2 runB-v2 runD-with-logs
...
  63 of 63 published cells reproduce exactly (30/30 in Table 2, 33/33 in Table 3)
...
  every published value               : 52 pass / 0 fail / 0 skip
──────────────────────────────────────────────────────────────────
  source of these numbers             : 1 of 4 rule sets re-measured
                                        through the engine here (out-full/)
                                        3 refused by Wazuh, read from the
                                        committed run
  wall clock on this machine          : 105 s
──────────────────────────────────────────────────────────────────
  RESULT: OK   (52/52 published values match the paper)
```

  A re-measured value is compared within a declared tolerance of 0.005 on a rate and 5 on a count, and printed as `PASS ~live`; a re-measured table cell is marked `~`. Replaying the engine moves about two of the 1,000 events, which is 0.002 of accuracy: two replays on this machine gave 0.586 and 0.590 for `runC-minimal`, against the 0.588 the paper reports for it. Everything read from the committed run is compared exactly. Step-by-step in [`docs/full-replay.md`](docs/full-replay.md).

## Cleaning up

One command removes everything a run created, the containers, the generated `.env`, the compose stack and the engine state outside the clone. It never touches anything tracked by git.

```bash
./cleanup.sh
```

Pass `--dry-run` to list what would go without removing it (the containers included).

## Citation

Priscila Schafhauzer, Cristhian Kapelinski, Marcio Pohlmann and Diego Kreutz. *Context-Aware SIEM Rule Generation with LLMs: When Site Profiles Are Not Enough.* Simpósio Brasileiro de Segurança da Informação e de Sistemas Computacionais (SBSeg), 2026.

```bibtex
@inproceedings{schafhauzer2026siem,
  author    = {Schafhauzer, Priscila and Kapelinski, Cristhian and Pohlmann, Marcio and Kreutz, Diego},
  title     = {Context-Aware {SIEM} Rule Generation with {LLMs}: When Site Profiles Are Not Enough},
  booktitle = {Simp\'osio Brasileiro de Seguran\c{c}a da Informa\c{c}\~ao e de Sistemas Computacionais (SBSeg)},
  year      = {2026}
}
```

[`CITATION.cff`](CITATION.cff) carries the same metadata in machine-readable form, so GitHub's "Cite this repository" button picks it up.

## LICENSE

[MIT](LICENSE).
