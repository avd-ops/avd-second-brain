---
status: accepted
date: 2026-10-20
decision-makers: [owner]
---

# 0024. The brain is the estate brain: why, RAID, memory, guidance and the KB plumbing

## Context and Problem Statement

Decision 0001 made this repo the meeting point for the whole AVD lifecycle. It grew to match: the migration factory's engine knowledge, the foundation's schemas, docs consistency and a handbook for every repo, and project tracking, beside the estate vault and the why layer. The owner said on 2026-10-20 that much of it should not be here. The brain is the layer that understands why an AVD environment is built and performs as it does, and it keeps that environment's RAID log. The foundation (avd-assess, avd-current-state, avd-landing-zone) is the baseline and the plumbing, and it works with or without the brain. What belongs in this repo?

## Considered Options

- Narrow the repo to the estate brain and the KB plumbing, and move the rest to the repos that own it
- Keep everything here and document which parts are the estate brain
- Split the KB plumbing into a repo of its own as well

## Decision Outcome

Chosen option: "Narrow the repo to the estate brain and the KB plumbing" (owner, 2026-10-20, on the [restructure proposal](../../restructure-proposal.md) and its defaults), because each piece then lives with the repo that owns its job, and the foundation never has a reason to read the brain.

- **The brain keeps five jobs.** The why of each environment (C18, decision 0020). The living RAID log and the action and decision tracker for each operated estate (C25, decision 0022). The estate's memory: the vault, filed C11 and C12 facts, and C21 reports. Fail-open guidance on top of the foundation: calibration, runbooks, playbooks and the app catalog. And the knowledge base plumbing: the family KB tooling, sweeps, curator, leak checks, kb-capture and handoffs, the decisions that govern them, and the AVD knowledge base they maintain.
- **Moves.** The foundation contracts go to avd-assess (decision 0021), and so do C22 to C24, the sizing prior and the quality gate (avd-assess `baselines.yaml`), and the avd-assess spec. Docs consistency, the handbook and C13 (decision 0004) go to avd-ops, paired with avd-swarm for its Scribe. C16 goes to avd-liquidware. The migration factory's engine knowledge goes to the private assessment factory repo: the delivery rule, engagements, the harvest skill, C3, C5, C6 and the knowledge spec.
- **The project's own working log is private.** That covers its risks, open actions, PR dependencies and what waits on the owner. Public docs keep the settled outcome. Decision history stays public.
- **How things move.** Each move is copied to its new home and merged there first. It is then replaced here by a stub that links to it, so the last copy is never deleted. Pins move in the same PR.
- This decision narrows 0001. The other decisions stand: 0003, 0005 as narrowed by 0021, 0006 to 0015, 0019 to 0023.

### Consequences

- Good, because the repo says one thing: what an estate is for, what went into it and what is open on it.
- Good, because the foundation pair has nothing in the brain that it could come to depend on.
- Bad, because readers of the old paths follow a stub for a while, and pinned consumers need a bump.
- Neutral: C14 stays here until the factory producer is built (gray area G1). `knowledge/` is renamed `guidance/` last, if at all (G9).

## More Information

- The audit, the gray areas G1 to G9 with their defaults, and the move steps R1 to R7: [docs/restructure-proposal.md](../../restructure-proposal.md).
- Decision 0018 (PR #41, where the public family ends) is on the private side. It closes unmerged, and its substance goes to the private log (G8).
