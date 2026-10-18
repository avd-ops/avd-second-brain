---
status: accepted
date: 2026-10-18
decision-makers: [owner]
---

# 0003. The brain is the intelligence layer; avd-swarm is the actor and control layer

## Context and Problem Statement

The operations spec ([operations-spec.md](../../operations-spec.md)) gave the brain its own way to act: an orchestrator that runs approved plans, one executor identity per playbook, a kill switch (EX-0004) and a watchdog. [avd-swarm](https://github.com/nickprignano/avd-swarm) was then specified with the same pieces: a plan store, an approval environment, a write identity, a governance gate, an external observer and a four-position kill switch. Two write paths, two kill switches and two front ends for one estate would drift apart, and each would be half as tested. Which of the two acts on an estate?

## Considered Options

- Both act: the brain keeps its own executors and kill switch beside avd-swarm's
- The brain thinks, avd-swarm acts and controls

## Decision Outcome

Chosen option: "The brain thinks, avd-swarm acts and controls", because one write path and one kill switch can be tested, drilled and red-teamed properly. The owner decided on 2026-10-18: the brain is the intelligence layer of the swarm, the swarm is the actor and control layer, and a change in one is integrated into the other.

- **The brain thinks.** Sense, remember, reason, learn and evolve stay here: detections, signals and episodes, the knowledge base, vaults, calibration, lessons, the Triage, Diagnose, Critic, Retro and Evolve agents, the playbooks as tested procedure, the evals, and the grading of model output (the judge's auditor, avd-swarm spec §6b). The brain proposes; it never holds a write credential.
- **avd-swarm acts and controls.** Every change to an estate goes through avd-swarm: the governance gate, the person's approval of the exact plan, the write identities, the executor, verification and rollback, the observer, the kill switch and the watchdog. Pre-approved exceptions (§4.5.1) are policy about acting, so their runtime is the swarm's; the brain keeps their definitions' history and their run records as episodes.
- **One front end.** Operators talk to avd-swarm (avd-buddy, Teams, MCP clients). The Concierge becomes a read tool the swarm's coordinator calls, answering from the brain with citations.
- **One kill switch.** avd-swarm's (four positions). The brain obeys it: `halt-actions` stops its plan proposals, `halt-agents` and `halt-all` stop its model calls; sensing and recording never stop. The cost safeties (EX-0001, EX-0002) stay outside both switches, as before.
- **The handoff is a contract**, not shared code: C8 (swarm → brain: insights, incidents and grading scores, counts only), C9 (brain → swarm: a playbook run proposal), C10 (swarm → brain: switch position and action outcomes). See [contracts.md](../../contracts.md).
- **Paired changes.** A change here to a contract, a playbook's shape, an agent's role, grading, models or identity comes with the matching avd-swarm change, and each PR links the other. avd-swarm is a connected source (`sources/sources.json`), so its docs are searchable here.

### Defaults where it forks

- **A brain without avd-swarm is advisory.** It senses, diagnoses and proposes, and gives people Cloud Shell blocks to run themselves. It doesn't act. (Before this decision, the brain's Tier 2 acted on its own.)
- **Playbooks stay brain knowledge;** the swarm's action catalog is the set of primitives (drain, restart, Run Command by hash) a playbook may use. A playbook that needs an action the catalog lacks is a paired PR.

### Consequences

- Operations spec §4.1's Tier 2 and Tier 3 executors, §4.5's executor and §4.5.1's EX-0004 move to avd-swarm; that spec now says so where they are described, and is rewritten section by section as each is built.
- One approval path and one kill switch to test, drill and red-team.
- The brain depends on avd-swarm to act. An estate that wants self-healing deploys both.

## More Information

- **Pair:** [avd-swarm decision 0003](https://github.com/nickprignano/avd-swarm/blob/main/docs/decisions/0003-swarm-acts-brain-thinks.md) says the same from the other side. The two change together.
- Accepted by the owner on 2026-10-18, together with avd-swarm decision 0003. Moved here from `docs/decisions/` and converted to MADR 4; the decision itself is unchanged.
