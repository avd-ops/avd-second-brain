---
status: accepted
date: 2026-10-18
decision-makers: [owner]
---

# 0009. Family format: a stronger leak check and reviewed model-drafted entries

## Context and Problem Statement

The family's `validate.py` catches email addresses and public IPv4 addresses. This repo's guard also catches GUIDs that aren't placeholders, UNC paths, default Windows machine names and names on a hashed customer denylist, and it runs over `docs/knowledge/` here through `scripts/Test-KbLeaks.ps1`. Topic pages are where real-run fixes get written up, so they are the likeliest place for a tenant ID or a storage account to slip in. Separately, nothing in the format marks an entry a model drafted, so it can't be told apart from one a person checked. Should the shared format carry both checks?

## Considered Options

- Keep format v1 as it is; this repo keeps its extra check on its own
- Propose both for format v2, in all four KBs

## Decision Outcome

Chosen option: "Propose both for format v2", because every KB in the family writes up real runs, and a leak check that only one KB runs protects only that one.

- **Stronger leak check in `validate.py`:** GUIDs other than an allowlist of placeholders (the all-zero GUID and documented examples), UNC paths, default Windows machine names, and an optional `denylist.sha256` of lowercase customer names for private forks.
- **Reviewed model-drafted entries:** a YAML entry or page with `source: llm` needs `reviewed_by` and `reviewed_on` before it validates.
- Ships as `format_version: 2` once all four KBs agree; until then each stays on 1, and this repo keeps `Test-KbLeaks.ps1`.

### Consequences

- Good, because all four KBs get the same protection.
- Bad, because the GUID check needs tuning: public Microsoft IDs (well-known role or app IDs) need the allowlist.
- Neutral, because it is a proposal: nothing changes until the other three KBs accept it.

## More Information

- Proposed to the family per [curation.md](../curation.md).
- Accepted by the owner on 2026-10-21. Written up in ai-brain, which owns the family format, as [AI 0018](https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/decisions/0018-family-format-stronger-leak-check.md); nerdio-hcl and avd-liquidware adopt it from there.
