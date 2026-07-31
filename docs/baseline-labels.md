# Manual ground truth (baseline labels)

Column `severidade_manual` of the CSVs, assigned according to the
[organization profile](org-guidelines.md), by the **effective impact** of each
event.

## Severity scale (Wazuh levels → label)

Defined by the team (the same scale maps the `severidade_wazuh` column):

| Wazuh level | Label (CSV / paper) |
|-------------|---------------------|
| 1-4 | baixo / low |
| 5-8 | medio / medium |
| 9-12 | alto / high |
| 13-16 | critico / critical |
| no alert | nenhum / none |

## Manual classification criterion

Principle: **effective impact** decides. What compromised (or could have) >
an attempt that failed. Geography only aggravates when there is **success**
or **volume**; time of day never aggravates (24/7 usage).

The labels apply the hypothetical profile supplied to the LLM. They do not
encode the actual access-control policy of either source host.

| Event pattern | Manual | Rationale |
|------------------|--------|---------------|
| Successful login from the **institutional network** (any hour) | none | legitimate routine — out of alerting scope |
| PAM session open/close, connection closed, disconnect | none | network noise |
| **Isolated** `invalid user` / external scan (failed) | low | unsuccessful attempt = internet noise |
| `invalid user` in a **burst** (active enumeration from one IP) | medium | active external attack, but it did not get in |
| Brute force (rule 5712) | medium | active attack without success |
| Login from an **in-country IP outside the institutional network** | medium | atypical success → verify |
| `su`/`sudo` to **root** | high | **privilege escalation obtained** = concrete impact |
| **Successful out-of-country** login / brute force followed by success | critical | compromise — *no such case in this dataset* |

The burst threshold (≥10 attempts from the same IP) is derived from the
distribution: 6 IPs concentrate the mass enumeration; the rest is isolated
opportunistic traffic.

## Resulting distribution (n = 1,000)

| Severity | Manual | Native Wazuh |
|-----------|-------:|-------------:|
| critical | 0 | 0 |
| high | 15 | 13 |
| medium | 249 | 339 |
| low | 92 | 274 |
| none | 644 | 374 |

(The stored CSV has 1,001 rows and 645 raw `nenhum` labels because it includes
one spurious manager self-event captured alongside the sample. The metrics
exclude that event, so this table reports the evaluated population of 1,000
events and support 644 for `none`; see `docs/REPRODUCIBILITY_REPORT.md`.)

## Divergences from Wazuh (what the study wants to correct)

- **Legitimate-login noise:** Wazuh marks institutional access as `low`
  (raises an alert); the guideline treats it as `none` (24/7 routine).
- **Scans treated as one block:** Wazuh gives `medium` to *every*
  `invalid user` (level 5); the analyst separates isolated attempts (`low`)
  from active enumeration (`medium`).
- **Agreement where it matters:** escalation to root is `high` for both; the
  highest-impact event is recognized by both.

## Dataset limitation

There is no `critical` case: no out-of-country login succeeded, and no brute
force was followed by success. One in-country, non-institutional login did
succeed and is labeled `medium`. Exercising the critical geolocation case
would require synthetic injection.
