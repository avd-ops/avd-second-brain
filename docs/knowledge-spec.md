# Spec: the knowledge base

- **Status:** Proposed (see [decision 0002](knowledge/decisions/0002-knowledge-base.md)). Phase 1 (the knowledge base, its schemas and its guards) is built; nothing in it has been fed by a real engagement yet.
- **Date:** 2026-10-16
- **Builds on:** the migration factory's [spec](https://github.com/nickprignano/avd-readiness-stratusphere/blob/main/docs/factory-spec.md) §10.5 (Learn), where this design started (in avd-readiness-stratusphere). Part of avd-second-brain: the [architecture](architecture.md) shows how this layer connects to the estate vaults and the operations brain. "Factory §n" below refers to the factory spec.

> Personal project. Not affiliated with, endorsed by or supported by the author's employer, Liquidware or Microsoft. Stratusphere, Azure Virtual Desktop, Entra and FSLogix are trademarks of their owners.

## 1. Summary

A migration factory is only a factory if the tenth engagement is easier and more accurate than the first. Today that knowledge lives in people: which apps broke in multi-session, how many sessions an E8 host really carried for a medium persona, which quality-gate threshold was too lax. When the person moves on, the knowledge goes with them.

The **knowledge base** is the organization's long-term memory, shared by the factory, the estate vaults and the operations brain. It holds what the organization learned across engagements, in a form the engine reads and people review:

```
 Engagement ──► Harvest ──► Review (PR) ──► Brain (Git) ──► Engine + people ──► next Engagement
   stages 1–9     stage 10     a person merges   catalog · rules ·     sizing, delivery,
                                                  calibration · lessons  gate, report citations
```

- **It remembers** apps and how they behaved on AVD, measured sizing against predicted sizing, the rules the engine applies (and why each one changed), lessons from real runs, and a pseudonymous record of each engagement.
- **It is read by the engine**, not just by people: app rationalization (factory §6.2) resolves inventory names through the catalog, sizing (§6.5) applies the calibration factors, and the quality gate (§5) reads its thresholds from the rules.
- **It answers questions with citations:** "what do we know about SAP GUI in multi-session?", "how far off were our medium-tier estimates?" (§7.2).
- **It never holds a customer's data.** Customer data stays in the engagement folder in the customer's environment. Only generalized, reviewed knowledge crosses into the brain, and CI checks that it does (§5, §8).

The rule that holds it together, the same as the landing zone's: **models and scripts propose, a person approves, and Git is the only place knowledge becomes policy.**

## 2. Goals and non-goals

### Goals

1. Every engagement leaves the brain better: a closed engagement without a harvest is a defect.
2. Never pay twice for the same app test. An app classified once is resolved from the catalog in every later engagement.
3. Estimates converge on reality: the second engagement's sizing error, per tier and VM family, is smaller than the first's (factory phase 5's exit criterion).
4. Every number and rule the engine uses traces back to evidence: a document, a pilot or an engagement.
5. Knowledge survives the people: a new consultant can ask the brain and get the organization's answer with its sources.

### Non-goals

- **No customer data.** No customer names, user names, machine names, IPs, tenant or subscription IDs, or line-of-business app names. Those stay in `output/engagements/` in the customer's environment (factory §4.3).
- **No automatic policy change.** The engine never edits a rule or the catalog by itself. The harvest proposes; a person merges.
- **No hosted service.** The brain is files in Git. There is no database, vector store or server until the volume demands one (Q2).
- **Not the operations brain.** Incidents, playbooks and self-healing for a running AVD estate belong to the landing zone's second brain. The two exchange evidence (§9), not responsibilities.

## 3. Principles

| # | Principle | Source |
|---|---|---|
| P1 | Real runs are the source of truth. A pilot result beats a vendor document, and a document beats a model's guess. | Landing-zone decision 0006 |
| P2 | Knowledge is code. Every entry validates against a schema, and every rule change carries its reason and the evidence that caused it. | Landing-zone decision 0006 |
| P3 | The LLM never decides. It may normalize names and draft notes; an entry it wrote stays `unknown` for multi-session until a document, a pilot or a person says otherwise. | Factory §6.2 |
| P4 | Customer data stays with the customer. Only generalized knowledge crosses into the brain, and a guard checks every file. | Factory §4.3, landing-zone decision 0008 |
| P5 | Few observations are not a trend. A calibration factor applies only after a minimum number of observations, and it is clamped. | Factory §15, "false precision" |
| P6 | Warnings are not failures. Stale entries warn; schema violations and sensitive data fail. | Landing-zone decision 0009 |
| P7 | One language for the tools. The brain's tools are PowerShell 7 with no modules, like the rest of the repo; the data is JSON that the future Python engine reads natively. | Factory §12, Q7 |

## 4. What the brain remembers

| Memory | Holds | Home | Read by |
|---|---|---|---|
| **App catalog** | Public products: normalized name, match patterns for inventory names, category, multi-session verdict, default delivery, evidence | `knowledge/catalog/apps.json` | Stage 4 app rationalization; the app test plan; people |
| **Rules** | The engine's thresholds and decision tables: workload tiers, delivery, quality gate, calibration policy. Each rule has a version and a history with a reason per change | `knowledge/rules/*.json` | Stages 3–5 |
| **Calibration** | One observation per host pool per wave: predicted vs measured sessions per host, by tier and VM family | `knowledge/calibration/sizing.json` | Stage 4 sizing, through `Get-SizingCalibration` |
| **Engagements** | A pseudonymous record per engagement: estate shape (in buckets), sources, outcome, and what it contributed to the brain | `knowledge/engagements/eng-<yyyy>-<mm>-<4 chars>.json` | Cross-references, measures (§11), people |
| **Lessons and decisions** | What real runs taught and why the design is what it is | `docs/lessons/`, `docs/knowledge/decisions/` | People and Claude Code |

Derived values are never stored. Calibration factors are computed from the observations when they are read, so a factor can't drift from its evidence.

**Why JSON and not YAML.** PowerShell 7 validates JSON against a JSON Schema with the built-in `Test-Json`, so the guards need no module. Python reads it with the standard library. The factory spec's `catalog/apps.yaml` and `rules/*.yaml` become `knowledge/catalog/apps.json` and `knowledge/rules/*.json`.

## 5. Scopes: what may cross from an engagement into the brain

Knowledge lives at three scopes. It moves only upward, only by a reviewed PR, and only after it has been generalized.

| Scope | Where | Holds | Never holds |
|---|---|---|---|
| **Engagement** | `output/engagements/<customer>-<yyyymm>/` in the customer's environment (git-ignored) | Raw exports, the estate model, the manifest, LOB app names, the re-identification key | — |
| **Organization** | The organization's **private** fork of this repo, `knowledge/` with `"scope": "organization"` | Everything in the public scope, plus engagement records and calibration observations under pseudonymous engagement IDs, and a hashed denylist of customer names | Customer names, people, machines, network details, LOB app names |
| **Public** | This repository, `knowledge/` with `"scope": "public"` | Schemas, rules, public-product catalog entries backed by documents, the tools and guards | Engagement records, calibration observations, any evidence that points at an engagement |

Rules the guard enforces (`Test-Knowledge.ps1`, §8):

- **Pseudonymous engagement IDs.** `eng-2026-11-a7f3`, never `contoso-202611`. The mapping from ID to customer lives in the organization's own records (CRM, engagement tracker), not in the brain.
- **Buckets, not counts.** An engagement record says `500-2k` users, never 1,317.
- **No LOB apps.** A catalog entry with `scope: customer-lob` fails. A customer's own application is customer data even when its name looks harmless. It stays in the engagement's local overrides.
- **Public scope holds no engagement trail.** Engagement records, calibration observations, and catalog evidence of kind `engagement` or `pilot` fail in a brain whose scope is `public`. An organization upstreams a catalog entry by citing a public document, or not at all.
- **Sensitive text scan** over every file in `knowledge/`: email addresses and UPNs, IPv4 addresses outside the documentation ranges, non-placeholder GUIDs (tenant and subscription IDs), UNC paths, and default Windows machine names. In the organization scope, also every one-, two- and three-word phrase against `knowledge/denylist.sha256`, the SHA-256 hashes of the lowercase names of the organization's customers. The denylist holds hashes so that the file listing your customers doesn't itself become a customer list in plain text; it stays in the private fork, because short names can be guessed from their hashes.

## 6. How knowledge enters: the harvest

Harvest is factory stage 10 (Learn). It runs after each wave closes and once more when the engagement closes.

```
 engagement folder ──► harvest draft ──► redact + generalize ──► PR to the org brain ──► a person merges
 (analysis/, verify/,     (the harvest     (pseudonymous ID,       (CI: schemas, scope,     (and, for public
  waves/status.yaml)       skill or, later, buckets, no LOB,       sensitive scan,          products with a
                           `avdmf learn`)    public products only)  cross-references)        document, upstream)
```

What a harvest proposes:

| From | Becomes | Rule |
|---|---|---|
| The app test plan's results (pilot pass / fail / fixed) | Catalog entries or new evidence on existing ones | Public products only. A verdict needs pilot or document evidence |
| Stage 9's measured sessions per host, per host pool | Calibration observations | One per host pool per wave, measured at the rule's target utilization |
| A wrong decision (a gate that let bad data through, a persona that landed in the wrong pattern) | A rule change with a new version, a history entry and a reason, plus a test | The reason cites the engagement ID and the lesson |
| A real-run surprise in stage 0 or deployment | A lesson in `docs/lessons/` with its guard | As the repo already does (CLAUDE.md) |
| The engagement itself | Its record, with `harvest.done: true` | A `closed` engagement without a finished harvest fails CI |

**Who writes it.** Until the engine exists, Claude Code writes the draft with the `harvest` skill (`.claude/skills/harvest/SKILL.md`) from the engagement folder on the consultant's machine. The skill reads the customer's data locally and writes only generalized entries into `knowledge/`. Then it runs the guard before proposing the PR. Later, `avdmf learn` produces the same draft deterministically, and the skill only reviews it.

**The LLM's part (P3).** It may propose a normalized vendor/product/version and a category for the long tail of inventory names. It records `source: llm` with the model, prompt version and date. It can't set a multi-session verdict: that needs evidence of kind `doc`, `pilot` or `engagement`, and an entry written by the model needs `reviewedBy` before its verdict counts.

## 7. How knowledge is used

### 7.1 By the engine

| Stage | Reads | Behavior |
|---|---|---|
| 3 Quality gate | `rules/quality-gate.json` | Thresholds come from the rule, and the gate's report prints the rule's ID and version |
| 4 App rationalization | `catalog/apps.json` through `Resolve-BrainApp` (the engine ports it) | Inventory names resolve by match pattern, most specific pattern first. Unresolved apps go to the LLM normalizer and to the app test plan |
| 4 Delivery | `rules/delivery.json` | The delivery decision table (factory §6.2) |
| 4 Sizing | `rules/workload-tiers.json`, `calibration/sizing.json`, `rules/calibration.json` | Microsoft's users-per-vCPU guidance as the prior, then the calibration factor for the tier and VM family when it has enough observations. The design report states the factor, its count and whether it applied |
| 5 Design report | All of the above | Every decision that used the brain cites the entry (`knowledge/catalog/apps.json#microsoft/teams/2`, `knowledge/rules/quality-gate.json@v1`) |

**Pinning.** Each engagement's manifest records the brain commit it was designed with (`brainCommit`). A re-run on fresh data uses the same commit unless a person moves it, so the brain changing mid-engagement never changes a signed-off design silently.

### 7.2 By people

- **`scripts/Find-BrainKnowledge.ps1 -Query "sap gui multi-session"`** searches the catalog, rules, lessons and decisions and prints each hit with its path. `-App "<inventory name>"` resolves one inventory name against the catalog.
- **Claude Code** reads the checkout directly. At this volume the Git checkout is the retrieval index; a vector store waits for Q2.

## 8. Guards

`scripts/Test-Knowledge.ps1` runs in CI (`.github/workflows/validate.yml`) and before every harvest PR. It fails on:

- a file that doesn't validate against its schema (`knowledge/schemas/`);
- a duplicate catalog ID, rule ID or engagement ID, or a file whose name doesn't match its ID;
- a catalog entry with `scope: customer-lob`; a multi-session verdict without evidence; an `llm` entry with a verdict but no `reviewedBy`, or without its model metadata;
- a rule whose latest history entry isn't its current version;
- a reference to an engagement that has no record;
- a `closed` engagement whose harvest isn't done;
- anything in §5's scope and sensitive-text rules.

It warns, without failing, on catalog entries not verified in 365 days.

Pester tests (`tests/Knowledge.Tests.ps1`) cover every rule with fixtures in both scopes, including a sample of sensitive text that must be caught.

## 9. Relation to the other repos

The full picture, with every flow and contract, is in [architecture.md](architecture.md) and [contracts.md](contracts.md). In short:

| Repo | Gives the brain | Takes from the brain |
|---|---|---|
| `avd-landing-zone` (its second brain) | Day-2 evidence: AVD Insights baselines as `avd-sizing-evidence/v1` ([contracts](contracts.md) C4), imported as calibration observations by `scripts/Import-SizingEvidence.ps1` | The catalog's verdicts for the image pipeline; the calibration factors for its own sizing defaults |
| `avd-current-state` (through an estate vault) | Brownfield facts for engagement records (in buckets), recurring findings, runbook and lesson candidates (`scripts/Get-VaultHarvest.ps1`) | Shared runbooks, seeded into vaults at `-Init` |
| avd-readiness-stratusphere stage 0 | Lessons from real appliance and rollout runs | — |

Only the harvest moves knowledge between them, so the same scope and review rules apply whichever repo the evidence came from.

## 10. Phases

| Phase | Delivers | Done when |
|---|---|---|
| **1. Knowledge base (built)** | `knowledge/` layout, schemas, seed rules from the factory spec and Microsoft's sizing guidance, a seed catalog of documented public products, the guard, `Find-BrainKnowledge.ps1`, `Get-SizingCalibration`, the harvest skill, CI | CI green; the guard catches the sensitive-text sample |
| **2. First harvest** | One real (or lab) engagement harvested into an organization fork | A closed engagement record, its catalog evidence and at least one calibration observation merged by a person |
| **3. Engine reads the brain** | The factory engine (phase 1 of the factory) reads rules and the catalog, and pins `brainCommit` in the manifest | A fixture estate's design report cites brain entries |
| **4. Calibration in use** | Calibration factors applied in sizing once a tier and family reach the minimum observations | The second engagement's sizing error is smaller than the first's |
| **5. Landing-zone feed** | Day-2 right-sizing evidence from the landing zone's brain harvested as observations | One observation from a running estate merged |

## 11. Measures of success

| Measure | Target |
|---|---|
| Closed engagements with a finished harvest | 100% (CI enforces it) |
| Inventory apps (by usage) resolved from the catalog, not the LLM, from the third engagement on | ≥ 70% |
| Median absolute sizing error per tier and family, after calibration | Falls engagement over engagement |
| Sensitive-data findings that reached the default branch | 0 |
| Catalog entries with a verdict but no evidence | 0 (CI enforces it) |
| Rule changes without a reason and evidence | 0 (CI enforces it) |

## 12. Open questions

- **Q1. Where does the organization brain live?** Recommendation: a private fork per organization, synced from this repo's release tags, as the landing zone does. One brain per consultancy, not per customer.
- **Q2. When does retrieval need more than the checkout?** Recommendation: not before a few hundred catalog entries or a dozen engagements. Then an index built from the same files in CI, never a second source of truth.
- **Q3. Upstreaming catalog entries.** Should the public catalog accept pilot evidence summarized without the engagement ID ("verified in a pilot, 2026")? It would help the community and weakens traceability. Recommendation: documents only, until there's a way to cite a pilot without pointing at a customer.
- **Q4. Minimum observations and clamp.** The seed (`rules/calibration.json`: 3 observations, factor clamped to 0.5–1.5) is a guess to revisit after phase 4.
- **Q5. Denylist strength.** Hashes of short customer names can be brute-forced. Is a keyed hash (HMAC with a key outside the repo) worth the extra secret in CI?
