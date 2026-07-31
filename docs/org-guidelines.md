# Organization profile used in the study

## Description

- **Academic research** servers, accessed remotely over SSH.
- Used by researchers and graduate students.

## Evaluation context

- The servers permit SSH access from external networks.
- For the experimental labeling policy, successful access from in-country
  institutional IP ranges is treated as routine. Successful access from
  outside those ranges is permitted by the system but treated as atypical and
  assigned severity according to its geographic origin.
- There are **no business hours**: access is continuous (24/7), including
  overnight and on weekends.
- The servers have **public IPs** and receive external attack traffic all the
  time (scans, login attempts with nonexistent users, brute force).

## Principles (supplied verbatim to the LLM)

- **Geographic origin is determinant**: out-of-country access is anomalous.
- **Time of day is not, on its own, a risk factor**, given continuous usage.
- **Successful access matters more than an attempt.**
- **Volume and repetition** of events from the same origin are significant.
