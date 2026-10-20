---
title: "Knowledge base roadmap"
summary: "How this KB is being moved onto the family format, step by step, and what's still to come"
topic: roadmap
status: plan
last_reviewed: 2026-10-19
---

# Knowledge base roadmap

This KB is moving onto the family format in small pull requests, without moving the engine's
data in [`knowledge/`](../../knowledge/README.md) or the lessons that live in the connected repos.

| Step | What lands | Waits on |
|---|---|---|
| 1. Foundation | Done: the scripts, schemas, workflows and issue forms; this README, `family.yaml`, the first sources, the curation and experts method, the guardrails, and a page per topic with status `plan` | Nothing |
| 2. Decisions | Done: the earlier decisions moved here in MADR 4 format with every reference updated (0001 to 0003 accepted), and the first family decisions, [0006](decisions/0006-family-kb-format.md) to [0010](decisions/0010-family-model-selection-convention.md) | Nothing |
| 3. Seed content | Done: topic pages and known errors written from the connected repos' lessons, linked rather than copied, and the first upstream asks | Nothing |
| 4. Experts study | Done: the first scored list for this KB's topic, and its feeds in `sources.toml` | Nothing |
| 5. Guardrails everywhere | Done: the guardrails and the family KB in the repo README and CLAUDE.md | Nothing |

Proposed to the family in step 2, waiting on the other three KBs: a stronger leak check and
reviewed model-drafted entries ([0009](decisions/0009-family-format-stronger-leak-check.md)). The
family's model-selection convention is
[0010](decisions/0010-family-model-selection-convention.md).

Proposed on 2026-10-19: link to upstream sources of truth instead of restating them, check
against them, and give back through reviewed drafts
([0011](decisions/0011-family-format-upstream-sources.md)). The writing rule applies now; the
`upstream:` front matter and its freshness check wait on the family. Pages still to get their
upstream links: every topic page except [fslogix/](fslogix/README.md).
