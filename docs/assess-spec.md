# Spec: avd-assess, the free baseline assessment

- **Status:** Draft, for the owner's review. Nothing here is built. Where avd-assess lives (its own public repo, a folder in avd-current-state, or rules in this repo) is the owner's call; this spec is written for its own public MIT repo, the recommended option, and §9 says what changes for the others.
- **Date:** 2026-10-20
- **Builds on:** [decision 0005](knowledge/decisions/0005-one-schema-registry-and-fact-register.md) (one schema registry and fact register), [decision 0011](knowledge/decisions/0011-family-format-upstream-sources.md) (link upstream, don't restate), [decision 0018](https://github.com/nickprignano/avd-second-brain/pull/41) (proposed: the public family ends at its contracts), and contracts C11, C14 and C15 in [contracts.md](contracts.md).

> Personal project. Research and learning only, not for production, provided as is. Not affiliated with, endorsed by or supported by the author's employer, Liquidware or Microsoft. Azure Virtual Desktop is a trademark of its owner.

## 1. Summary

avd-assess answers *"how does this AVD estate measure up, and what can we already decide about its target state?"* from what Azure's control plane and the operator can tell us, for free, offline, in Cloud Shell. It is three things:

1. **A method, as data.** A catalog of checks, each tied to the C11 facts or intake answers that evidence it, to the C14 decision it informs, and to the Microsoft source it comes from (the AVD review checklist, the Azure Proactive Resiliency Library, the Well-Architected AVD workload guidance). The method is ours only in how it joins those sources to our facts; the recommendations stay upstream.
2. **A small evaluator.** A pure PowerShell module that runs the method over a C11 snapshot, an intake file and, optionally, Microsoft's WARA findings, and writes an assessment report. It never calls Azure itself; the observed environment reaches it only as C11 facts and redacted WARA findings (§5a).
3. **A baseline manifest writer.** From the same inputs, a C14 target-state manifest with the decisions Azure facts and intake can support, marked low confidence, and every decision that needs measurement left open and named.

Two consumers carry it: **avd-current-state** runs a pinned copy of the method to validate the environment it observes, and **avd-second-brain** ingests the method and the reports its agents reason over. Neither depends on avd-assess at run time (§6).

## 2. What exists today and what is missing

| Piece | State | Where |
|---|---|---|
| Observed facts (C11) | Built, offline | avd-current-state `avd_current_state_facts.ps1`, brain schema `current-state-facts.schema.json` |
| Decisions a manifest makes (10) and the facts that evidence them (C15) | Built | `contracts/fact-register.json` |
| Coverage line ("N of 10 decisions this snapshot can support") | Built | avd-current-state `Get-ManifestCoverage` |
| Pass/fail rules on a live subscription | Built (about 260 checks in 20 categories) | avd-current-state `avd_deployment_validator.ps1` |
| Well-Architected warnings on a deployed landing zone | Built | avd-landing-zone `-WellArchitected` (Advisor, Policy, PSRule for Azure; `waf-*` ids, decision 0009) |
| Seed rules (workload tiers, quality gate, delivery) | Built, no thresholds | `knowledge/rules/` |
| Intake (what telemetry can't know) | **Missing:** five `intake.*` facts in the register with no contract and no path | §5 |
| A method that says what each fact means for the estate | **Missing** | §4 |
| An assessment report | **Missing** | §7 |
| A free writer of a C14 manifest | **Missing:** C14's `producer.name` only allows the measured design's producer | §7.2 |

So nothing named avd-assess exists, but most of its inputs do. It adds the method, the intake contract, the evaluator, the report and the baseline manifest, and reuses everything above.

## 3. Prior art: what we build on

Searched 2026-10-20: Microsoft Learn (the Learn MCP search), the web, the PowerShell Gallery, the upstream repos' own pages, the family's prior-art report and adoption spec, and the family KB (`scripts/kb/prior_art.py`). GitHub's search API and the sibling KBs returned HTTP 403 from the build container, so GitHub was checked repo by repo, not searched broadly. Microsoft sources are the source of truth for recommendations; avd-assess cites them by their own IDs and links them.

| Source | What it gives us | License | How avd-assess uses it |
|---|---|---|---|
| [Azure/review-checklists](https://github.com/Azure/review-checklists), `checklists/avd_checklist.en.json` | The AVD review checklist: items with a short ID (`A01.01`), category, WAF pillar, severity and Learn link. The AVD items carry no Resource Graph query, so the evidence for each is ours to map | MIT | A check that comes from it cites the item's short ID and link (not its GUID, which the leak guard reads as tenant data). Pinned by commit |
| [Azure Proactive Resiliency Library v2](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2) (`azure-resources/DesktopVirtualization/`: host pools, scaling plans, workspaces) and the [WARA module](https://github.com/Azure/Well-Architected-Reliability-Assessment) that runs it | Reliability recommendations (Reliability only) with Resource Graph queries. `Start-WARACollector -AVD` writes JSON; the analyzer writes Excel and the reporter PowerPoint, which needs Windows. Needs PowerShell 7.4, Az.Accounts and Az.ResourceGraph | MIT | **WARA is the rule engine for live reliability checks (owner, 2026-10-20); we don't write our own.** avd-assess reads only the collector's JSON (§5a). Checks cite APRL recommendation IDs |
| The [Azure Virtual Desktop workload assessment](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations#specialized-well-architected-reviews) (Microsoft Assessments) and the pillar design review checklists (RE:01 and so on) | The design questions, by pillar, with stable codes | Microsoft Learn content | Intake questions and check wording link to them and cite the pillar code; we don't copy the questions. Links under `well-architected/azure-virtual-desktop/` now redirect into the AVD product docs, so link those directly |
| [Windows Desktop Optimization Tool](https://github.com/The-Virtual-Desktop-Team/Windows-Desktop-Optimization-Tool) (WDOT; it supersedes VDOT, which has no license) and Learn's [Optimizing Windows configuration for VDI desktops](https://learn.microsoft.com/windows-server/remote/remote-desktop-services/remote-desktop-services-vdi-optimize-configuration) | Windows desktop optimization: services, scheduled tasks, autologgers, default user settings, local policy | MIT (WDOT) | The landing zone's image build already runs WDOT at a pinned commit with a reviewed profile (`scripts/image/wdot/`). Image checks cite that profile as the source of truth. A session host's in-guest state isn't in C11, so those checks are `unknown` until a host fact exists (§11) |
| PSRule for Azure | Rules for deployed resources, already run by the landing zone's `-WellArchitected` | MIT | Not re-run here; the landing zone keeps that check |
| [Native session host health checks](https://learn.microsoft.com/azure/virtual-desktop/session-host-status-health-checks), AVD Insights | Health after the fact | Microsoft product | Out of scope: health is the validator's and the swarm's, not an assessment |
| [microsoft/ARI](https://github.com/microsoft/ARI) (Azure Resource Inventory), the community Az.Avd module, documenter-azure-azurevirtualdesktop | Whole-subscription inventory (ARI writes an Excel workbook) and documentation | Check each LICENSE before reuse | Prior art only. The docs point an operator who wants a full inventory at ARI; avd-current-state's collector stays AVD-only and avd-assess doesn't inventory |

What none of these do, and avd-assess does: join recommendations to a **redacted, contract-shaped** fact snapshot (no names, no IDs), say which **target-state decisions** an estate's evidence can support and which need measurement, and write a manifest the landing zone can deploy.

Rules for upstream content: we store an upstream item's ID, link, pinned commit and our own one-line title, never its text. A check whose upstream item disappears at a newer pin fails the method's test until a person updates or retires it.

## 4. The method (`avd-assess-method/v1`, contract C20)

One JSON file, `method/method.json`, versioned like a rule (`version`, and a `history` entry for every change, as `knowledge/rules/` already requires). Its schema lives in this repo (`contracts/schemas/assess-method.schema.json`), per decision 0005.

```json
{
  "schema": "avd-assess-method/v1",
  "version": 1,
  "registerVersion": 1,
  "checks": [
    {
      "id": "asm-hostpool-start-vm-on-connect",
      "area": "hostPool",
      "pillar": "Cost Optimization",
      "title": "Pooled host pools start hosts on connect",
      "facts": ["c11.hostPool.startVmOnConnect", "c11.hostPool.type"],
      "intake": [],
      "rule": { "each": "/subscriptions/*/hostPools/*", "where": { "type": "Pooled" }, "expect": { "startVmOnConnect": true } },
      "informs": ["hostPool.power"],
      "upstream": [{ "source": "review-checklists/avd", "ref": "<checklist short ID, such as A01.01>", "url": "https://learn.microsoft.com/azure/virtual-desktop/start-virtual-machine-connect" }],
      "severity": "medium"
    }
  ],
  "history": [{ "version": 1, "date": "2026-10-20", "reason": "First method" }]
}
```

- **Checks are declarative.** A rule is a JSON pointer over the C11 snapshot (or the intake file), an optional filter, and an expectation (equals, in, at least, at most, present). No code in the method, so a person reviews a method change by reading JSON, and the brain can validate it.
- **Four outcomes:** `pass`, `warn` (a trade-off to review, as the landing zone's WAF findings are), `gap` (the estate falls short of the source's recommendation) and `unknown` (the fact isn't in the snapshot or the intake answer is missing). Unknown is never guessed. A model never decides an outcome.
- **No single score.** The report counts outcomes by pillar and by decision. One number would hide which decisions are unsupported.
- **Every fact ID** a check cites must be `built` in the fact register at `registerVersion`, and every `informs` value must be a register decision. The method's own test enforces it, and so does the brain's (§6.2).
- **Version 1 scope:** about 20 checks, only over C11 facts already built (host pools, network, storage, policy, regions) and the five intake facts. Each maps to an upstream item; a check with no upstream source needs a written reason in its `history` entry.

## 5. Intake (`avd-intake/v1`, contract C19)

What telemetry can't know, answered by the operator once per estate, in a file next to their landing zone parameters (`intake.json`). Its schema lives in this repo and gives the register's five `intake.*` facts their contract and paths:

| Fact | Field | Values |
|---|---|---|
| `intake.residency` | `/residency` | Azure region names, or a geography from Microsoft's public list |
| `intake.preferredRegions` | `/preferredRegions` | Azure region names, in order |
| `intake.existingHub` | `/existingHub` | `none`, `azure-hub`, `vwan`, `other` |
| `intake.identityConstraints` | `/identity` | `entra-only`, `hybrid-ad`, `entra-ds`, `undecided` |
| `intake.workingHours` | `/workingHours` | start and end hour and a time zone name |

The schema has no field for a name, a domain, an address, an ID or free text, and every string has an enum or a pattern, like C11. Adding a fact later (a user-count band, say) is a register change with its own reason. The landing zone may ship an example `intake.json` beside its parameter files; it never reads one.

## 5a. WARA findings (optional input)

WARA's collector needs read access to the subscription and the module from the PowerShell Gallery, so it runs in Cloud Shell, not inside avd-assess. `Import-AvdWaraResult` (avd-assess) reads the collector's JSON and writes `wara-findings.json`: for each AVD recommendation (APRL ID, pillar, WARA's impact), the pseudonyms of the resources it found (same `resources` subkey as C11) and a count. Resource IDs, names and WARA's free-text fields are dropped, and the result passes the same guard as C11. This is the family's one WARA reader: avd-swarm's proposed chat review reuses this module (a paired swarm change when it is built) instead of writing its own. Checks can then cite `wara:<APRL ID>` beside C11 facts, with the outcome `gap` when WARA found the resource and `unknown` when no WARA file was given. Without WARA, the assessment still runs on C11 and intake. The WARA output shape is pinned to a module version and tested with a synthetic file; a newer WARA version that changes it fails the test, never silently.

## 6. Which way dependencies point, and how the copies stay in sync

```
              avd-second-brain   schemas C11, C14, C15, C19, C20, C21; fact register
                ▲            ▲
   pins schemas │            │ pins method.json (C20) for its agents and checks
                │            │
            avd-assess ──────┘   method, evaluator, baseline writer (source of truth)
                │
   vendored,    ▼ byte-identical at a pinned commit
            avd-current-state    runs the pinned method over the snapshot it just wrote
                ·
            avd-landing-zone     unchanged; may read a C14 manifest, as today
```

### 6.1 avd-current-state carries a pinned copy

Owner's rule: avd-landing-zone and avd-current-state are a self-contained pair that works with no brain, no swarm and no avd-assess. So avd-current-state never fetches avd-assess. It vendors two files the way it already vendors the brain's contracts:

- `assess/method.json` and `assess/AvdAssess.psm1`, byte-identical to avd-assess at the commit in `assess/PINS.json` (`assessCommit` and a SHA-256 per file). `tests/Facts.Tests.ps1` checks the hashes, as it does for `contracts/PINS.json` today. One PR updates the files, the commit and the hashes together.
- The facts script gets `-Assess` (and keeps its coverage line). After writing the snapshot it runs the pinned method and writes `assessment.json` and `assessment.md` beside it. Same redaction guard, same refusal to write inside a repo.
- How avd-current-state collects doesn't matter to the method. Its collector is moving to Azure Resource Graph reads (`DesktopVirtualizationResources` and `Resources`, cmdlets only where Resource Graph lacks a property), with the package format and C11 unchanged; it doesn't wrap ARI. When a check needs evidence C11 doesn't have, the collector gains a C11 fact (a register change); avd-assess never queries Azure itself.
- `Get-ManifestCoverage` moves into `AvdAssess.psm1` and comes back as part of the vendored copy, so coverage is defined once.
- `AvdAssess.psm1` runs in Windows PowerShell 5.1 and PowerShell 7, with no modules, because avd-current-state does.

If avd-assess disappeared tomorrow, avd-current-state would keep running its last pinned copy. That is what makes it a copy, not a dependency.

### 6.2 avd-second-brain ingests the method

- **As a contract:** C20 and C21 schemas live here. `Test-AssessMethod` (pure, in `scripts/AvdBrain.psm1`) checks a method file against the register: every fact `built`, every decision known, every upstream entry with a source, a ref and a URL. Tests in `tests/Connectors.Tests.ps1`, per the pairing rule.
- **As knowledge:** `sources/sources.json` adds avd-assess as a public search source, so `Find-BrainKnowledge` can cite `avd-assess@<commit>:method/method.json#asm-...`. The brain links each check's upstream source rather than restating it (decision 0011). The [assessment topic page](knowledge/assessment/README.md) links the method.
- **As estate evidence:** an assessment report is filed in the estate vault next to its C11 snapshot, by the same importer, and the brain's agents cite its outcomes with the snapshot time (`assess:<estate>@<generatedUtc>#asm-...`). An outcome is evidence that points at C11 facts; it adds no new estate data.

### 6.3 avd-swarm: nothing new in v1

avd-swarm gets estate facts only from the brain, as cited C11 or C12 evidence. An assessment outcome reaches a plan only through the C11 fact IDs it cites, so v1 changes no swarm input and needs no swarm PR. If a later version makes assessment outcomes a C9 evidence type, that is a paired change (decision 0003).

### 6.4 avd-landing-zone: unchanged

Its `-WellArchitected` review stays its own post-deployment check. Its C14 reader already refuses what `contracts/target-state-capabilities.json` doesn't list; a baseline manifest (§7.2) passes through that same reader, and a schema change reaches it only through its normal PINS bump.

## 7. Outputs

### 7.1 The assessment report (`avd-assessment/v1`, contract C21)

`assessment.json`: the method version and commit, the snapshot's `generatedUtc` and estate pseudonym, one row per check (ID, outcome, the pseudonyms it applies to, the fact IDs used), counts by pillar and outcome, and the coverage by decision. `assessment.md` renders the same for a person, with each check's upstream link. Neither holds a name, an ID or free text; both pass the same guard as C11.

### 7.2 The baseline manifest

A C14 manifest with the decisions Azure facts and intake can support (identity, region, network, host pool type, application group, power settings) and `evidence.quality: "low-confidence"`. The sizing decisions (VM size, sessions per host, host count, profile quota) need measurement, so they are absent and listed in the report as needing it. C14 needs two changes before this works, both in this repo with their tests and a landing zone PINS bump:

- `producer.name` accepts `avd-assess` as well as the measured design's producer;
- a host pool's sizing fields may be absent when `evidence.quality` is `low-confidence`, and the landing zone's reader then uses its own defaults and says so.

Writing a manifest is a design step, not a judgment the evaluator makes alone: every decision cites its facts, and the operator approves it with the existing `avd-target-approval/v1` file before anything deploys it.

## 8. Boundary with work outside the family

Per decision 0018, measured assessment (real users over a window) and the design that sizes host pools from it are outside the family. avd-assess stops where its evidence stops: it writes "needs measurement" for the sizing decisions and links avd-ops.dev, and says nothing about what that other work does. It never reads telemetry, a Stratusphere export or a measured-usage file.

## 9. Where it lives

| Option | What changes in this spec |
|---|---|
| **Its own public repo, `avd-assess` (recommended)** | As written. The owner creates the empty repo; the first PR seeds it with this spec, a LICENSE (MIT), the notice and CI (PSScriptAnalyzer, Pester, the method test, the leak guard) |
| A folder in avd-current-state | `assess/` is the source, not a copy, and §6.1's pin goes away; the brain pins avd-current-state instead. avd-current-state grows from inventory into judgment, and the baseline writer lives in a read-only tool |
| Rules in this repo | `knowledge/rules/assess-method.json` beside the workload tiers; avd-current-state vendors it from here (it already vendors from here). No separate avd-assess; the evaluator and the writer would need another home |

Name check (2026-10-20): no `avd-assess` package on the PowerShell Gallery and no repository found by search. The name is a working name, like the other repo names.

## 10. Build order

All offline; no cloud spend until phase 7, which waits on the owner's go and a cost estimate.

| Phase | Repo | What |
|---|---|---|
| 0 | this repo | This spec (draft PR) |
| 1 | this repo | C19, C20, C21 schemas, synthetic examples, `Test-AssessMethod`, `Test-Intake`, contracts.md rows, register paths for the `intake.*` facts |
| 2 | avd-assess | Seed: LICENSE, notice, CI, `method.json` v1 (about 20 checks), `AvdAssess.psm1`, `Invoke-AvdAssess.ps1`, tests over a synthetic snapshot and intake |
| 2a | avd-assess | `Import-AvdWaraResult` and checks that cite APRL IDs, tested on a synthetic WARA file (read WARA's LICENSE and output docs first) |
| 3 | avd-current-state | Vendor the method and module with `assess/PINS.json`, `-Assess`, coverage moved into the module |
| 4 | this repo | `sources.json` entry, importer files assessment reports, the assessment topic page links the method |
| 5 | this repo, avd-landing-zone, avd-assess | C14 changes (§7.2), PINS bump, then the baseline manifest writer |
| 6 | avd-current-state, avd-assess | Evidence the first checks show is missing becomes C11 facts read through Resource Graph, then checks that use them |
| 7 | (owner's go) | One sandbox run: collector, WARA collector, facts, `-Assess`, baseline manifest, the landing zone's reader in dry run; teardown evidence |

## 11. Open questions

1. Where it lives (§9).
2. Whether the baseline manifest writer is free. The owner said avd-assess is free; this spec reads that as including the writer, the one thing a free user can't do today.
3. Image optimization: whether a session host's WDOT state becomes a fact (a tag the landing zone's image build writes on the gallery image version, or a host-side read by the validator), so image checks can leave `unknown`.
4. Whether the method should also carry the validator's pass/fail rules (about 260 checks), or keep those in avd-current-state and cite them by check name. This spec keeps them where they are: the validator judges a subscription's readiness to deploy, the method judges an estate's design.
