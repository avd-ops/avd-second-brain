---
status: proposed
date: 2026-10-20
decision-makers: [owner]
---

# 0019. Basic recovery testing and failover run through avd-swarm; the brain judges what the results mean

## Context and Problem Statement

Azure Virtual Desktop has no native disaster recovery; the operator builds it from other Azure services and has to prove it by testing ([Microsoft Learn, AVD BCDR concepts](https://learn.microsoft.com/azure/virtual-desktop/disaster-recovery-concepts); [multiregion BCDR guide](https://learn.microsoft.com/azure/architecture/example-scenario/azure-virtual-desktop/azure-virtual-desktop-multi-region-bcdr): "treat these examples as estimates... validate them through DR testing"). avd-landing-zone's recovery spec (draft PR #75) defines what to protect, the tiers R0 to R2, a read-only status check and tests an operator runs by hand. A test run by hand happens as often as someone remembers, and a failover typed under pressure has no gate. The owner decided on 2026-10-20 that basic recovery testing and failover are part of avd-swarm and that more advanced recovery builds on that. Where does each part live, and what does the brain do with the results?

## Considered Options

- Leave recovery to the landing zone's Cloud Shell blocks only
- Give the brain its own recovery playbooks and executor
- The landing zone owns recovery, avd-swarm runs it as catalog actions, the brain judges the results over time

## Decision Outcome

Chosen option: "The landing zone owns recovery, avd-swarm runs it, the brain judges the results", because it keeps one write path and one kill switch ([0003](0003-brain-thinks-swarm-acts.md)) and one implementation of every restore.

- **Why avd-swarm.** A recovery test creates resources and spends money, and a failover moves every user to another pool: both are changes, so they go through the gate, a person's approval of the exact plan, the observer and the kill switch like every other change. The how is in [avd-swarm's recovery spec](https://github.com/avd-ops/avd-swarm/blob/main/docs/recovery.md) and its decision 0006.
- **Why not the brain.** The brain never holds a write credential (0003). Its part is the long view: which tier each estate holds, whether tests keep passing, whether the measured recovery time is growing, and what the family learns from a failure.
- **A tier counts as met only when a test proved it.** The brain treats a tier claimed without a passing test, measured in the landing zone's run record, as unmet, the same rule as the landing zone's (its recovery spec D3).
- **Recovery never depends on avd-swarm being up.** In a region outage avd-swarm may be down too; the landing zone's Cloud Shell blocks stay the primary path, and avd-swarm fails closed.
- **Scope.** The public family covers any region and subscription in the operator's own tenant. Anything beyond that, or a run no person asked for, is outside the public family and can only build on avd-swarm's hooks.

### Consequences

- Good, because recovery gets the same evidence, approvals and teardown as any other change, and its results reach the brain as outcomes (C10), counts (C8) and the landing zone's run record (C17, use case `recovery`), with no contract change.
- Good, because the brain can say, with citations, whether an estate is recoverable today, not just whether it was designed to be.
- Bad, because failover needs a swarm identity that writes role assignments (application group assignments are Azure role assignments), which the operations spec's guardrails rule out today. avd-swarm proposes an ABAC-conditioned exception limited to one role, named groups and named application groups; it waits on the owner.
- Bad, because nothing is testable in the project's sandbox beyond one region until its region policy changes.

## More Information

Pair: [avd-swarm decision 0006](https://github.com/avd-ops/avd-swarm/blob/main/docs/decisions/0006-recovery-tests-and-failover.md) and its [recovery spec](https://github.com/avd-ops/avd-swarm/blob/main/docs/recovery.md). Builds on avd-landing-zone's recovery spec (draft PR #75), this repo's KB facts on backup and recovery (draft PR #39) and the `recovery` use case for C17 (draft PR #40). Revisit when the first real recovery test has run.
