---
status: accepted
date: 2026-10-20
decision-makers: [owner]
---

# 0021. The foundation's contracts live in avd-assess

## Context and Problem Statement

Decision 0005 made this repo the one registry of cross-repo formats. The foundation repos (avd-landing-zone, avd-current-state, avd-assess) already run without the brain, because they carry pinned copies, but the home of their own formats sat in the layer above them: changing or retiring the brain would leave the foundation nowhere to evolve its schemas. The owner asked on 2026-10-20 for a shared schema that works with or without the brain and avd-swarm, supports their use cases without requiring them, and treats what comes from above as guidance that fails open, like a domain Group Policy over local policy. Where should the formats the foundation exchanges live?

## Considered Options

- avd-assess holds the foundation's contracts
- A new contracts-only repo
- This repo stays the authority for every contract

## Decision Outcome

Chosen option: "avd-assess holds the foundation's contracts" (owner, 2026-10-20), because avd-assess depends on nothing, never runs anything, and is already the standards both engines read; the formats they exchange are standards too, and no new repo is needed.

- **avd-assess `contracts/` is the authority** for C11 (current-state facts), C15 (the fact register), C17 (run records and cost), C19 (intake), C20 (assessment index and method) and C21 (assessment report), and later C22 (the check catalog) and the rebuild map. The numbers stay.
- **This repo vendors them** byte-identical, listed in `contracts/FOUNDATION-PINS.json` with the avd-assess commit and a SHA-256 per file, checked by `tests/Connectors.Tests.ps1`. The first copy is the same bytes this repo held, so nothing changed for any consumer.
- **This repo keeps its own:** C4, C8 to C10, C12, C13, C14 (the target state, which the landing zone reads when one is given), C16 and C18.
- **Rules for every foundation contract** are in avd-assess `contracts/README.md`: upstream data only in optional extension points, readers that ignore what they don't know, upstream input applied when present and valid and otherwise dropped with a warning, precedence baseline then guidance then the operator's explicit choice, and a floor guidance never lowers.
- Decision 0005 stands for one fact register (one list of IDs) and for this repo as the registry of the upper layers' formats; its "this repo is the one registry of cross-repo formats" is narrowed by this decision.

### Consequences

- Good, because the landing zone and avd-current-state pair, with avd-assess, stays whole if the brain or avd-swarm changes or goes away.
- Good, because the fail-open rules are written where every producer reads them.
- Bad, because a foundation contract change now starts in avd-assess and reaches this repo as a pin bump, one more step than before.
- The fact register still lists the upper tiers (`c12.*`, partner facts) in the same file. Splitting them into an extension file this repo owns is a later change; no foundation tool needs those facts.
- avd-current-state and avd-landing-zone keep their current pins (older brain commits, same formats) and switch their `source` to avd-assess at their next pin bump.

## More Information

- Pair: avd-assess, same branch name, "Hold the foundation contracts here"; avd-swarm, a pointer update (it cites C15 IDs). Design: the foundation wiring note (2026-10-20), with the Group Policy model.
