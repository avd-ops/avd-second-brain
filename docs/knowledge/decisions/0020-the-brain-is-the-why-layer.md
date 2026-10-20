---
status: proposed
date: 2026-10-20
decision-makers: [owner]
---

# 0020. The brain is the why layer: one lifecycle record per environment, from its birth

## Context and Problem Statement

The owner set the brain's role on 2026-10-20: avd-second-brain is the layer that understands why AVD is built and performing the way it is, including its use cases and the decisions made in building, configuring, expanding, contracting and fixing the environment, from the time it is born onwards; avd-swarm is the how.

Most of the pieces exist but don't connect into a why. C11 and C12 say what an environment is and how it performs. C14 records the design decisions with their evidence, but only for the day it is designed, and with no alternatives. C17 records runs and avd-swarm's C10 records plan outcomes: what was done, not why. The vault has free-text ADRs and an environment "purpose" note, which people can read but the brain's agents can't, because they read only pseudonymous facts (C11). So the brain can't answer "why is this host pool ten E8 hosts?", can't say which change no one decided, and can't tell when the reason behind a decision has gone away. How does the brain hold the why?

## Considered Options

- A pseudonymous lifecycle record per environment (contract C18) that links use cases, decisions and events to the facts, runs, plans and manifests that already exist
- Keep the why in the vault's free-text ADRs and let a model read them
- Extend C14 so the manifest carries every later decision too

## Decision Outcome

Chosen option: "A pseudonymous lifecycle record per environment", because it reuses every existing contract by reference instead of copying it, keeps tenant data in the vault, and gives the agents a why they can cite and the checks a gap they can find.

- **Brain = why, avd-swarm = how.** The brain keeps the use cases, the decisions (chosen, alternatives with why not, drivers, evidence, watched facts) and the events that carried them out, across assess, design, build, configure, expand, contract, fix, recover and retire. avd-swarm records how each change was done (its plan, gate, approval and C10 outcome) and every plan says which decision it carries out. Paired with [avd-swarm decision 0007](https://github.com/nickprignano/avd-swarm/blob/main/docs/decisions/0007-every-plan-says-why.md).
- **One record per environment, born once.** `avd-lifecycle-record/v1` ([contracts](../../contracts.md) C18), filed in the estate vault under `lifecycle/`, never in `knowledge/`. Its first decisions come from the approved C14 manifest (`ConvertFrom-TargetStateDecision`).
- **Reuse, don't rebuild.** Facts by C15 register ID, runs by C17 run ID, plans by avd-swarm plan ID, manifests by hash, lessons by C7 citation, the vault's ADRs by number. The record adds only what none of them has: the use cases, the alternatives and the link from each change to its decision.
- **Gaps are findings.** A change no decision explains and an accepted decision with no alternatives are warnings the brain puts in front of a person. A watched fact that changes reopens its decision (`Get-LifecycleReview`) as a Notice, never an action.
- **The pair stays self-contained.** avd-landing-zone and avd-current-state deploy, inventory and validate with no brain and no avd-swarm, and keep doing so. The record only reads what they already emit (C17 run IDs, C11 snapshots); nothing there reads or requires it.

### Consequences

- Good, because "why is it like this" gets an answer with citations, and "what changed that nobody decided" becomes a check.
- Good, because a decision whose reason has gone away (the peak it was sized for, the round-trip time that picked the region) comes back for review.
- Good, because generalized patterns (which alternatives lose and why, which expansions follow which use cases) can be harvested as buckets later, like engagements.
- Bad, because someone has to record alternatives and decisions for manual changes; the warnings nag until they do.
- Bad, because a value or a note can still hold a name the guard doesn't know. Same limit as C14 notes: the record stays in the private vault and harvests drop notes and values.

## More Information

- **Pair:** [avd-swarm decision 0007](https://github.com/nickprignano/avd-swarm/blob/main/docs/decisions/0007-every-plan-says-why.md) says the same from the other side. The two change together (decision 0003).
- Built offline: the schema, the example, `Test-LifecycleRecord`, `Get-LifecycleExplanation`, `Get-LifecycleReview`, `ConvertFrom-TargetStateDecision` and their tests in `tests/Connectors.Tests.ps1`. The writers from C17, the vault's `/capture` and avd-swarm's C10 are specified, not built, and follow the build order (avd-swarm spec §9a).
- Open: whether C14 should carry alternatives so the record starts complete ([architecture](../../architecture.md) Q5).
