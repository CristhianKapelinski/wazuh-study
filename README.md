# wazuh-study: Context-Aware SIEM Rule Generation with LLMs

Replication package for the SBSeg 2026 paper *"Context-Aware SIEM Rule
Generation with LLMs: When Site Profiles Are Not Enough"* (Main Track, short paper). An LLM conditioned only on an organization
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
| [Experiments](#experiments) | Claim #1 (main, < 1 s) and Claim #2 (optional, Docker) |
| [Citation](#citation) | How to cite the paper |
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
| RAM / disk | 13 MB peak RAM (measured), < 50 MB disk |
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

Two claims. **Claim #1 is the main one and is what reproduces the paper.** Its
command is the same one as the *Minimal test* above, because the whole
verification runs in under a second: there is nothing to gain from a reduced
variant, and splitting it into two different commands would only invent a
difference that does not exist. Claim #2 re-measures the pipeline live and is
optional.

### Claim #1 (main): the LLM-augmented ruleset loses 4.4 pp of accuracy and 3.1 pp of weighted F1 to the native baseline, and runs A and B are identical

```bash
./reproduce.sh
```

- **Flags:** none. `--out DIR` writes elsewhere than `out/`.
- **Expected time:** 0.15 s (measured; see *Basic information*).
- **Expected resources:** 13 MB peak RAM, under 10 MB written to `out/`. No
  network, no Docker.
- **Expected result:** the checksums verify, the native and LLM metrics are
  recomputed from the committed labeled CSVs, and all 52 published values are
  checked against the paper at its own precision, one `PASS <check-id>` line
  each, ending in:

```
52 pass / 0 fail / 0 skip
```

  `out/summary.json` carries the headline deltas
  (`"drop_accuracy_pp": 4.4`, `"drop_weighted_f1_pp": 3.1`,
  `"runs_ab_identical": true`) and `out/summary.csv` reproduces the aggregate
  columns of Table 2. Every other number in the paper is a field of the same
  run: per-class precision, recall and F1 in `out/native.json` and
  `out/run*.json`, and the confusion matrices of Table 3 in their `confusion`
  fields. The script exits non-zero if any check fails.

### Claim #2 (optional): the numbers come from the Wazuh engine, not from the committed CSVs

```bash
./scripts/make-env.sh && ./run.sh --fresh
```

- **Flags:** `--fresh` wipes previous state so the run starts from scratch.
  `scripts/make-env.sh` writes the `.env` the stack needs, generating strong
  random passwords and their bcrypt hashes in a throwaway container, so nothing
  extra is installed on the host and no placeholder is edited by hand. It
  refuses to overwrite an existing `.env`; pass `--force` to replace one.
- **Expected time:** ~5-10 min to bring the stack up, then ~3-5 min per rule
  variant.
- **Expected resources:** Docker with the compose plugin, ~4 GB RAM, ~5 GB disk.
- **Expected result:** the Wazuh engine is re-run over the same 1,000 events for
  each rule set, producing labeled CSVs on your machine rather than reusing the
  committed ones, and Claim #1 then verifies against those. Full procedure in
  [`docs/full-replay.md`](docs/full-replay.md). Not required for any seal:
  Claim #1 already reproduces every number in the paper.

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

## Citation

Priscila Schafhauzer, Cristhian Kapelinski, Marcio Pohlmann and Diego Kreutz.
*Context-Aware SIEM Rule Generation with LLMs: When Site Profiles Are Not Enough.* Simpósio Brasileiro de Segurança da Informação e de
Sistemas Computacionais (SBSeg), 2026.

```bibtex
@inproceedings{schafhauzer2026siem,
  author    = {Schafhauzer, Priscila and Kapelinski, Cristhian and
               Pohlmann, Marcio and Kreutz, Diego},
  title     = {Context-Aware {SIEM} Rule Generation with {LLMs}: When Site
               Profiles Are Not Enough},
  booktitle = {Simp\'osio Brasileiro de Seguran\c{c}a da Informa\c{c}\~ao e de
               Sistemas Computacionais (SBSeg)},
  year      = {2026}
}
```

[`CITATION.cff`](CITATION.cff) carries the same metadata in machine-readable
form, so GitHub's "Cite this repository" button picks it up.

## LICENSE

[MIT](LICENSE).
