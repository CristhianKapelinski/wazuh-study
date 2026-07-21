# Organization profile used in the study

## Description

- **Academic research** servers, accessed remotely over SSH.
- Used by researchers and graduate students.

## Usage context

- Legitimate access comes **exclusively from in-country institutional IP
  ranges** (remote users connect through the institutional VPN, whose egress
  addresses fall inside those ranges).
- There are **no business hours**: access is continuous (24/7), including
  overnight and on weekends.
- The servers have **public IPs** and receive external attack traffic all the
  time (scans, login attempts with nonexistent users, brute force).

## Principles (supplied verbatim to the LLM)

- **Geographic origin is determinant**: out-of-country access is anomalous.
- **Time of day is not, on its own, a risk factor**, given continuous usage.
- **Successful access matters more than an attempt.**
- **Volume and repetition** of events from the same origin are significant.
