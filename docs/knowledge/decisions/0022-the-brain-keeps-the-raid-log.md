---
status: proposed
date: 2026-10-20
decision-makers: [owner]
---

# 0022. The brain keeps each estate's RAID log and action tracker, beside the lifecycle record

## Context and Problem Statement

The owner asked (2026-10-20) for the brain to be the living RAID log (risks, assumptions, issues, dependencies) and the action and decision tracker for an AVD environment. Decisions already have a home in the lifecycle record (C18, [0020](https://github.com/avd-ops/avd-second-brain/pull/45)), findings in C21, a person's dispositions and remediation items in the proposed C23 and C24, and the why of a change in avd-swarm's plans. Nothing holds risks, assumptions, issues, dependencies and actions with an owner, a due date and a status, linked to those records. Where does that register live, and how does it stay optional? The scope is the AVD environment itself; the owner keeps the project's own RAID log privately, outside this repo (2026-10-20).

## Considered Options

- A sibling contract, C25 `avd-raid-log/v1`, one per estate in its vault, linked by ID to C18, C21, C23, C24 and avd-swarm plans
- Extend C18 to v2 with RAID and action arrays, one per environment
- GitHub issues in the estate's private vault repo as the store

## Decision Outcome

Chosen option: "a sibling contract, C25", because RAID items are often estate-wide while C18 is one environment, because a working list that changes weekly shouldn't churn a history record, and because each can be absent without breaking the other. Decisions stay in C18 only. GitHub issues may become a one-way view later, never the store, since the brain's agents read structured, pseudonymous data. The design is in [docs/raid-spec.md](../../raid-spec.md).

### Consequences

- Good, because the brain can reopen a risk or an assumption when a fact it names changes, and close an action from the evidence of the change that did it, which no RAID template does.
- Good, because the foundation repos and avd-swarm need no change: the brain reads what they already write.
- Good, because each row carries a ULID, so the private project ledger and an estate's log can cite each other's rows without sharing a store or copying text.
- Bad, because it is one more contract to keep, and it waits on C18 (#45) and on avd-assess publishing C23 and C24.

## More Information

Prior art: CAF Govern's [risk register fields and review rhythm](https://learn.microsoft.com/azure/cloud-adoption-framework/govern/assess-cloud-risks), Azure Advisor's [recommendation states](https://learn.microsoft.com/azure/advisor/advisor-azure-state-management) (marked done versus verified), and Well-Architected's [advice to track recommendations in a backlog](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations). Pair: none needed now; a plan naming the action it serves would be a paired avd-swarm change later.
