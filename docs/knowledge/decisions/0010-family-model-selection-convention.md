---
status: accepted
date: 2026-10-18
decision-makers: [owner]
---

# 0010. Follow the family's model-selection convention, as one of its four pilot projects

## Context and Problem Statement

The AVD repos use Claude in two places: Claude sessions that build them, and avd-swarm, whose first spike calls Claude Opus, Sonnet and Haiku 5.5 through Microsoft Foundry or, when Foundry has no quota, through the Claude API with workload identity federation. The brain's own agents are specified but don't call a model yet. The family is piloting one model-selection convention across its four projects, and model choices are the AI KB's topic ([0006](0006-family-kb-format.md)). Do the AVD repos follow it?

## Considered Options

- Follow the convention, with any exception recorded here as a "Model override" decision
- Keep the AVD repos' own model choices

## Decision Outcome

Chosen option: "Follow the convention", because avd-swarm's spike already matches its fallback rules (Foundry first, the Claude API with workload identity federation when quota is missing, no stored API key), and the brain's agents can start on its defaults when they are built.

Also recorded in: [Nerdio HCL kit 0022](https://github.com/nickprignano/nerdio-hcl/blob/main/docs/knowledge/decisions/0022-family-model-selection-convention.md).

For the pilot, the AVD repos:

- Pin full model IDs in config and read model, effort and provider from the environment, when the brain's agents and avd-swarm's runtime are built.
- Log, per request, the model, effort, `usage`, `stop_reason` and latency. Not built yet.
- Keep the rule that a model never decides (the brain's CLAUDE.md): it drafts, and verdicts need evidence.
- File their pilot numbers as feedback on the AI KB's Claude API page.

### Consequences

- Good, because a model change follows evidence and the family's rules.
- Bad, because nothing here logs usage yet, so the AVD pilot numbers come from Claude sessions only until the agents are built.
- Neutral, because no default changes today.

## More Information

- Revisit at the family's pilot review on 2026-12-01.
- Any app here that calls Claude is a paired change with avd-swarm (decision [0003](0003-brain-thinks-swarm-acts.md)), because models and identity are on its paired list.
- Accepted by the owner on 2026-10-21. Pair: [avd-swarm decision 0008](https://github.com/avd-ops/avd-swarm/blob/main/docs/decisions/0008-family-model-selection-convention.md).
