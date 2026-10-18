---
title: "Knowledge base roadmap"
summary: "How this KB is being moved onto the family format, step by step, and what's still to come"
topic: roadmap
status: plan
last_reviewed: 2026-10-18
---

# Knowledge base roadmap

This KB is moving onto the family format in small pull requests, without moving the engine's
data in [`knowledge/`](../../knowledge/README.md) or the lessons that live in the connected repos.

| Step | What lands | Waits on |
|---|---|---|
| 1. Foundation | The scripts, schemas, workflows and issue forms; this README, `family.yaml`, the first sources, the curation and experts method, the guardrails, and a page per topic with status `plan` | Nothing |
| 2. Decisions | `docs/decisions/` moves here in MADR 4 format, with every reference updated, and the first family decisions (adopting the format, two tool languages, learned knowledge stays where it happened) | The open docs-consistency and schema-registry pull requests, which add decisions and change how paired decisions are checked |
| 3. Seed content | Topic pages and known errors written from the connected repos' lessons, linked rather than copied, and the first upstream asks | Step 1 |
| 4. Experts study | The first scored list for this KB's topic, and its feeds in `sources.toml` | Step 1 |
| 5. Guardrails everywhere | The guardrails section in the repo README and CLAUDE.md | The open pull requests that edit those files |

Also proposed to the family, as decisions in step 2:

- **A stronger leak check in `validate.py`:** GUIDs outside an allowlist of public IDs, UNC paths,
  default machine names and a hashed customer denylist, which this brain's guard already has.
- **Model-drafted entries count only after review:** an entry from a model needs a reviewer before
  it can be `verified`.
- **Using the Claude API**, a cross-project decision with the AI research KB as its source of truth.
