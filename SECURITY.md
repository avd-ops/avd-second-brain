# Security policy

avd-second-brain is a personal research project, not for production, provided as is, and not affiliated with the author's employer, Liquidware or Microsoft. There is no support agreement and no response time, but reports are welcome and read.

## Reporting a vulnerability

- **Privately, please.** Use **Report a vulnerability** on this repository's Security tab (GitHub private vulnerability reporting). If that button isn't there, open an issue titled "Security contact request" with no details, and a private channel will be arranged.
- **Never put secrets, tenant, subscription or object IDs, names or estate data in a report or an issue.** Issues are public.
- Say what is affected (a contract schema, the leak guard, a vault script, a knowledge base tool), how it can be misused, and how to reproduce it with synthetic data.

## What is in scope here

This repo holds the family knowledge base, reasoning rules, contracts (`C1`–`C25`), and leak guards (`scripts/Test-KbLeaks.ps1`, `scripts/kb/validate.py`). It holds no write credential and never connects directly to an Azure estate. See [docs/guardrails.md](docs/guardrails.md) and the [security review page](https://avd-ops.dev/security.html) for the family-wide map.
