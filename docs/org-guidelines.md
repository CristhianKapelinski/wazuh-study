# Hypothetical organization profile used in the study

This profile is the scenario supplied to the LLM and used for manual labeling.
It is inspired by an academic environment but is not a description of
UNIPAMPA's infrastructure or of the access policy of the two source hosts.

## Description

- **Academic research** servers, accessed remotely over SSH.
- Used by researchers and graduate students.

## Modeled usage context

- Legitimate access comes **exclusively from in-country institutional IP
  ranges**, as stated in the frozen prompt.
- There are **no business hours**: access is continuous (24/7), including
  overnight and on weekends.
- The modeled server has a **public IP** and receives external attack traffic
  all the time (scans, login attempts with nonexistent users, brute force).

## Principles (supplied verbatim to the LLM)

- **Geographic origin is determinant**: out-of-country access is anomalous.
- **Time of day is not, on its own, a risk factor**, given continuous usage.
- **Successful access matters more than an attempt.**
- **Volume and repetition** of events from the same origin are significant.
