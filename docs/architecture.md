# Architecture: one brain for the AVD lifecycle

- **Status:** Proposed ([decision 0001](decisions/0001-one-brain-for-the-avd-lifecycle.md)). The knowledge base, the vault, the connectors and the cross-repo search are built and tested offline; nothing has run against a real estate yet.
- **Date:** 2026-10-16

> Personal project. Not affiliated with, endorsed by or supported by the author's employer, Liquidware or Microsoft.

## 1. Why one brain

Three repositories each grew their own "second brain":

| Repo | Its brain | State |
|---|---|---|
| [avd-current-state](https://github.com/nickprignano/avd-current-state) | A Markdown vault per customer, built from collector and validator runs: environments, drift, findings, decisions, runbooks | Built |
| [avd-landing-zone](https://github.com/nickprignano/avd-landing-zone) | An operations brain for a running landing zone: detections, playbooks, approvals, episodes | Specified |
| [avd-readiness-stratusphere](https://github.com/nickprignano/avd-readiness-stratusphere) | The migration factory's knowledge: app catalog, rules, sizing calibration | Built |

They are the same idea at different points of one lifecycle: **assess → inventory → design → deploy → operate**, then assess again. Kept apart, they can't learn from each other. An app that broke in a pilot doesn't warn the image pipeline. Day-2 utilization doesn't correct the next sizing estimate. A runbook one customer's team wrote doesn't help the next customer. **avd-second-brain** is where they meet: one home for the brain's code, its knowledge and the contracts between the repos. The repos keep their sensors and runtimes.

## 2. The lifecycle and who does what

```
          ┌──────────────── avd-second-brain (this repo) ────────────────┐
          │  knowledge/  catalog · rules · calibration · runbooks ·       │
          │              engagements (org forks)                          │
          │  vault/      estate vault tool + template                     │
          │  contracts/  what the repos exchange                          │
          │  scripts/    guard · search · sync · harvest · import         │
          └──▲──────────────▲───────────────▲─────────────────▲──────────┘
     harvest │ reads    ingest│ harvest  evidence│ lessons     │ reads
             │              │               │                 │
 ┌───────────┴───┐ ┌────────┴──────┐ ┌──────┴─────────────────┴──────┐
 │ stratusphere  │ │ current-state │ │ landing-zone                  │
 │ ASSESS/DESIGN │ │ INVENTORY     │ │ DEPLOY/OPERATE                │
 │ instrument,   │ │ collector,    │ │ IaC, preflight, operations    │
 │ factory       │ │ validator     │ │ brain runtime (in-tenant)     │
 └───────────────┘ └───────────────┘ └───────────────────────────────┘
```

| Stage | Repo (sensor or runtime) | Feeds the brain | Reads from the brain |
|---|---|---|---|
| Assess and design | avd-readiness-stratusphere | Engagement harvests; sizing evidence from the verify stage; the forensic facts tier for performance and sizing (C12); target-state manifests for the landing zone (C14), harvested as buckets only; lessons | Catalog, rules, calibration (pinned by commit); the fact register (C15) |
| Instrument | [avd-liquidware](https://github.com/nickprignano/avd-liquidware) (the Stratusphere UX appliances and Connector ID Key rollout, moving there from avd-readiness-stratusphere; the optional ProfileUnity tier) | Lessons; `liquidware.*` facts once built (proposed in C15) | Its block of the manifest (C14), later |
| Inventory and validate | avd-current-state | Evidence packages into a customer vault (C1); the redacted facts snapshot the brain's agents read (C11) | The fact register (C15), for its manifest coverage line |
| Deploy | avd-landing-zone | Lessons and decisions | Workload tiers and calibration for its sizing defaults; catalog for the image pipeline; approved manifests (C14) through its reader |
| Operate | avd-landing-zone (operations brain, [spec](operations-spec.md)) | Sizing evidence from day-2 baselines; episodes that became lessons | The same, plus shared runbooks |
| Act and control | [avd-swarm](https://github.com/nickprignano/avd-swarm) (agents, approval, executor, kill switch) | Insights, incidents and grading scores (C8); action outcomes and switch position (C10) | Playbook run proposals (C9), knowledge with citations (C6, C7) |

**The brain thinks, avd-swarm acts** ([decision 0003](decisions/0003-brain-thinks-swarm-acts.md)). The brain senses, remembers, reasons and learns, and proposes; avd-swarm is the only thing that changes an estate, through a person's approval of the exact plan, and its kill switch is the one both obey. They change in pairs.

## 3. Layers and scopes

The brain has three stores. They differ in **whose data they hold**, and so in where they may live.

| Layer | Holds | Lives in | Visibility |
|---|---|---|---|
| **Knowledge** (`knowledge/`) | Generalized, cross-customer knowledge: public products, rules with their history, calibration, shared runbooks, pseudonymous engagement records | This repo (public scope) and an organization's private fork (organization scope) | Public: no engagement trail. Organization: no customer data. The guard enforces both ([knowledge spec](knowledge-spec.md) §5) |
| **Estate vault** (`vault/`) | One customer's estate: subscriptions, resources, drift, findings, their decisions and runbooks | A private repository per customer or organization, built by `vault/avd_second_brain.ps1` | Private, tenant data |
| **Operations memory** | Signals, episodes, evidence of a running landing zone | The adopter's tenant (Blob, Cosmos DB) and private landing-zone fork ([operations spec](operations-spec.md) §4.3) | Private, tenant data |

The factory's engagement folders (`output/engagements/` in avd-readiness-stratusphere) are a fourth, temporary store, on the customer's side.

**Knowledge moves up only by a reviewed PR, after it is generalized.** Tenant data never leaves the vault, the tenant or the engagement folder. What crosses is a bucket, a VM family, a check name, a public product, a rule change with its reason, or a runbook with the customer taken out.

## 4. The flows

| # | Flow | How | Status |
|---|---|---|---|
| 1 | avd-current-state packages → estate vault | `vault/avd_second_brain.ps1 -PackagePath` ([vault](vault.md)) | Built |
| 2 | Estate vault → knowledge | `scripts/Get-VaultHarvest.ps1` proposes generalized estate facts, recurring findings, and runbook and lesson candidates; a person copies what they keep and opens a PR | Built |
| 3 | Knowledge → estate vault | `vault/avd_second_brain.ps1 -Init` copies `knowledge/runbooks/` into the vault; matching findings link them | Built |
| 4 | Factory engagement → knowledge | The `harvest` skill drafts catalog evidence, rule changes, lessons and the engagement record ([knowledge spec](knowledge-spec.md) §6) | Built (skill and guard); the engine's `avdmf learn` comes with the factory engine |
| 5 | Measured utilization → calibration | `avd-sizing-evidence/v1` ([contracts](contracts.md) C4) from the factory's verify stage and from the operations brain, imported by `scripts/Import-SizingEvidence.ps1` | Importer built; producers specified |
| 6 | Knowledge → factory and landing zone | They read `knowledge/` at a pinned commit ([contracts](contracts.md) C6) | Specified |
| 8 | avd-swarm → brain | `avd-swarm-insights/v1` ([contracts](contracts.md) C8), action outcomes and the switch position (C10) | Specified |
| 9 | Brain → avd-swarm | Playbook run proposals ([contracts](contracts.md) C9); the Concierge as a read tool | Specified |
| 10 | avd-current-state → brain agents → avd-swarm | `avd-current-state-facts/v1` ([contracts](contracts.md) C11): the fact layer the brain's agents read, filed in the vault by `scripts/Import-CurrentStateFacts.ps1`; avd-swarm sees it only as the brain's cited evidence | Built (offline) |
| 11 | avd-readiness-stratusphere → brain agents → avd-swarm | `avd-forensic-facts/v1` ([contracts](contracts.md) C12): measured demand, concurrency, logon and profile aggregates per host pool or persona, the forensic tier under C11 | Specified |
| 12 | avd-readiness-stratusphere → avd-landing-zone | `avd-target-state/v1` with its approval ([contracts](contracts.md) C14): the design, every decision citing register facts (C15); the landing zone's reader prints the preflight and `deploy.sh` commands | Schemas, checks and reader built; producer specified |
| 7 | Every repo's lessons and decisions → search | `scripts/Sync-BrainSources.ps1` checks out the repos in `sources/sources.json`; `scripts/Find-BrainKnowledge.ps1` searches them, the knowledge base and optionally a vault, and cites `<repo>@<commit>:<path>` | Built |

Flow 5 needs the landing zone to know which engagement and persona tier a host pool came from. The factory's `lz-cloudnative` renderer tags each host pool with `avdbrain-engagement` and `avdbrain-tier` ([contracts](contracts.md) C5); a host pool without them yields no observation, because there is no prediction to compare with.

## 5. Principles

The three repos already agreed on these; the brain keeps them in one place.

1. **Real runs are the source of truth.** Evidence beats documents, and documents beat a model's guess.
2. **Knowledge is code.** Schemas, a guard in CI, versioned rules with a reason for every change.
3. **Models propose, people approve.** No model writes knowledge, approves a plan or sets a verdict on its own. The operations brain's approval rules ([spec](operations-spec.md) §4.5) are the strictest form of this.
4. **Tenant data stays with the tenant.** Every crossing is generalized and scanned. The brain's agents read current state as C11 facts (pseudonyms and counts), never as the raw packages.
5. **Derived values are computed, not stored.** Calibration factors, recurring-finding counts and harvest proposals are recomputed from their evidence.
6. **PowerShell, no modules, offline tests.** Like the repos it connects.

## 6. Repository layout

```
avd-second-brain/
├── knowledge/          the knowledge base (schemas, catalog, rules, calibration, runbooks, engagements)
├── vault/              avd_second_brain.ps1 and the vault template (from avd-current-state)
├── contracts/schemas/  avd-sizing-evidence/v1, avd-current-state-facts/v1
├── sources/            sources.json: the connected repos and what each feeds and reads
├── scripts/            AvdBrain.psm1; Test-Knowledge, Find-BrainKnowledge, Sync-BrainSources,
│                       Get-VaultHarvest, Import-SizingEvidence, Import-CurrentStateFacts
├── tests/              Pester: the guard, the connectors, an end-to-end package → vault → harvest run
├── docs/               this page, knowledge-spec, vault, operations-spec (+ red team), contracts, decisions
└── .claude/skills/     harvest
```

## 7. Open questions

- **Q1. Should the operations brain's runtime move here too?** (Its acting half now belongs to avd-swarm, decision 0003; this is about the sensing and reasoning half.) Today its Bicep module and workflows are specified to deploy from the landing zone, because they deploy into it. Moving them would make avd-second-brain a second deployable. Recommendation: no, until a second landing-zone flavor (the `avd-lza` renderer's target) needs the same runtime.
- **Q2. One organization fork, or one per practice?** The knowledge spec recommends one per organization.
- **Q3. Vault per customer, or one vault per organization with environments from many customers?** The vault keys environments by subscription, so both work; per customer keeps access simpler.
- **Q4. Shared playbooks.** The operations brain's playbooks are generic by design. Should verified playbooks and their run statistics become shared knowledge like runbooks? Probably, once two adopters run the same playbook.
