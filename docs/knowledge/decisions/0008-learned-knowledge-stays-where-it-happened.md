---
status: accepted
date: 2026-10-18
decision-makers: [owner]
---

# 0008. Learned knowledge stays where it happened; this KB links and watches

## Context and Problem Statement

avd-landing-zone has about thirty lessons and its own decisions, each tied to the code and the run that taught it; avd-swarm and avd-current-state keep their own decisions too. The family KB here covers the whole AVD lifecycle. Should those lessons and decisions move into this KB, be copied, or stay where they are?

## Considered Options

- Move them into this KB
- Copy them here and keep both
- Leave them where they happened; this KB links to them and watches them

## Decision Outcome

Chosen option: "Leave them where they happened", because a lesson sits next to the guard and the code it changed, moving it breaks the links those repos already have, and a copy drifts.

- Topic pages link the lessons and decisions that apply to them, at the repo they live in.
- [sources.toml](../sources.toml) watches avd-landing-zone's `docs/lessons` and `docs/decisions` and avd-swarm's `docs/decisions`, so a new one shows up in the weekly digest.
- A decision that binds more than one repo is recorded in each affected KB or repo, and each copy says "Also recorded in" with links. Paired decisions with avd-swarm keep their "Pair:" line.

### Consequences

- Good, because nothing in the connected repos moves.
- Bad, because a reader follows a link out of this KB for the detail.
- Neutral, because the brain's search (`scripts/Find-BrainKnowledge.ps1`) already indexes those folders in place.

## More Information

- The same rule the Nerdio HCL kit and the AI KB follow: link a sibling's page instead of copying it.
