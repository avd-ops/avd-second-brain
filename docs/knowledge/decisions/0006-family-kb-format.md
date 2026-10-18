---
status: accepted
date: 2026-10-18
decision-makers: [owner]
---

# 0006. Adopt the family KB format at docs/knowledge/, beside the engine's knowledge/

## Context and Problem Statement

The owner runs four projects that each keep a second brain: AVD (this repo), the Nerdio HCL kit, Liquidware and AI (the research behind all of them). They should be built the same way, list each other and own separate topics, so a fix learned in one is found from the others. This repo already has a knowledge base, `knowledge/`, which the engine reads and other repos read at a pinned commit (contract C6). Does this repo adopt the family format, and where does it go?

## Considered Options

- Keep only the engine's `knowledge/` and don't join the family
- Convert `knowledge/` itself to the family format
- Add the family format at `docs/knowledge/`, beside `knowledge/`, which stays as it is

## Decision Outcome

Chosen option: "Add the family format at `docs/knowledge/`, beside `knowledge/`", because the family pages are for people and agents to read, while `knowledge/` is data the engine and other repos read at a pinned commit, and changing its layout would break contract C6.

- `docs/knowledge/` holds the family format v1: topic pages with front matter, decisions in MADR 4 (this folder), YAML data with JSON Schemas, generated blocks, a root `llms.txt`, [family.yaml](../family.yaml) and [sources.toml](../sources.toml).
- `knowledge/` keeps its JSON, its schemas and its guard (`scripts/Test-Knowledge.ps1`), governed by [0002](0002-knowledge-base.md).
- The family format changes only through a "Family format" decision made in all four KBs; until then this KB stays on `format_version: 1`.
- General AI knowledge (the Claude API, Foundry, model choices, keyless sign-in to AI APIs) is the AI KB's topic; the `agents/` page here keeps only how the AVD repos use it.

### Consequences

- Good, because the four KBs share checks, workflows and one way to find each other's decisions.
- Good, because nothing that reads `knowledge/` changes.
- Bad, because there are two knowledge folders; each one's README says what the other is for.
- Bad, because a format change now takes four PRs.

## More Information

- Also recorded in: [AI 0001](https://github.com/nickprignano/ai-brain/blob/main/docs/knowledge/decisions/0001-adopt-family-kb-format.md) and [Nerdio HCL kit 0021](https://github.com/nickprignano/nerdio-hcl/blob/main/docs/knowledge/decisions/0021-knowledge-base-family.md).
- The owner chose this repo as the AVD KB's home on 2026-10-18. Plan and red team: the "second brain family alignment" plan in the project files.
