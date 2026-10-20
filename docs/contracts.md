# Contracts between the repos and the brain

What each repo gives the brain and takes from it, in a form that can be tested. A change to a contract is a PR here, and the producing or consuming repo follows. Overview: [architecture.md](architecture.md) §4.

| # | Contract | Producer | Consumer | Format | Status |
|---|---|---|---|---|---|
| C1 | Evidence packages | avd-current-state collector and validator | `vault/avd_second_brain.ps1` | The packages as they are: `manifest.json` plus dataset JSON files | Built |
| C2 | Vault harvest proposal | `scripts/Get-VaultHarvest.ps1` | A person, then `knowledge/` by PR | Console or `-Json` | Built |
| C3 | Engagement harvest | avd-readiness-stratusphere (the `harvest` skill, later `avdmf learn`) | `knowledge/` by PR | The knowledge schemas (`knowledge/schemas/`) | Built |
| C4 | Sizing evidence | Factory verify stage; landing-zone operations brain | `scripts/Import-SizingEvidence.ps1` | `avd-sizing-evidence/v1` (`contracts/schemas/sizing-evidence.schema.json`) | Importer built; producers specified |
| C5 | Host pool attribution tags | The factory's `lz-cloudnative` renderer | The operations brain, when it writes C4 | Tags on the host pool | Specified |
| C6 | Reading the knowledge base | `knowledge/` at a commit | The factory engine; the landing zone's sizing and image pipeline | The knowledge schemas, pinned by commit | Specified |
| C7 | Searchable docs | Every connected repo | `scripts/Find-BrainKnowledge.ps1` | Markdown under the paths in `sources/sources.json` | Built |
| C8 | Swarm insights | avd-swarm's Improve workflow and judge auditor | The `harvest` skill, then `knowledge/` by PR | `avd-swarm-insights/v1`: counts and topics from a fixed vocabulary, no free text, no names or IDs | Specified |
| C9 | Playbook run proposal | The brain (a playbook matched to an episode by signature) | avd-swarm's `propose_playbook_run`, then its gate and approval | Playbook ID and content hash, targets as resource IDs, parameters bound from the episode, evidence links, the Critic's dissent | Specified |
| C10 | Action outcomes and switch position | avd-swarm | The brain's episodes and its own halts | Outcome per plan (verified, failed, rolled back, rejected with a reason category), its compliance change per Defender for Cloud control (fixes, regressions and exemptions counted apart; Microsoft's public control and recommendation names, resource IDs only for regressions) and the kill switch position, as events | Specified |
| C11 | Current-state facts | avd-current-state `avd_current_state_facts.ps1`, from the C1 packages | `scripts/Import-CurrentStateFacts.ps1`, then the brain's agents; avd-swarm only through the brain | `avd-current-state-facts/v1` (`contracts/schemas/current-state-facts.schema.json`): counts, booleans, public Azure values and keyed pseudonyms, no names, IDs, IPs, tags or free text | Built (producer and importer, offline) |
| C12 | Forensic facts | avd-readiness-stratusphere's factory, from its pseudonymized estate model (Stratusphere telemetry) | The brain's agents, as C11; avd-swarm only through the brain | `avd-forensic-facts/v1`: per host pool or persona, aggregates over a measured window (concurrency, demand per user and per host, logon, UX, profile, latency), at least 10 users per group and coarser data under 20, no user or machine at all | Specified |
| C13 | Docs findings | `scripts/Test-DocConsistency.ps1`, nightly across the connected repos ([docs-spec.md](docs-spec.md)) | avd-swarm's Scribe, which drafts fixes as PRs | `avd-doc-findings/v1` (`contracts/schemas/doc-findings.schema.json`): check ID, severity, repo, path, line, what the text says, the source of truth, the side to fix; quotes only the repos' own public text | Built (the check and the schema); Scribe, its consumer, is avd-swarm's phase D1 |
| C14 | Target-state manifest | avd-readiness-stratusphere's factory (stage 5, design) | avd-landing-zone's `ConvertFrom-AvdTargetState.ps1`; avd-liquidware for its `liquidware` block, later; the harvest, as buckets only | `avd-target-state/v1` (`contracts/schemas/target-state.schema.json`) and its approval, `avd-target-approval/v1` (`target-approval.schema.json`); example pair in `contracts/examples/` | Schemas and checks built; producer waits on factory phase 1, reader built |
| C15 | Fact register | This repo | Every producer and consumer of C11, C12 and C14; avd-current-state's manifest coverage | `avd-fact-register/v1` (`contracts/fact-register.json`, schema `fact-register.schema.json`) | Built |
| C16 | Stratusphere instrument outputs | avd-liquidware (the Stratusphere instrument, moving there from avd-readiness-stratusphere) | avd-readiness-stratusphere's ingest and quality gate | `stratusphere-instrument/v1`: preflight, appliance and rollout reports, local only (they hold machine names) | Proposed: the schema lands with its producer |
| C17 | Run records | Every family repo that records a run: avd-landing-zone first ([run recorder spec](https://github.com/nickprignano/avd-landing-zone/blob/master/build/specs/run-recorder-spec.md)), then the use cases in `contracts/run-use-cases.json` | The operator (resume, teardown, copies), the run report, and the brain only through public-level field reports | `avd-run-record/v1` (`run-record.schema.json`), its journal lines (`run-journal.schema.json`) and `avd-run-cost/v1` (`run-cost.schema.json`); examples in `contracts/examples/run-record/` | Schemas built; producer being built in avd-landing-zone |
| C18 | Lifecycle record: why an environment is the way it is | The brain, from approved C14 manifests (`ConvertFrom-TargetStateDecision`), the operator's decisions and ADRs, C17 runs and avd-swarm's C10 outcomes | The brain's agents (`Get-LifecycleExplanation`, `Get-LifecycleReview`), the vault's `/ask` and `/brief`, and the harvest as buckets only; avd-swarm only through the brain | `avd-lifecycle-record/v1` (`lifecycle-record.schema.json`); example `contracts/examples/lifecycle-record.example.json` | Schema, checks and the explain and review functions built (offline); writers specified |

C8 to C10 connect the brain to avd-swarm ([decision 0003](knowledge/decisions/0003-brain-thinks-swarm-acts.md)): the brain proposes, avd-swarm acts. A change to one of them is a pair of PRs, one here and one in avd-swarm, each linking the other. C13 is the same split for the repos' own text: the brain decides what is inconsistent, avd-swarm drafts the fix ([decision 0004](knowledge/decisions/0004-docs-consistency.md)), and a change to it is a pair of PRs. C14 and C15 sit on top of the fact layer: a manifest is a design whose every decision cites C11, C12 or intake facts by their register ID, and the register is the one list of those IDs. C17 is the one shape for a recorded run, whichever repo ran it, so a run of the landing zone, an image build, the Liquidware tier or an avd-swarm plan can be resumed, copied, costed and torn down the same way. C16 is between two producers and never reaches the brain; it is listed here because this repo is the one registry of cross-repo formats ([avd-readiness-stratusphere boundaries spec](https://github.com/nickprignano/avd-readiness-stratusphere/blob/main/docs/boundaries-spec.md)). C11 and C12 are the fact layer under both: C11 the Azure-side inventory every estate gets, C12 the forensic tier when a question needs measured performance. A change to either is three PRs: here, the producer (avd-current-state or avd-readiness-stratusphere) and avd-swarm (its gate rule). C18 is the why on top of all of them: one record per environment of its use cases, the decisions made about it (with what else was considered and why not) and the events that carried them out, from its birth onwards. avd-swarm records the how (its plans and their C10 outcomes), and the brain keeps and explains the why ([decision 0020](knowledge/decisions/0020-the-brain-is-the-why-layer.md)).

## C1. Evidence packages → vault

The vault reads collector packages (`manifest.json` with `SubscriptionDetails`) and validator packages (`manifest.json` with `Verdict`), as folders or ZIPs, in any order. From the collector it reads `avd-host-pools`, `avd-session-hosts`, `virtual-machines`, `avd-workspaces`, `avd-application-groups` and `arm-resources` per subscription folder. From the validator it reads `validation-results`. A change to those dataset names or their fields in avd-current-state is a contract change: `tests/Connectors.Tests.ps1` builds minimal packages of both kinds and runs them through the vault, so update its fixture in the same change.

## C2. Vault → knowledge

`Get-VaultHarvest` reads the latest inventory and validation snapshot per environment and returns:

- **Estate**: a session host bucket (`1-10`, `11-50`, `51-200`, `>200`), host pool count and types, VM families, configured max session limits. These go into an engagement record when the vault belongs to a factory engagement.
- **Recurring checks**: validator checks still `FAIL` or `WARN`, by category and check name, with the number of environments. Never the scope or detail, which name resources.
- **Candidates**: verified runbooks and lessons, each with its count of sensitive-text findings.

Configured max session limits are not calibration evidence: they are what someone set, not what users did.

## C3. Engagement → knowledge

See the [knowledge spec](knowledge-spec.md) §6 and `.claude/skills/harvest/SKILL.md`.

## C4. `avd-sizing-evidence/v1`

One document per period (and wave, for the factory). There's no field for a name: no host pool, host, resource or user name can travel in it.

```json
{
  "schema": "avd-sizing-evidence/v1",
  "source": "landing-zone-brain",
  "engagement": "eng-2026-11-a7f3",
  "wave": 2,
  "period": { "start": "2027-01-01", "end": "2027-01-31" },
  "hostPools": [
    { "tier": "medium", "vmSize": "Standard_E8as_v5", "maxSessionLimit": 14, "hosts": 10,
      "predictedSessionsPerHost": 14, "peakSessionsPerHost": 10,
      "p95CpuPercent": 50, "p95MemoryPercent": 80 }
  ]
}
```

| Field | Producer's source |
|---|---|
| `peakSessionsPerHost` | Peak concurrent sessions per available host in working hours: `WVDConnections` in the landing zone, Stratusphere session data in the factory |
| `p95CpuPercent`, `p95MemoryPercent` | Per-host `Perf` counters (landing zone, AVD Insights DCR) or Stratusphere host metrics, p95 over working hours |
| `predictedSessionsPerHost` | The manifest the pool was designed with (factory); omitted otherwise, and `maxSessionLimit` stands in |
| `tier`, `engagement` | C5 tags |

**Conversion.** Sessions per host at the target utilization (`knowledge/rules/workload-tiers.json`, 0.8) = peak sessions per host × target ÷ the higher of p95 CPU and p95 memory. That resource is `boundBy`. The extrapolation is linear, so `knowledge/rules/calibration.json` refuses host pools whose peak is below 3 sessions per host or whose binding utilization is under 40%. Host pools without an engagement or a tier are skipped with the reason.

**Producers.**
- *Factory verify stage* (avd-readiness-stratusphere factory spec §10.4): one document per wave, `source: factory-verify`.
- *Operations brain* (avd-landing-zone, [operations spec](operations-spec.md) §4.6 baselines): a monthly document from the daily baselines, `source: landing-zone-brain`. It is a read-only job, so it fits Tier 1 of that spec.

## C5. Host pool tags

| Tag | Value | Set by |
|---|---|---|
| `avdbrain-engagement` | `eng-<yyyy>-<mm>-<4 chars>` | The `lz-cloudnative` renderer, from the manifest |
| `avdbrain-tier` | `light`, `medium`, `heavy`, `power` or `gpu` | Same, from the host pool's persona |

They hold no customer data: the engagement ID is pseudonymous by construction.

## C6. Reading the knowledge base

Consumers read the JSON files directly, validated against `knowledge/schemas/`, at a commit they record (the factory's manifest field `brainCommit`). They cite entries as `knowledge/catalog/apps.json#<id>` and `knowledge/rules/<id>.json@v<version>`. Calibration factors are computed with `Get-SizingCalibration` (or a port of it with the same tests), never read from a stored value.

## C7. Searchable docs

`sources/sources.json` lists each repo, the ref to follow, and the Markdown paths worth searching. `scripts/Sync-BrainSources.ps1` checks them out into `.sources/` (git-ignored) and records each commit in `.sources/lock.json`, so a citation names the exact text: `avd-landing-zone@5f10290:docs/gotchas.md`.

## C11. `avd-current-state-facts/v1`

The fact collection layer of the brain and avd-swarm. C1 gives the vault everything the collector and validator saw, for people. C11 gives the same evidence in the form the brain's agents (Diagnose, Critic, the Concierge) reason over, that their prompts hold, and that a C9 proposal cites. (The vault's `/ask` and `/brief` commands are a person's tools inside their private vault, outside this.) avd-swarm never reads a package, a vault or a snapshot file; it gets facts only from the brain, as answers with citations and as C9 evidence.

```
collector + validator packages ──C1──► estate vault (private; names and IDs, for people)
            │
            └─► avd_current_state_facts.ps1 (offline, the estate's key)
                        │
                        ▼ C11
              vault facts/<estate>/<time>.json ──► brain agents ──C9 evidence──► avd-swarm gate
```

**What it holds.** Per subscription: regions, dataset counts, host pools (type, load balancing, max session limit, Start VM on Connect, RDP property names without values, app group types, session hosts by status, agent, SxS and OS version, stale heartbeats, VM sizes, marketplace images or `custom`), VM sizes and power states, storage accounts (kind, SKU, TLS, network default, private endpoint), network counts (custom DNS, NSGs and route tables on subnets, default routes by next hop, private endpoints by group), Key Vault protection, Log Analytics retention, policy assignment counts, and role assignments by built-in role. Per validator run: mode, verdict, counts, the planned region, host count and VM size, and every check as phase, category, check name, status and, when it is in the snapshot, the pseudonym of what it checked.

**What it can't hold.** The schema has no field for a name, a resource ID, an object ID, an IP address, a tag, a user, a check's scope or detail, or a recommendation, and every string has a pattern. A custom role counts as `other`; a value that doesn't fit its pattern becomes `other` and is counted in `redactedValues`. A validator check name that contains a collected name becomes `redacted`. The producer scans the result for GUIDs, email addresses, UNC paths and IPv4 addresses and refuses to write it if it finds one; the importer runs the brain's guard over it again and refuses on any finding.

**Pseudonyms.** `sub-`, `hp-`, `st-` and `est-` (the tenant) followed by the first 8 hex characters of HMAC-SHA256 over the kind and the lowercased resource ID, keyed with the estate's **`resources` subkey**. The same key gives the same pseudonyms on every run, so the brain sees one host pool's trend without its name. The brain keeps no mapping: whoever needs the real target recomputes the pseudonym over live resource IDs with the key, in the tenant. With an operations brain deployed, the key is derived from the landing zone's Key Vault `resources` secret with HKDF-SHA256 ([operations spec](operations-spec.md) §9.4). It is not the `users` subkey, which rotates every 12 months to crypto-shred user pseudonyms: resource IDs aren't personal data, so a host pool's trend line survives that rotation (second red team AX-16). Without an operations brain, the key is a file beside the vault (`.brain/facts.key`, ignored by the vault template's `.gitignore`), backed up like any secret and never committed. The producer (avd-current-state) moves to the derived subkey when it is next changed; until then its file key is already separate from any user key.

**Freshness.** A snapshot is evidence of the moment its packages were collected (`collectedUtc`, `generatedUtc` per validator run), not of now. The brain cites it with that time: `facts:<estate>@<generatedUtc>#/subscriptions/0/hostPools/1`. avd-swarm's gate refuses a C9 proposal whose only evidence is a snapshot older than its freshness limit (avd-swarm governance §2.1, 7 days by default) and resolves every target live before approval; a snapshot is a reason to propose, never the target list.

**Producer and consumer.** avd-current-state's `avd_current_state_facts.ps1` (Windows PowerShell 5.1 and PowerShell 7, offline, tests in its `tests/Facts.Tests.ps1` against a copy of this schema) writes the snapshot; `scripts/Import-CurrentStateFacts.ps1` checks it (`Test-CurrentStateFacts`) and, with `-Apply`, files it in the vault under `facts/<estate>/`. It refuses to write inside this repository: a snapshot is still one estate's data. Generalized facts for the knowledge base still come through the vault harvest (C2).

## C12. `avd-forensic-facts/v1` (specified)

The forensic tier of the fact layer. C11 says what an estate is configured as, from Azure's control plane, for free. It can't say what users do: how many are on at 10:00, how hard they push a host, how long logon takes, how big profiles are, where latency hurts. That is Stratusphere UX telemetry, collected by avd-readiness-stratusphere's instrument over a 2-to-4-week window and normalized into the factory's pseudonymized estate model (`estate.duckdb`, factory spec §4.3–4.4). C12 is what of it the brain's agents may read.

| | C11 current-state facts | C12 forensic facts |
|---|---|---|
| Answers | What is deployed and is it wired right | How it performs and how big it needs to be |
| Source | ARM (collector, validator) | Endpoint telemetry (Stratusphere Connector ID Key), plus C11 for the host pool mapping |
| Cost | $0, minutes, any time | Hub appliance VMs and a license for the window, weeks; only when a question needs it |
| Grain | Resource (subscription, host pool, storage account) | Group: a host pool (estate already on AVD) or a persona (estate not yet on AVD), never a user or a machine |
| Freshness limit at avd-swarm's gate | 7 days | 90 days after the window ends |

**Shape** (the schema lands with the producer, factory phase 1, once a real Hub has fixed the field names, factory Q1):

```json
{
  "schema": "avd-forensic-facts/v1",
  "estate": "est-2540bffa",
  "engagement": "eng-2026-11-a7f3",
  "window": { "start": "2026-11-02", "end": "2026-11-27", "days": 26, "peakIncluded": true },
  "quality": { "coverage": 0.86, "verdict": "pass" },
  "groups": [
    { "kind": "hostPool", "id": "hp-ac5fc5e3", "tier": "medium", "users": 120,
      "concurrency": { "peak": 84, "byHour": [0, 0, 0, 0, 0, 0, 3, 22, 61, 80, 84, 82, 70, 79, 81, 77, 60, 31, 9, 2, 0, 0, 0, 0] },
      "perUser": { "p95CpuPercentOfCore": 38, "p95MemoryMiB": 2900, "p95DiskIops": 14 },
      "perHost": { "peakSessionsPerHost": 11, "p95CpuPercent": 62, "p95MemoryPercent": 81 },
      "logonSeconds": { "p50": 21, "p95": 48 }, "uxScoreMedian": 7.9,
      "profile": { "p95SizeGiB": 6.2, "logonIopsPerUser": 55 }, "rttMsP95": 64,
      "apps": { "catalog": ["microsoft-teams", "sap-gui"], "unknown": 7 } }
  ]
}
```

**Rules.**
- **No user, no machine, no small team** (second red team AX-16). A group of 5 to 10 users active at night on one named app is a specific team to anyone who knows the customer, and a p95 over 5 users is one person. So:
  - **At least 10 users per group.** A smaller group folds into its nearest neighbor or is dropped with a count.
  - **Groups of 10 to 19 get coarser data:** `concurrency.peak` without `byHour`; `perUser` as p50 (`p50CpuPercentOfCore`, `p50MemoryMiB`, `p50DiskIops`), never p95; no `apps.catalog`, only the count of apps seen. `perHost`, logon, UX, profile and latency stay, since they describe hosts and the group as a whole.
  - **Groups of 20 or more** get the full shape above. `byHour` is rounded to the nearest 5 sessions for every group.
  - App usage is catalog IDs (`knowledge/catalog/apps.json`, public products) plus a count of the unknown ones, never names or paths.
- **One key, one pseudonym space.** The producer uses the estate's C11 key. With an avd-current-state collector package, machines that are session hosts map to their host pool's resource ID, so `hp-ac5fc5e3` here is the same host pool as in C11, and the brain can put configuration and behavior side by side. Personas (`persona-<n>`) are for estates not yet on AVD.
- **Agents get only what a question names.** The brain's tool for C12 returns the groups and facts a question names, by fact register ID, never the whole document; a prompt to the model carries those values only. Facts of the `group-behavior` privacy class (C15) are quoted as the cited fact, never as the group's whole profile.
- **Quality travels with the numbers.** The factory's quality gate (§5) result is part of the document; a `low-confidence` snapshot may inform, never back a sizing proposal.
- **C4 is a subset.** For a factory-designed host pool (C5 tags) at the verify stage, the same numbers become `avd-sizing-evidence/v1` for calibration. C12 is the wider, per-estate view the agents reason with.
- **Asking for one is an action.** Forensic collection deploys appliances and costs money, so the brain doesn't start it: when a question needs measured data (a sizing or size-change proposal, a performance complaint with no ARM-side cause, a migration), it says so, and the collection is a plan avd-swarm runs through its spend gate, approval and teardown evidence (avd-swarm spec §6d).

## C13. `avd-doc-findings/v1`

What the docs consistency check found, for avd-swarm's Scribe to draft fixes from. The checks (D1 to D11), the sources of truth and an example document are in [docs-spec.md](docs-spec.md) §6 and §9. Built in phase D0: `scripts/Test-DocConsistency.ps1 -JsonPath` writes it, the nightly `docs-sweep` workflow keeps it as an artifact, the schema is `contracts/schemas/doc-findings.schema.json` and its tests are in `tests/Connectors.Tests.ps1`. Each finding carries a `key` that is stable across runs (it leaves out the line), so a repo can accept a finding in its `docs/accepted-findings.json` and Scribe can track one from night to night. Scribe, the consumer, is avd-swarm's phase D1.

## C14. `avd-target-state/v1` and `avd-target-approval/v1`

What the assessment produces and the landing zone deploys: one design, every deployed value a **decision** (`value`, `evidence`, `confidence`, optionally `rule`, `boundBy`, `override`). It replaces the factory spec's `factory.avd/v1`, which was never built. Design and reasons: avd-readiness-stratusphere's [boundaries spec](https://github.com/nickprignano/avd-readiness-stratusphere/blob/main/docs/boundaries-spec.md) §3.

```
C11 snapshot ─┐
C12 facts ────┼─► factory analysis ─► manifest.json ─► person reviews ─► approval.json (pins the manifest's SHA-256)
intake ───────┘        (rules at pins.brainCommit)                          │
                                                                            ▼
                                     avd-landing-zone ConvertFrom-AvdTargetState.ps1 ─► preflight + deploy.sh commands
```

**Pseudonymous, not public.** Host pools by pseudonym (`hp-` existing, `tp-NN` target, `persona-N`), apps by catalog ID, regions and VM sizes by public name; no tenant, subscription, group or object ID, user, machine or address, and a `note` of at most 200 characters with no links. A manifest lives in the engagement folder and the customer's private repo. **It never enters `knowledge/`:** a harvest projects it onto the engagement record's buckets, and `Test-BrainKnowledge` fails on any estate pseudonym (`est-`, `hp-`, `st-`, `sub-`) in `knowledge/`.

**Approval is a second file.** `avd-target-approval/v1` holds the manifest file's SHA-256 (over its exact bytes), the approval time and the decisions a person accepted at `confidence: low`. Who approved is the commit that added it in the customer's repo. Readers refuse a manifest without a matching approval.

**What `Test-TargetState` checks** beyond the schema: the guard; the register version the manifest pins; every citation is a registered fact that isn't `proposed`, that the register lists as evidence for that decision, and that names its subject when its grain is a host pool, group, storage account or host; cited rules exist in `knowledge/rules/` at that version or lower; pool IDs are unique; `hosts × maxSessions` covers each pool's peak; `lz-cloudnative` manifests have no gaps. `tests/Connectors.Tests.ps1` runs it over the example and over one broken copy per rule.

**Freshness** is checked against the approval date: within 7 days of the C11 snapshot and 90 days of the C12 window's end when decisions cite them, the same limits avd-swarm's gate uses. avd-swarm doesn't read manifests yet; deploying one is an operator's run of the landing zone.

## C15. `avd-fact-register/v1`

`contracts/fact-register.json`: the **decisions** a manifest makes (with the manifest path and the tiers whose facts alone can support each) and the **facts** any repo may cite (ID, tier, contract and JSON path, grain, unit, privacy class, status, and the decisions it can evidence). `Test-FactRegister` keeps it honest: unique IDs, a prefix per tier (`c11.`, `c12.`, `intake.`, `liquidware.`), known decisions, no proposed fact as evidence, and every **built** fact's path resolvable in its contract's schema, so renaming a C11 field without the register fails CI. Privacy classes: `count`, `public`, `pseudonym`, `boolean`, `measure`, and `group-behavior` for C12's per-group measures, its hourly concurrency and its app catalog, which together can describe a team (C12 rules). A test keeps every such C12 fact in that class.

- `version` goes up whenever a fact is removed or renamed; manifests pin it.
- C12 facts are `specified`: their paths follow C12's shape above and are checked when its schema lands.
- `liquidware.*` facts (avd-liquidware spec §10.1) are `proposed` and can't be cited until the Liquidware tier builds them.
- avd-current-state vendors a copy for its **manifest coverage** line: how many decisions an estate's C11 snapshot can support (those whose `decidableFrom` includes `azure`), and which need measurement.

## C16. `stratusphere-instrument/v1` (proposed)

The output files of the Stratusphere instrument that avd-readiness-stratusphere reads: the deployment preflight's `manifest.json` and `current-state.json`, the appliance check report (with each role's address), and the Connector ID Key rollout report (per machine: name, resource ID, subscription ID, status, version, source channel). Every one holds names, so none reaches the brain; the factory pseudonymizes at ingest. The instrument is moving from avd-readiness-stratusphere to avd-liquidware; the Liquidware project lands this schema with its producer, and the factory's consumer test follows in the same set of PRs (boundaries spec §4).


## C17. `avd-run-record/v1` and `avd-run-cost/v1`

One shape for a recorded run, so every repo in the family can record its runs the same way and new use cases fit in without a new contract. A run folder `runs/<runId>/` holds:

- `run.json` (`run-record.schema.json`): the run ID, its **use case**, the producing repo and commit, steps, region, status, the **manifest** of every file with its SHA-256 and each verified copy (a file with no verified copy is the last copy: decision 0017), and how teardown ended (`-TeardownLogs`, `-KeepRunning`).
- `journal.jsonl` (`run-journal.schema.json`): one event per line: `step.start`, `check`, `api.error`, `step.end`, `operator.note`.
- `cost.json` (`run-cost.schema.json`): expected cost written before anything is deployed, each line with the retail meter it matched (or `none`/`several` and no price, never a guess), the cap and the go/no-go rule, then each actual reading appended until it settles, and the comparison (difference, meters the estimate didn't know about, anything billing after teardown).

**Growing it without breaking it.**

- **A new use case** is a line in `contracts/run-use-cases.json` (ID, producer, status). It adds fields only under `extensions.<useCase>` in `run.json` or `cost.json`, and events only named `x.<useCase>.<name>` in the journal, which carry `useCase`. A use case that settles its fields adds a schema for its extension here.
- **Experiments** use `extensions.x-<name>` and `x.x-<name>.<event>` until they are registered.
- **Within v1, changes are additive:** a new optional field, event or use case. Readers ignore fields they don't know and keep events they don't know. A field is never renamed or removed in v1, and a core event's required fields never change.
- **A breaking change is v2,** and readers accept v1 and v2 for at least one release of each producer.

**Privacy.** `level: private` (secrets removed by the producer's redaction, tenant names and IDs kept) lives only in the operator's run store and their own private companion repo, never a project repo. `level: public` has also passed the public redaction (avd-landing-zone's `report.js`) and may go into a public issue or report. Cost files carry no subscription or resource IDs. The brain reads runs only as public-level field reports a person filed, through the harvest.

`tests/Connectors.Tests.ps1` checks the examples against the schemas, that every example's use case is registered, and that a guessed price, an unregistered event and an extension event without its use case are refused.

## C18. `avd-lifecycle-record/v1`

Why one environment is built and performs the way it does, from the day it is born. The facts (C11, C12) say what an environment is and how it behaves; the runs (C17) and avd-swarm's plans (C10) say what was done to it. Neither says **why**: which use cases it serves, what was decided at each step, what else was considered and why not, and which decision each change carried out. Today that lives in people's heads and in the vault's free-text ADRs, which the brain's agents can't read (they read only pseudonymous facts). C18 is that why, in a form the agents can reason over and cite. Decision: [0020](knowledge/decisions/0020-the-brain-is-the-why-layer.md).

```
C14 approved manifest ──ConvertFrom-TargetStateDecision──┐  (birth: the design decisions)
operator decisions and vault ADRs (adr:ADR-NNNN) ───────┤
C17 run records (run:<runId>) ──────────────────────────┼─► vault lifecycle/<environment>.json ─► Get-LifecycleExplanation
avd-swarm plans and C10 outcomes (plan:<planId>, why) ──┤        (Test-LifecycleRecord)          Get-LifecycleReview
C11 / C12 facts (watch, change) ────────────────────────┘                                           │
                                                                    brain agents, Concierge, /ask, /brief ◄┘
```

**What it holds.** One document per environment (`env-` pseudonym, keyed like C11 with the estate's `resources` subkey over the environment's resource group or subscription):

- **Use cases** (`uc-NN`): a kind from a fixed list (knowledge worker, task worker, developer, contractor, graphics, disaster recovery and so on), the workload tier, a users bucket (never a count of named people), the persona and host pools that serve it, the apps by catalog ID, and when it started and stopped.
- **Decisions** (`dec-NNNN`): the phase (assess, design, build, configure, expand, contract, fix, recover, retire, operate), a topic (a fact register decision such as `hostPool.vmSize`, or a lifecycle topic such as `profiles` or `scaling`), the subjects and use cases it is about, the **chosen** value, the **alternatives** with a reason category for each (`whyNot`), the **drivers**, the **evidence**, the facts it **watches**, a review date, its status and what it supersedes, its source and the role that decided (never a person).
- **Events** (`evt-NNNN`): born, build, configure, expand, contract, fix, recover, retire, drift, incident or review, with the decisions it carried out, the actor (a landing-zone run, an avd-swarm plan, the operator, the scaling plan, the platform), the C17 run ID or the plan ID, the outcome, and the before and after of the facts it changed. A born event maps design subjects onto what was deployed (`tp-01` became `hp-5e6f7a8b`), so the design's decisions follow the host pool.

Evidence cites facts by register ID (C15), rules (`rule:workload-tiers@v1`), the manifest decision (`manifest:<first 12 hex of its SHA-256>#hostPool.vmSize`), runs (`run:`), plans (`plan:`), public docs at a commit as C7 cites them (`doc:avd-landing-zone@326a3c5:build/lessons/...`), the vault's ADR number (`adr:ADR-0003`, where the full text with names stays) and earlier events.

**What it can't hold.** Like C14: no tenant, subscription, group or object ID, user, machine or address, no person's name for who decided, and notes of at most 200 characters with no links, which harvests drop. Values are public values (sizes, regions, settings, counts, catalog IDs). The guard runs over the whole document. It lives in the estate vault under `lifecycle/`, never in `knowledge/`: `Test-BrainKnowledge` refuses `env-` pseudonyms there as it does the others.

**What `Test-LifecycleRecord` checks** beyond the schema: the guard; the register version; unique IDs; every use case, decision and event a record points at exists; every fact it cites is registered, citable and names its subject when its grain needs one; cited rules exist at that version or lower; one birth, with nothing before it; a superseded decision is marked so, is superseded by something, and is older than what supersedes it. Two **warnings** are the point of the record, the gaps the brain asks a person to fill: a change (build to retire, or drift) that no decision explains, and an accepted decision with no alternatives.

**What the brain does with it.**
- `Get-LifecycleExplanation -Subject hp-...`: the use cases a host pool serves, the decisions in force about it with their alternatives and drivers, its history in time order with the decision behind each event, and the changes nothing explains, each with a citation (`lifecycle:<environment>#dec-0006`). This is what the Concierge and the vault's `/ask` answer "why is this pool ten E8 hosts?" from.
- `Get-LifecycleReview -Changed <facts> -AsOf <date>`: the decisions to revisit because a fact they watch has changed (peak concurrency, p95 memory, round-trip time) or their review date has come. A changed reason is a Notice, never an action: the brain may propose, avd-swarm acts (decision 0003).
- **Performance** is explained the same way: a C12 window or a C11 trend on a host pool is read beside the events and decisions before it, so "logons got slower in February" lands next to "evt-0005: expand, dec-0006, contractors joined".

**Who writes it.** The brain, and only into the estate vault, from what flows to it:

| Source | Becomes | Status |
|---|---|---|
| An approved C14 manifest | The design decisions at birth (`ConvertFrom-TargetStateDecision`), one per register decision; a person adds the alternatives | Built (offline) |
| A landing-zone run (C17), read from the operator's run store by the operator | A born, build, configure or retire event with its `run` ID | Specified |
| An operator's decision, or a vault ADR | A decision with `source: adr` or `operator`, citing `adr:ADR-NNNN` | Specified (the vault's `/capture` drafts it) |
| An avd-swarm plan's `why` and its C10 outcome | The event, and the plan's decision accepted (verified) or reverted (rolled back) | Specified, with the C10 feed (avd-swarm spec §6f) |
| Two C11 snapshots or C12 windows | Drift events and the input to `Get-LifecycleReview` | Specified |

**The landing zone and avd-current-state never depend on it.** avd-landing-zone and avd-current-state stay a self-contained pair that deploys, inventories and validates with no brain and no avd-swarm. C18 only reads what they already emit (C17 run IDs, C11 snapshots); nothing in either repo reads, requires or waits for a lifecycle record, and no change to C18 is a change to them.
