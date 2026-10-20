# Proposal: restructure avd-second-brain around the estate brain

- **Status:** Proposed. Nothing moves or is deleted until the owner approves this proposal and each step's PR.
- **Date:** 2026-10-20
- **Builds on:** decisions [0003](knowledge/decisions/0003-brain-thinks-swarm-acts.md) (the brain thinks, avd-swarm acts), 0020 (the why layer, PR #45), 0021 (foundation contracts in avd-assess, PR #54), 0022 (the estate RAID log, PR #56) and 0023 (adopt the best open source or build).

> Personal project. Research and learning only, not for production, provided as is. Not affiliated with, endorsed by or supported by the author's employer, Liquidware or Microsoft.

## 1. What the brain is for

The owner's description (2026-10-20), which this proposal measures every file against:

1. **The why of each AVD environment.** Use cases, and the decisions made building, configuring, expanding, contracting and fixing it, from its birth onward (C18).
2. **The living RAID log and action and decision tracker for the AVD environment itself**, one per operated estate (C25). Not for the avd-ops repos: the RAID and decision log of building the project stays in the owner's private project repo.
3. **The estate's memory**, the evidence the why and the RAID log cite: the estate vault, filed C11 facts, C12 forensic facts, C21 assessment reports.
4. **Fail-open guidance on top of the foundation.** Intelligence and evolution (calibration learned from evidence, playbook proposals, insights) that the foundation may apply when present and valid, and ignores otherwise. avd-swarm acts on it; the brain never writes.
5. **The knowledge base plumbing** (owner, 2026-10-20): the family KB tooling, sweeps, curator, leak checks, kb-capture and handoffs, the decisions that govern them, and the AVD knowledge base they maintain.

What it is not: the foundation's standards or schemas (avd-assess), the inventory (avd-current-state), how the estate is built (avd-landing-zone), the front door and family docs (avd-ops), or the project's own working log (private). The foundation pair works with no brain at all, so nothing below may make avd-landing-zone or avd-current-state read the brain.

## 2. Audit: what is here today and where it belongs

Verdicts: **Keep**, **Move** (to the named repo), **Retire** (frozen in place as history with a pointer; never deleted while it is the last copy), **Owner** (a gray area, section 4).

| Area | What it is | Verdict | Where |
|---|---|---|---|
| `vault/`, [vault.md](vault.md), `Import-CurrentStateFacts.ps1`, C1, C2 | The estate vault and its importers | Keep | The home of `lifecycle/` (C18) and `raid/` (C25) |
| C18 (#45), C25 (#56), decisions 0020, 0022 | The why and the RAID log | Keep | Core of the restructured brain |
| C8, C9, C10 | Brain and avd-swarm pair | Keep | Unchanged |
| C12 forensic facts | Measured performance the agents read | Keep | Brain contract |
| C4 sizing evidence, `Import-SizingEvidence.ps1`, `knowledge/calibration/` | Calibration learned from measured estates | Keep | Guidance layer (fail-open over avd-assess baselines) |
| [operations-spec.md](operations-spec.md), [red team](operations-redteam.md) | The operations brain; its acting half already moved to avd-swarm (0003) | Keep, trimmed | Keep detections, episodes, playbooks as guidance; the superseded sections become a short pointer to the avd-swarm spec |
| C11, C15, C17, C19, C20, C21, `run-use-cases.json` | Foundation contracts | Move (under way) | avd-assess is the authority (#54); this repo keeps byte-identical pinned copies |
| C22, C23, C24 (proposed) | Check catalog, review, plan | Move | avd-assess and avd-current-state, never registered here |
| C14 target state | The design the landing zone reads | Owner (G1) | Kept here by 0021 |
| C16 Stratusphere instrument | Between avd-liquidware and the assessment factory; never reaches the brain | Move | avd-liquidware, with its producer |
| `knowledge/rules/workload-tiers.json`, `quality-gate.json` | Baselines and a data-quality gate | Move | avd-assess `baselines.yaml` already holds the same sizing prior with citations; keep one copy there |
| `knowledge/rules/delivery.json`, `knowledge/engagements/`, C3, C5, C6, the `harvest` skill, [knowledge-spec.md](knowledge-spec.md), decision 0002 | The migration factory's engine knowledge and its feed | Owner (G2) | Belongs with the assessment factory, not the estate brain |
| `knowledge/catalog/apps.json` | App compatibility verdicts with evidence | Owner (G3) | Guidance (keep) or a standard (avd-assess) |
| `knowledge/runbooks/` | Shared runbooks copied into new vaults | Keep | Guidance for vaults |
| [assess-spec.md](assess-spec.md) | avd-assess's own spec | Move | avd-assess `docs/`; a stub here points to it |
| [docs-spec.md](docs-spec.md), [red team](docs-redteam.md), `Test-DocConsistency.ps1`, `Update-BrainDocs.ps1`, the 35 `*-Doc*` functions in `AvdBrain.psm1`, `wiki/`, [accepted-findings.json](accepted-findings.json), `docs-check.yml`, `docs-sweep.yml`, C13, decision 0004 | Docs consistency across every repo and the generated handbook | Owner (G4) | Recommended: avd-ops, the front door that already renders the family docs; avd-swarm's Scribe re-points |
| `docs/knowledge/` (topic pages, known errors, upstream asks, experts, curation), `scripts/kb/`, `kb-*.yml`, `family.yaml`, `sources.toml`, `Test-KbLeaks.ps1`, decisions 0006 to 0015 | The family KB and its plumbing | Keep | Owner's steer: the brain keeps the plumbing and its decisions |
| `sources/`, `Sync-BrainSources.ps1`, `Find-BrainKnowledge.ps1`, C7 | Search across the repos' lessons, the KB and a vault | Keep | Plumbing the agents use to cite |
| [docs/knowledge/roadmap.md](knowledge/roadmap.md) | Status of the KB migration (all steps done) | Retire | Settled outcome stays in curation.md; tracking goes private |
| `docs/v1-review.md` (#44), status and "next steps" lines in specs | Owner-decision lists (D1 to D18) and build tracking | Owner (G5) | Public keeps the settled outcome; open items and dates go to the private log |
| [architecture.md](architecture.md), README, decision 0001 | Describe the brain as the hub of the whole lifecycle | Rewrite | Around section 1; 0001 superseded by a new decision 0024 |
| `docs/decisions/`, `docs/lessons/` | Redirect stub, empty lessons folder | Keep | Stubs stay so old links work |
| Mentions of the private assessment repo by name (about 23 files) | Public text naming a private repo | Owner (G6) | Neutral wording |

### Decision records: which side of the public line

The working boundary (from the RAID thread, not yet confirmed by the owner): decisions that explain how the public repos, the contracts and the KB plumbing work stay public; the working log of building the project (risks, open actions, PR dependencies, what waits on the owner, anything on the paid boundary) is private. Decision history stays public: nothing already public is moved into a private repo without the owner's yes.

| Decision | Subject | Side |
|---|---|---|
| 0001 | One brain for the AVD lifecycle | Public; superseded in part by 0024 |
| 0002 | The engine's knowledge base | Public; moves with G2 or is deprecated |
| 0003 | Brain thinks, avd-swarm acts | Public, keep |
| 0004 | Docs consistency | Public; moves with G4 |
| 0005 | One schema registry and fact register | Public, keep (narrowed by 0021) |
| 0006 to 0015 | Family KB format, leak check, model convention, upstream sources, lanes, kb-capture, handoffs, GitHub work | Public, keep (KB plumbing) |
| 0016, 0017 (#37) | Never delete the last copy, never leave the meter running | Public: they are rules every repo follows. Could live in avd-ops beside the family conventions (G7) |
| 0018 (#41) | Where the public family ends | Private side (G8): it is about the public and private line |
| 0019 | Recovery runs through avd-swarm | Public, keep (estate) |
| 0020, 0022 | Why layer, estate RAID log | Public, keep (core) |
| 0021 | Foundation contracts in avd-assess | Public, keep |
| 0023 | Adopt the best open source or build | Public; a family convention, could live in avd-ops (G7) |

## 3. Target structure

```
avd-second-brain/
├── vault/                 the estate vault: environments, facts, lifecycle/ (C18), raid/ (C25)
├── guidance/              fail-open guidance: calibration, runbooks, playbooks (was knowledge/)
├── contracts/             the brain's own formats: C4, C8-C10, C12, C18, C25 (+ C14 if G1 keeps it)
│   └── foundation/        pinned copies from avd-assess, FOUNDATION-PINS.json
├── docs/
│   ├── architecture.md    rewritten around section 1
│   ├── contracts.md       the brain's contracts; foundation ones link to avd-assess
│   ├── vault.md, operations-spec.md (trimmed), lifecycle and raid specs
│   └── knowledge/         the AVD family KB (topic pages, decisions, known errors, curation)
├── scripts/               AvdBrain.psm1 (vault, facts, lifecycle, RAID, calibration, search)
│   └── kb/                the family KB plumbing
└── sources/               the repos and KB pages the brain's search reads
```

Moving `knowledge/` to `guidance/` is a rename for clarity; it is optional and comes last (G9), because every pin and the guard name the old path.

## 4. Gray areas for the owner

Each has a default the move plan follows if the owner says nothing else.

- **G1. C14 target state.** The landing zone reads it, so it is arguably a foundation contract. Default: keep here, as 0021 decided; revisit when the factory producer is built.
- **G2. The migration factory's engine knowledge** (delivery rule, engagements, harvest, C3, C5, C6, knowledge-spec). Default: move to the private assessment factory repo, leaving a public stub, because none of it is about one estate's why.
- **G3. The app catalog.** Default: keep as guidance; it is learned across estates.
- **G4. Docs consistency and the handbook.** Default: move to avd-ops, with a paired avd-swarm PR for the Scribe.
- **G5. Owner-decision lists in public docs** (v1-review D1 to D18, status lines). Default: once answered, each becomes a settled line in its spec; open items live only in the private log.
- **G6. Naming the private assessment repo in public text.** Default: replace with "the assessment factory (private)".
- **G7. Family conventions (0016, 0017, 0023).** Default: stay here, linked from avd-ops.
- **G8. 0018.** Default: close #41 unmerged and keep its substance in the private log.
- **G9. Rename `knowledge/` to `guidance/`.** Default: do it last, or not at all.

## 5. Move plan

Rules for every step: a step is one PR (paired where a contract or the swarm changes); a moved file is copied to its new home and merged there first, then replaced here by a stub that links to it, so the last copy is never deleted and history stays in both repos; pins and hashes are updated in the same PR as the copy; `scripts/kb/build.py`, `Test-Knowledge.ps1` and the Pester suites pass at each step; no step makes the foundation pair read the brain.

| Step | What | Waits on |
|---|---|---|
| R0 | This proposal (doc only) | Owner review |
| R1 | Decision 0024 "The brain is the estate why layer", superseding 0001 in part; rewrite README and architecture.md; retire roadmap.md | R0, #45, #56 |
| R2 | Foundation contracts: finish #54, move `contracts/` pinned copies under `contracts/foundation/`, retarget C22 to C24 | #54 |
| R3 | Baselines: drop `workload-tiers` and `quality-gate` after avd-assess holds them; calibration reads avd-assess's prior | R2, avd-assess PR |
| R4 | Docs consistency and handbook to avd-ops (G4), paired with avd-swarm | Owner on G4; #28 closed or merged first |
| R5 | Assessment factory knowledge out (G2), C16 to avd-liquidware, assess-spec to avd-assess | Owner on G2 |
| R6 | Trim operations-spec; settle v1-review decisions into specs (G5) | #44 merged |
| R7 | Optional rename to `guidance/` (G9) | Everything else |

## 6. Sequence against the open PRs

- **Merge before R1:** #45 (C18) and #56 (C25), the core of the new shape; #44 (v1 review), once its conflict with main is resolved; #54 (foundation contracts).
- **Unaffected, merge any time:** KB pages #39, #49, #51, #52, #55, #58, #34, #38; #33 (kb-auto-merge resync); #40 (C17 use case, which then also lands in avd-assess as the authority).
- **Decide before moving:** #37 (G7), #41 (G8), #29 (claims on every edge; stays with the swarm pair), #28 (handbook refresh; superseded by R4 if G4 moves it).
