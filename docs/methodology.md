# Methodology — dataset and environment construction

Methodological justification of the choices behind the dataset and the
evaluation environment.

## 1. Data origin

The logs come from two real production servers with public IPs, monitored by
Wazuh:

| Host (released name) | Role | auth.log (lines) |
|------|-------|-------------------|
| `srv01` | research server, internet-exposed | ~290,000 |
| `srv02` | research server, internet-exposed | ~35,000 |

Collection window: **2026-05-17 to 2026-05-21** (five calendar days). Because both
machines have public IPs, they receive real, continuous attack traffic (scans,
username enumeration, SSH brute force) in addition to legitimate access, which
yields a dataset with **real positives**, not synthetic ones.

Why `auth.log` (and not generic `syslog`): the object of study is the
classification of **authentication, credential use, and privilege escalation**
events. `auth.log` concentrates 100% of those events (sshd, PAM, sudo, su,
account management). `syslog` is dominated by kernel/service noise with no
value for the proposed classification problem.

## 2. Why sample (instead of using everything)

The raw volume is ~152k events/day. The manual classification that serves as
ground truth is infeasible at that volume, so the design fixes a manually
classifiable fraction (~1,000 lines). The central sampling concern is that
**a simple random sample does not work**: ~70% of `auth.log` is repetitive
noise (`systemd-logind` sessions, `CRON`, `Connection closed`). A random
sample of 1,000 would carry ~700 noise lines and very few security events,
making per-class F1 statistically poor on the classes of interest.

## 3. Stratified sampling

We stratify by **event category**, guaranteeing minimum representation of each
class relevant to the problem, plus enough noise to measure false positives:

| Stratum | Quota | Role in the study |
|---------|------|------------------|
| Invalid user | ~200 | username enumeration (attack) |
| Failed password | ~150 | brute force (attack) |
| Accepted (successful login) | 200 | legitimate access — basis for geo/time rules |
| sudo | 9 (all) | privilege escalation (rare → census, not sample) |
| su | 36 (all) | privilege escalation (rare → census) |
| Disconnected | ~105 | connection anomalies |
| session / connection / CRON | ~300 | noise (false-positive control) |
| **Total** | **1,000** | |

Escalation events (`sudo`, `su`) are rare (45 total) and central to the study,
so they were included **in full** (a census), not sampled.

### 3.1 Cross-cutting dimensions: time of day and geolocation

"Login outside business hours" and "attempt from a foreign country" are not
log categories; they are **attributes** (timestamp and source IP) of login
events. The sampling guarantees both combinations are present:

- **Time of day:** legitimate logins occur around the clock, with an
  early-morning peak (04h ≈ 2,190 logins), confirming the machines have no
  conventional business hours. The `Accepted` stratum was split into
  **business (09-18h)** and **non-business (00-06h + night)**, ~100 each.
- **Geolocation:** 197 `Accepted` logins come from two institutional IPs
  (`203.0.113.1` and `203.0.113.2` in the released mapping). One additional
  `Accepted` login comes from an in-country, non-institutional IP
  (`198.51.100.51`) and is labeled `medium` as an atypical success requiring
  verification. Failed attacks (`Invalid user`, `Failed password`) come from
  dozens of external IPs (419 unique source IPs in total).

Known limitation: the case "**accepted** login from a foreign country" (the
most critical, indicating compromise) **does not exist in the real data**.
The only non-institutional success is in-country. Evaluating the critical case
would require synthetic injection (future work).

## 4. Sampling determinism

Sampling uses **systematic selection** (1 in every *k* lines, with
*k = total/quota*), not random draws. Properties:

- **Reproducible:** same input → same output, no random seed.
- **Temporal spread:** systematic selection distributes the sample across the
  whole window, avoiding concentration in one interval.

The resulting dataset (`dataset/sample-1000.log`, 1,000 lines) is **versioned
in the repository** and pinned by checksum (`expected/checksums.sha256`); it is
the frozen artifact of the experiment. Reproducibility does not depend on
re-running the extraction (production logs change), only on the frozen file.

## 5. Reproducible evaluation environment

Wazuh runs in Docker (manager + indexer + dashboard), version pinned at
**4.14.5**. The dataset is ingested through a `localfile` with
`only-future-events=no`, which forces the manager to **reprocess the whole
file from the first line** on every clean start, instead of the default
tail-only behavior. This guarantees every execution classifies exactly the
same 1,000 events.

Reproducibility rests on three anchors: the frozen dataset in git, the pinned
Wazuh version (identical native ruleset), and deterministic ingestion
(`only-future-events=no` + `make fresh`).

## 6. Anonymization

The released files are anonymized with a consistent substitution (the same
real value always maps to the same fictitious one): institutional and external
IPs map to disjoint RFC 5737 documentation ranges, usernames to `usrNN`
(`root` preserved), hostnames to `srv01`/`srv02`, and SSH key fingerprints to
synthetic SHA-256 strings. Wazuh classification depends on log patterns, not
on the substituted values, so per-rule labels are identical to the internal
dataset. The anonymization script requires the private originals and is
therefore not part of the public artifact.

## 7. Limitations

- Wazuh **correlation** rules (brute force: 5712, 5763, 5551) depend on time
  windows (frequency/interval). Since ingestion uses processing time rather
  than the log's own timestamp, faithful reproduction of those rules would
  require timed replay, out of scope here (the study focuses on atomic
  classification).
- The dataset covers ~4 days of two hosts; it does not capture longer-term
  seasonality.
