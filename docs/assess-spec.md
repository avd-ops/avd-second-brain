# Spec: avd-assess, a research index for AVD assessment

- **Status:** Draft, for the owner's review. Nothing here is built.
- **Owner's direction (2026-10-20):** `avd-assess` gets its own public MIT repo. It holds methodology only: collection, assessment, and target, benchmark and scoring. It is a **research project**. It doesn't reinvent anything that already exists. It links out to existing sources with immutable references and adds value by validating them against our own experience and observations. It writes new method only where nothing exists.
- **Date:** 2026-10-20
- **Builds on:** [decision 0005](knowledge/decisions/0005-one-schema-registry-and-fact-register.md) (one schema registry and fact register), [decision 0011](knowledge/decisions/0011-family-format-upstream-sources.md) (link upstream, don't restate), [decision 0018](https://github.com/nickprignano/avd-second-brain/pull/41) (proposed: the public family ends at its contracts), and contracts C11, C14, C15 and C17 in [contracts.md](contracts.md).

> Personal project. Research and learning only, not for production, provided as is. Not affiliated with, endorsed by or supported by the author's employer, Liquidware or Microsoft. Azure Virtual Desktop is a trademark of its owner.

## 1. Summary

The world has already written most of what it takes to assess an AVD estate. Microsoft's review checklist, its resiliency library and WARA, the Well-Architected checklists, the session host sizing guidelines, the connection quality guidance and the Windows optimization tool are all published. What's missing is a place that gathers those sources, says which ones hold up in practice, and fills the few real gaps. avd-assess is that place. It has three layers, and only the last two are ours:

1. **References (theirs).** An index of every source the method relies on. Each entry has a pinned, immutable link, so a reader can see exactly what the source said on the day we read it, plus the claims we take from it (an ID, a number, a recommendation) in a short line of our own words. The source's text is never copied.
2. **Observations (ours).** What our own runs showed about each claim: whether it agrees, disagrees, extends the claim or is not yet tested, with links to the evidence. Evidence is a landing zone lesson, a run record (C17), a validator result or a KB page. This is the research and the value add.
3. **Gaps (ours, marked as such).** Method written only where no source exists: joining recommendations to the family's redacted facts, the decision-readiness rules for the target state, and a scoring model, because no open scoring standard exists (§3). Each gap entry says what we searched for and didn't find, so it can be replaced the day a source appears.

Those layers serve one purpose: avd-assess is **the family's starting point and reference for four methodologies**, each a page a person reads first (§3a):

- **Collection:** what to collect about an estate, from where, and with what privacy class.
- **Assessment:** how to judge what was collected against the recommendations.
- **Targets and benchmarks:** what good looks like, as numbers with their sources.
- **Scoring:** how outcomes roll up, and which decisions the evidence can support.

Each page states the method in order, step by step. Every step links the reference it comes from, the observations that test it, or the gap entry where we wrote it ourselves.

avd-assess has no tools. avd-current-state implements the collection and assessment it describes. avd-second-brain ingests it, and the brain's agents cite it. Both read a pinned copy (§8).

## 2. What exists today and what is missing

| Piece | State | Where |
|---|---|---|
| Observed facts (C11) and the fact register (C15) | Built | avd-current-state `avd_current_state_facts.ps1`; this repo's `contracts/` |
| Coverage line ("N of 10 decisions this snapshot can support") | Built | avd-current-state `Get-ManifestCoverage` |
| Readiness rules on a live subscription | Built (about 260 checks) | avd-current-state `avd_deployment_validator.ps1` |
| Well-Architected warnings on a deployed landing zone | Built | avd-landing-zone `-WellArchitected` (`waf-*` IDs) |
| Windows optimization profile | Built | avd-landing-zone `scripts/image/wdot/` (WDOT, pinned and reviewed) |
| Real-run evidence | Built, scattered | avd-landing-zone `build/lessons/`, run records (C17), this repo's KB topic pages |
| An index of the sources, pinned | **Missing** | §4 |
| Observations that tie our evidence to those sources | **Missing**; the evidence exists, but nothing links it to the claims it tests | §5 |
| Intake (what telemetry can't know) | **Missing:** five `intake.*` facts with no contract | §6.2 |
| The fact-to-recommendation mapping, decision readiness and scoring | **Missing**; no source covers them | §6 |

## 3. Sources found so far

Searched 2026-10-20. Sources were Microsoft Learn (through the Learn MCP search), the web, the PowerShell Gallery, the upstream repos' own pages, the family's prior-art report and adoption spec, and the family KB (`scripts/kb/prior_art.py`). GitHub's search API and the sibling KBs returned HTTP 403 from the build container. GitHub was therefore checked repo by repo, not searched broadly. A broad search is the first step of phase 1 (§10).

| Source | Area | What we take from it | License |
|---|---|---|---|
| [Azure/review-checklists](https://github.com/Azure/review-checklists) `checklists/avd_checklist.en.json` | Assessment | Items by short ID (`A01.01`): category, WAF pillar, severity, Learn link. The AVD items carry no Resource Graph query, so mapping evidence to them is a gap we fill | MIT |
| [APRL v2](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2) `azure-resources/DesktopVirtualization/` and [WARA](https://github.com/Azure/Well-Architected-Reliability-Assessment) | Collection, assessment | Reliability recommendations with Resource Graph queries. `Start-WARACollector -AVD` writes JSON. WARA covers Reliability only. It is the rule engine for live reliability checks (owner, 2026-10-20) | MIT |
| Well-Architected [pillar design review checklists](https://learn.microsoft.com/azure/well-architected/reliability/checklist) and the [AVD workload assessment](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations#specialized-well-architected-reviews) | Assessment, intake | Stable codes (RE:01 and so on) and the design questions. Links under `well-architected/azure-virtual-desktop/` now redirect into the AVD product docs | Learn content |
| [Session host sizing guidelines](https://learn.microsoft.com/windows-server/remote/remote-desktop-services/session-host-virtual-machine-sizing-guidelines) | Benchmarks | Multi-session maximum users per vCPU: light 6, medium 4, heavy 2, power 1. Multi-session hosts of 6 to 24 vCPUs, never fewer than 4. A 30 GB profile storage minimum. The page itself calls these "initial performance estimates" | Learn content |
| [AVD prerequisites](https://learn.microsoft.com/azure/virtual-desktop/prerequisites#network), [Insights use cases](https://learn.microsoft.com/azure/virtual-desktop/insights-use-cases#connectivity), [connection quality](https://learn.microsoft.com/troubleshoot/azure/virtual-desktop/troubleshoot-connection-quality), [Insights glossary](https://learn.microsoft.com/azure/virtual-desktop/insights-glossary#time-to-connect) | Benchmarks, measured collection | Round-trip time under 150 ms. Insights calls under 100 ms ideal and over 200 ms low quality. Time to connect is split into stages | Learn content |
| [WDOT](https://github.com/The-Virtual-Desktop-Team/Windows-Desktop-Optimization-Tool) (it supersedes VDOT, which has no license) and the [VDI optimization guide](https://learn.microsoft.com/windows-server/remote/remote-desktop-services/remote-desktop-services-vdi-optimize-configuration) | Assessment (image) | The optimization categories. The landing zone's reviewed profile records which items we apply and why | MIT (WDOT) |
| [microsoft/ARI](https://github.com/microsoft/ARI) | Collection | A full Azure inventory as Excel. We point operators at it and don't wrap it | MIT in the repo; check before reuse |
| Commercial user-experience scores (vendor tools) | Scoring | Proprietary scores built from logon, responsiveness and reliability, with thresholds tuned per customer. Prior art only | Proprietary |

Not found: an open scoring model for an AVD estate, a published logon-time target, or a mapping from the review checklist to evidence. Those are the gaps (§6).

## 3a. The four methodology pages (`methods/`)

`methods/collection.md`, `methods/assessment.md`, `methods/targets-benchmarks.md` and `methods/scoring.md` are the front door. Anyone starting an assessment, and any family repo implementing one, starts here. Each page:

1. states the method as numbered steps, in the order someone would do them;
2. gives each step its basis: a reference claim (`ref:...#...`), an observation, or a gap entry;
3. ends with what is still unknown or untested, linked to the open observations.

A page never says more than its references, observations and gaps support. A test checks that every step cites at least one of them. Changing a step means changing what it cites first, so the pages stay a view over the evidence rather than a second source. Version 1 of each page is written in phase 1 (§10) from the sources in §3, before any tooling.

## 4. References: the index (`references/`)

One YAML file per source, with an ID that observations and docs can cite (and that a vault can use as a wikilink, `[[ref:review-checklists-avd]]`):

```yaml
id: ref:session-host-sizing
title: Session host virtual machine sizing guidelines
url: https://learn.microsoft.com/windows-server/remote/remote-desktop-services/session-host-virtual-machine-sizing-guidelines
pin:
  repo: https://github.com/MicrosoftDocs/windowsserverdocs
  path: WindowsServerDocs/remote/remote-desktop-services/session-host-virtual-machine-sizing-guidelines.md
  commit: <sha>
read: 2026-10-20
license: Learn content (link only)
claims:
  - id: medium-users-per-vcpu
    says: Multi-session medium workloads, at most 4 users per vCPU
    kind: prior        # published | prior (the source calls it an estimate) | guidance
    anchor: "#workloads"
```

- **Immutable links.** A GitHub source is pinned to a commit (`/blob/<sha>/...`). A Learn page is pinned to its source file at a commit in Microsoft's public docs repo, beside the readable URL. A source with neither gets an archived copy's URL and the date it was read. The readable URL can move; the pin can't.
- **Claims, not content.** A claim is an ID and one line in our words, with the source's anchor. The source's text is never stored.
- **Freshness.** A scheduled check compares each pin to the source's current head. When the source changes, it opens an issue naming the claims to re-read. Nothing changes silently: a claim moves to a newer pin only by a reviewed PR.

## 5. Observations: our evidence (`observations/`)

One entry per claim we have evidence about:

```yaml
claim: ref:session-host-sizing#medium-users-per-vcpu
verdict: not-yet-tested   # agrees | disagrees | extends | not-yet-tested
evidence: []              # links: a lesson, a run record (C17), a validator result, a KB page
observed: null            # one line, our words, no estate data
date: 2026-10-20
```

- Evidence is a public link to a family artifact: a landing zone lesson, a run record, a KB page or a validator check. It holds no estate or customer data, the same rule as the KB. A measured result from a real estate reaches an observation only as a generalized, harvested fact (C2/C3), never as raw data.
- `disagrees` is the most valuable verdict. Each one also gets an upstream entry in this repo's KB (decision 0011), so a person can offer it back to the source.
- The first entries come from what already happened. For example, landing zone lesson 0028 (SMB channel encryption and FSLogix under Entra Kerberos) extends Microsoft's FSLogix storage guidance. The landing zone's WDOT review records which WDOT items we kept off and why.

## 6. Gaps: method we write (`gaps/`)

Each gap file opens with what was searched and not found, and is retired the day a source covers it.

### 6.1 Collection: facts to sources

For each fact ID in the register (C15), the Resource Graph table and property (`DesktopVirtualizationResources`, `Resources`) or the REST call, the WARA output field, the Insights table, or the intake question it comes from, and its privacy class. avd-current-state's collector is moving to these Resource Graph reads (adoption spec, section 6), with C11 unchanged. Each row cites the reference that documents the property, so the gap is only the join.

### 6.2 Intake (`avd-intake/v1`, contract C19)

The operator answers these once per estate, in an `intake.json` file beside their landing zone parameters. The schema lives in this repo and gives the register's five `intake.*` facts their paths: `/residency`, `/preferredRegions`, `/existingHub` (`none`, `azure-hub`, `vwan`, `other`), `/identity` (`entra-only`, `hybrid-ad`, `entra-ds`, `undecided`) and `/workingHours`. Each question links the reference that explains why it matters. The schema has no field for a name, a domain, an address, an ID or free text.

### 6.3 Checks: claims to facts

A check is a declarative test of one or more claims against facts. It has a JSON pointer, a filter and an expectation, with no code:

```json
{ "id": "asm-hostpool-start-vm-on-connect", "claims": ["ref:review-checklists-avd#<short ID>"],
  "facts": ["c11.hostPool.startVmOnConnect", "c11.hostPool.type"],
  "rule": { "each": "/subscriptions/*/hostPools/*", "where": { "type": "Pooled" }, "expect": { "startVmOnConnect": true } },
  "informs": ["hostPool.power"], "severity": "medium" }
```

There are four outcomes: `pass`, `warn` (a trade-off to review), `gap` and `unknown`. Unknown is never guessed, and a model never decides an outcome. Every cited fact must be `built` in the register, every claim must exist in `references/`, and every `informs` value must be a register decision. Version 1 has about 20 checks. Image checks cite the WDOT reference and stay `unknown` until a host fact exists.

### 6.4 Decision readiness and target-state rules

For each of the 10 C14 decisions, the claims and facts that decide it, and its readiness: `decidable`, `decidable with intake` or `needs measurement`. This generalizes today's coverage line. Sizing decisions cite the sizing guidelines' `prior` claims and stay `needs measurement`. Measuring real users is outside the family (decision 0018), so the method links avd-ops.dev there.

### 6.5 Scoring

No open standard exists, so the method publishes a simple one, labeled as a research hypothesis:

- the pillar score is the passing severity weight over the assessed weight (`warn` counts half; weights 3, 2 and 1, versioned);
- coverage, the share of a pillar's checks that aren't `unknown`, is always shown beside the score;
- there is no single overall number in version 1.

Observations test the model like any other claim: if a high score keeps coming with real problems, that becomes a `disagrees` entry on our own method.

## 7. Contracts

- **C19 `avd-intake/v1`**: §6.2.
- **C20 `avd-assess-method/v1`**: one schema each for references, observations and the gap files (checks, readiness, scoring), all in this repo per decision 0005.
- **C21 `avd-assessment/v1`**: the report avd-current-state writes. It records the method's version and commit, the snapshot time and estate pseudonym, one row per check (outcome, pseudonyms, fact IDs, claims), and the pillar scores with coverage and decision readiness. It holds no names, IDs or free text and passes the same guard as C11.

## 8. Who implements it, and how copies stay in sync

```
              avd-second-brain   schemas C11, C14, C15, C17, C19, C20, C21; fact register
                ▲            ▲
   pins schemas │            │ pins the method; Test-AssessMethod; agents cite references and observations
                │            │
            avd-assess ──────┘   references, observations, gaps (source of truth)
                │
   vendored,    ▼ byte-identical at a pinned commit
            avd-current-state    implements collection + assessment; writes C21
                ·
            avd-landing-zone     unchanged; its lessons and run records are evidence avd-assess links to
```

- **avd-current-state** vendors the gap files it runs (collection map, checks, readiness, scoring) into `assess/`, byte-identical at the commit in `assess/PINS.json`, with a SHA-256 per file that `tests/Facts.Tests.ps1` checks, as it already does for the brain's contracts. Nothing is fetched at run time. If avd-assess disappeared, avd-current-state would keep its last pinned copy, so the landing zone and avd-current-state pair stays self-contained. Its evaluator, `-Assess` and the WARA import live there. The WARA import is the family's one WARA reader, and avd-swarm's proposed chat review reuses it (a paired swarm change when that is built).
- **avd-second-brain** holds the schemas and `Test-AssessMethod`, with tests in `tests/Connectors.Tests.ps1`. It adds avd-assess to `sources/sources.json`, so agents cite `avd-assess@<commit>:references/...` and observations. The assessment topic page links the index instead of restating it. `knowledge/rules/workload-tiers.json` cites the sizing claims as its prior. Reports are filed in the estate vault beside their C11 snapshot.
- **avd-swarm:** nothing new in version 1. An outcome reaches a plan only through the C11 fact IDs it cites.
- **avd-landing-zone:** unchanged. avd-assess links to its lessons, run records and WDOT profile at pinned commits.

## 9. Repo layout and checks

```
avd-assess/
  README.md        notice; scope: a research index, methodology only; how to cite
  LICENSE          MIT
  methods/         the four methodology pages: collection, assessment, targets-benchmarks, scoring
  references/      one YAML per source, pinned, claims only
  observations/    our evidence per claim
  gaps/            collection map, intake, checks, readiness, scoring, each with "searched, not found"
  docs/            the method in prose, every claim linked to its reference
  tests/           schemas (from the brain at a pin); every claim, fact and pin resolves; leak guard
```

CI checks only the method. There are no scripts that touch Azure. A scheduled job checks pin freshness and opens issues; it never edits.

## 10. Build order

All offline. No cloud spend until phase 6, which waits on the owner's go and a cost estimate.

| Phase | Repo | What |
|---|---|---|
| 0 | this repo | This spec (draft PR) |
| 1 | avd-assess | A broad GitHub and Learn search outside the build container. Then the seed: README, LICENSE, CI, references for the sources in §3 with pins, the four methodology pages (version 1), and the first observations from existing lessons |
| 2 | this repo | C19, C20 and C21 schemas, examples, `Test-AssessMethod` |
| 3 | avd-assess | Gap files, version 1: collection map, intake, about 20 checks, readiness, scoring |
| 4 | avd-current-state | Vendor the gap files with `assess/PINS.json`; evaluator, `-Assess`, C21; WARA import; collector reads through Resource Graph |
| 5 | this repo | `sources.json` entry, report filing, topic page links, `workload-tiers.json` cites its prior |
| 6 | (owner's go) | One sandbox run, which becomes the first observations from a run made for avd-assess; teardown evidence |

## 11. Open questions

1. **Who writes a baseline manifest** from the readiness rules (avd-current-state, which moves it past read-only inventory, or a small writer here). It also needs two C14 changes: `producer.name` accepting it, and sizing fields that may be absent at `low-confidence`.
2. **Image evidence.** Whether WDOT state becomes a fact (a tag on the gallery image version, or a host-side read by the validator).
3. **One overall score.** Left out of version 1; the owner's call.
4. **The private feature register row** for the baseline writer still says undecided. This spec reads "free" as covering it.

Name check (2026-10-20): no `avd-assess` package on the PowerShell Gallery and no repository found by web search.
