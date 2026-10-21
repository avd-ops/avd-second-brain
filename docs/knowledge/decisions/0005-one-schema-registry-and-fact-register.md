---
status: proposed
date: 2026-10-18
decision-makers: [owner]
---

# 0005. One schema registry and one fact register for every repo

## Context and Problem Statement

The owner asked on 2026-10-18 for the assessment project to become assessment only, producing ready-to-migrate manifests that avd-landing-zone deploys; for the Stratusphere instrument to move to avd-liquidware; for avd-current-state to feed and upsell into the assessment; and for a shared schema and a shared fact register, all feeding this brain. Until now each contract's schema lived here, but the repos named the same facts differently, the factory's manifest (`factory.avd/v1`) existed only as YAML in a spec, and nothing tied a manifest's numbers to the evidence behind them. How do the repos agree on formats and on the names of facts?

## Considered Options

- Each repo keeps its own schemas and fact names
- One registry of cross-repo formats and one fact register, in this repo

## Decision Outcome

Chosen option: "One registry of cross-repo formats and one fact register, in this repo", because a manifest's every number can then cite a fact by one ID that CI checks against the contracts' schemas.

- **This repo is the one registry of cross-repo formats.** `contracts/schemas/` is the authority for every file that crosses a repo boundary, including ones that never reach the brain (C16). Producers and consumers vendor a copy and test against it.
- **The target-state manifest is contract C14** (`avd-target-state/v1`), pseudonymous JSON, with approval as a separate file that pins the manifest's SHA-256 (`avd-target-approval/v1`). It never enters `knowledge/`; harvests take buckets from it.
- **The fact register is contract C15.** One list of fact IDs, tiers, paths and the decisions each can support. Manifests cite facts by these IDs; the register is checked against the contracts' schemas in CI.
- **The renderer for a target we own lives in that target** (the landing zone's reader), and reads the manifest; the factory keeps renderers only for targets without a repo of ours.

### Consequences

- Renaming a C11 field now means changing the register in the same PR, or CI fails.
- C14 and C15 change in the same set of PRs as their producers and readers: the assessment project, avd-landing-zone and avd-current-state, plus avd-swarm for anything it cites.
- avd-swarm doesn't read manifests yet. Deploying one through the swarm is its own spec: catalog action, roles and gate rows.
- `knowledge/` now refuses estate pseudonyms, which also catches a C11 snapshot pasted into a runbook.

## More Information

- **Pair:** the assessment project's decision 0003 (the repo boundaries), avd-swarm spec §6d. The set merges together or not at all.
- Moved here from `docs/decisions/` and converted to MADR 4; the decision itself is unchanged.
