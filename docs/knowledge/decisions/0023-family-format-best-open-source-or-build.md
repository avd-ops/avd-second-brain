---
status: accepted
date: 2026-10-20
decision-makers: [owner]
---

# 0023. Adopt an outside tool only when it is the best and open source; otherwise build our own

## Context and Problem Statement

The prior-art check before building ([0012](0012-family-format-project-lanes.md) and the AGENTS.md rule) keeps finding outside tools that overlap with ours: Azure Resource Inventory (ARI) for inventory and diagrams, WARA for the Well-Architected review, the agent governance toolkit for the gate, Azure SRE Agent for investigations. Each time, the question "adopt, wrap or build" was answered case by case. On 2026-10-20 the ARI case went three ways in one afternoon (wrap it, then a bake-off where Mermaid drew the estate more accurately, then "we need our own inventory"). What rule decides it for every repo in the avd-ops family?

## Considered Options

- Adopt an outside tool only when it is the best at the job and open source; otherwise build our own, or use another open source tool that is
- Adopt whatever is best known, open source or not
- Always build our own

## Decision Outcome

Chosen option: "Adopt only the best, and only if open source", because the family is free and open source and an adopter must be able to read, run and fork everything it depends on, and because a well-known tool that is second best at our job costs more to work around than to replace. The owner's words: "if ari is the top of the line and open source ok, otherwise we build our own/something else that is open source instead. should be the standing convention for the avd-ops family."

How to apply it:

- **Best means best at our job,** checked against our own requirements (redaction before anything leaves the estate, contract-shaped output, Cloud Shell, offline tests), by a side-by-side run on the same fixture where one is possible. Being well known is not the test.
- **Open source means a license we can read in the repo** (MIT, Apache-2.0 and the like). A package whose published license differs from its repo's is checked before anything is copied.
- **A paid or closed service** (Azure SRE Agent, for example) can only be an optional add-on that no free repo depends on, never the thing that does the job.
- **When we build, the outside tool becomes the parity checklist:** ours has to do what it does. What we add can be offered upstream, and only the owner sends it.
- **Microsoft's own platform** (Azure, Resource Graph, Learn, the Azure MCP Server) is the platform we build on, not a tool this decision weighs.

Applied first to ARI ([v1 review D18](../../v1-review.md#7-decisions-only-the-owner-can-make)): it is not the best at our inventory job (no redacted, contract-shaped output) or at drawing the estate (Mermaid was more accurate), so avd-current-state builds its own inventory from Resource Graph and draws in Mermaid with Azure icons, with ARI as the parity checklist.

### Consequences

- Good, because adopt-or-build is decided once, the same way in every repo, and a bake-off settles it instead of a name.
- Good, because every dependency an adopter takes on stays open source.
- Bad, because building our own means more code to keep; the parity checklist and the upstream offers are how that cost is kept honest.
