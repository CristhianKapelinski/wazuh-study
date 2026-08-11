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
| [Minimal test](#minimal-test) | One command, < 1 s |
| [Experiments](#experiments) | Claim #1: replay through the Wazuh engine (Docker) |
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
git clone https://github.com/CristhianKapelinski/wazuh-study.git
cd wazuh-study
```

## Minimal test

One command runs the whole pipeline: checksum verification, metric recomputation, verification against the paper.

```bash
./reproduce.sh
```

- **Expected time:** 0.15 s (measured).
- **Expected resources:** 13 MB peak RAM, under 10 MB written to `out/`. No network, no Docker.
- **Expected result:** the checksums verify, the native and LLM metrics are recomputed from the committed labeled CSVs, and all 52 published values are checked against the paper at its own precision, one `PASS <check-id>` line each. The run then prints the paper's two result tables as recomputed here:

```text
  Table 3: Confusion matrices (rows: gold; columns: prediction; ...)

    LLM run A
      gold \ pred     none     low  medium    high
      none             374     270       0       0
      low                0       0      90       2
      medium             0       0     203      45
      high               0       3       0      12
      plus 1 in the critical column the paper omits (gold medium)

──────────────────────────────────────────────────────────────────
  63 of 63 published cells reproduce exactly (30/30 in Table 2, 33/33 in Table 3)
```

  A cell that did not reproduce is printed as `recomputed!=paper`. The run ends with the verdict:

```text
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

  The script exits non-zero if any check fails. The per-run metrics land in `out/*.json`, the aggregates in `out/summary.csv`.

## Experiments

### Claim #1 (main): the LLM-augmented ruleset trails the native baseline by 4.4 pp of accuracy and 3.1 pp of weighted F1, and the two identical runs agree

**Paper reference:** Table 2 and Table 3.

**What this runs.** The pinned Wazuh stack is brought up and the same 1,000 events are replayed through the engine once per rule set, producing freshly labeled CSVs on your machine. The paper's 52 values are then verified against those.

```bash
./claim.sh
```

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
