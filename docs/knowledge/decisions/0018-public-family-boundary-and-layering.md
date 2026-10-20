---
status: proposed
date: 2026-10-20
decision-makers: [owner]
---

# 0018. The public family ends at its contracts; work outside it builds on them and never the reverse

## Context and Problem Statement

The public AVD family (avd-landing-zone, avd-current-state, avd-second-brain, avd-swarm and
avd-liquidware, shown on avd-ops.dev) is free and open source. Some work that builds on it, such
as measured assessment and turning a measured estate into a target-state design, may stay outside
the family, and how that work is offered is undecided. Today the family's public text and checks
still name, describe and even fetch repos outside it, and the formats that cross that line are
only partly in the brain: the intake facts have no schema, and the measured input a design needs
has no contract at all. Where is the line, and which way may dependencies cross it?

## Considered Options

- Public contracts name the producing repo, and family repos may fetch or link repos outside the family
- The family ends at its contracts: they name a producer by its role, every format that crosses the
  line is a brain contract, and nothing in the family depends on, fetches or describes work outside it

## Decision Outcome

Chosen option: "The family ends at its contracts", because a public repo that depends on or
describes work outside the family breaks the day that work moves, and a hook in the brain lets
anything build on the family without the family knowing what it is.

- **Dependencies point one way.** Work outside the family reads the family's contracts and outputs
  at pinned commits. No family script, workflow, source list or test fetches, imports or requires a
  repo outside the family, and every family step runs without one.
- **Contracts name roles, not repos.** C12, C14 and the sizing evidence say "the assessment that
  produces it", not a repository. Schema enum values stay; only descriptions change, in one pin
  bump for the vendored copies.
- **Every format that crosses the line is a brain contract**, with a schema, a synthetic example
  and a `Test-` check here, as decision [0005](0005-one-schema-registry-and-fact-register.md)
  already requires. Two are missing and will be specified:
  - **Intake:** what telemetry can't know (residency, preferred regions, existing hub, identity
    constraints, working hours). The register's five `intake.*` facts get a contract and paths.
  - **Measured usage:** per-user and per-host demand by group (CPU, memory, IOPS, logon, UX,
    concurrency), as measures with their percentiles, never as tiers, and with "not measured"
    when a source can't supply a value. Tiers stay a decision made with
    `knowledge/rules/workload-tiers.json`. Its test uses two synthetic producers, so the format
    doesn't drift into one tool's export.
- **The free baseline assessment is data, not a new repo:** avd-current-state's C11 facts and its
  manifest coverage line, plus the intake contract. Whether a free tool also writes a baseline
  manifest from those (the decisions Azure facts and intake can support) is left open.
- **Public text names the boundary only.** A family repo may say that measured assessment and
  design are outside the family and link avd-ops.dev for it; it doesn't describe what that work
  does or plans.
- **Liquidware stays the only partner.** The family deploys and checks Liquidware products
  (avd-liquidware); assessment work that uses them is outside the family.

### Consequences

- Good, because work outside the family can move, rename or open up without a family PR.
- Good, because the brain's checks cover every format that crosses the line, so a producer
  outside the family can't silently change one.
- Bad, because the cleanup touches several repos at once: `sources/sources.json`, `family.yaml`,
  `docs/contracts.md` and two schema descriptions here, the vendored copy and pins in
  avd-landing-zone, the upsell text and its test in avd-current-state, and avd-swarm's docs.
- Neutral, because no contract's shape changes in this record; the two new contracts are
  specified in their own PR with their schemas and tests.

## More Information

- Follow-up PR set (linked, per [0005](0005-one-schema-registry-and-fact-register.md)): avd-second-brain,
  avd-landing-zone, avd-current-state, avd-swarm and avd-ops. Pair: avd-swarm docs change in the
  same set (decision [0003](0003-brain-thinks-swarm-acts.md)); no swarm behavior changes.
- Revisit if a family repo ever needs work from outside the family to run: that need becomes a
  contract here, not a dependency there.
