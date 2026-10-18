---
status: accepted
date: 2026-10-18
decision-makers: [owner]
---

# 0007. Python for the family layer, PowerShell for the engine

## Context and Problem Statement

The family's tooling (`scripts/kb/`: build, validate, curate, freshness, feedback, prior art) is Python, shared by all four KBs. This repo's engine, its guard and its tests are PowerShell 7.4 with Pester, and its knowledge spec and [0002](0002-knowledge-base.md) chose JSON over YAML so the guard needs no PowerShell module. Should this repo port the family tooling to PowerShell, or carry two languages?

## Considered Options

- Port the family tooling to PowerShell
- Move the engine to Python
- Keep both: Python for `docs/knowledge/`, PowerShell for the engine and `knowledge/`

## Decision Outcome

Chosen option: "Keep both", because a port would fork the family tooling (every family format change would need a second implementation here), and moving the engine would rewrite working, tested code for no gain.

- `scripts/kb/*.py` and `docs/knowledge/` follow the family: Python 3.11 or later, YAML data with JSON Schemas, tested by `scripts/kb/test_kb.py`.
- The engine, `knowledge/`, the vault tool and their tests stay PowerShell, with JSON data.
- Where the two meet, the stronger check runs on both: `scripts/Test-KbLeaks.ps1` runs the engine's sensitive-text guard over `docs/knowledge/` and `llms.txt`.
- This amends 0002's "JSON over YAML" for `docs/knowledge/` only.

### Consequences

- Good, because family format changes land here as a copy of the shared scripts.
- Good, because both run in Azure Cloud Shell, which has Python and PowerShell.
- Bad, because contributors need both languages and CI runs both.

## More Information

- Python version in Cloud Shell is *unverified*; check `python3 --version` on the first run. CI pins 3.12.
