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
| C12 | Forensic facts | avd-readiness-stratusphere's factory, from its pseudonymized estate model (Stratusphere telemetry) | The brain's agents, as C11; avd-swarm only through the brain | `avd-forensic-facts/v1`: per host pool or persona, aggregates over a measured window (concurrency, p95 demand per user and per host, logon, UX, profile, latency), at least 5 users per group, no user or machine at all | Specified |

C8 to C10 connect the brain to avd-swarm ([decision 0003](decisions/0003-brain-thinks-swarm-acts.md)): the brain proposes, avd-swarm acts. A change to one of them is a pair of PRs, one here and one in avd-swarm, each linking the other. C11 and C12 are the fact layer under both: C11 the Azure-side inventory every estate gets, C12 the forensic tier when a question needs measured performance. A change to either is three PRs: here, the producer (avd-current-state or avd-readiness-stratusphere) and avd-swarm (its gate rule).

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

**Pseudonyms.** `sub-`, `hp-`, `st-` and `est-` (the tenant) followed by the first 8 hex characters of HMAC-SHA256 over the kind and the lowercased resource ID, keyed with the estate's key. The same key gives the same pseudonyms on every run, so the brain sees one host pool's trend without its name. The brain keeps no mapping: whoever needs the real target recomputes the pseudonym over live resource IDs with the key, in the tenant. With an operations brain deployed, the key is the one in the landing zone's Key Vault ([operations spec](operations-spec.md) §9.4), and rotating it is the same crypto-shredding. Without one, the key is a file beside the vault (`.brain/facts.key`, ignored by the vault template's `.gitignore`), backed up like any secret and never committed.

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
- **No user, no machine.** Groups only, at least 5 users each; a smaller group folds into its nearest neighbor or is dropped with a count. App usage is catalog IDs (`knowledge/catalog/apps.json`, public products) plus a count of the unknown ones, never names or paths.
- **One key, one pseudonym space.** The producer uses the estate's C11 key. With an avd-current-state collector package, machines that are session hosts map to their host pool's resource ID, so `hp-ac5fc5e3` here is the same host pool as in C11, and the brain can put configuration and behavior side by side. Personas (`persona-<n>`) are for estates not yet on AVD.
- **Quality travels with the numbers.** The factory's quality gate (§5) result is part of the document; a `low-confidence` snapshot may inform, never back a sizing proposal.
- **C4 is a subset.** For a factory-designed host pool (C5 tags) at the verify stage, the same numbers become `avd-sizing-evidence/v1` for calibration. C12 is the wider, per-estate view the agents reason with.
- **Asking for one is an action.** Forensic collection deploys appliances and costs money, so the brain doesn't start it: when a question needs measured data (a sizing or size-change proposal, a performance complaint with no ARM-side cause, a migration), it says so, and the collection is a plan avd-swarm runs through its spend gate, approval and teardown evidence (avd-swarm spec §6d).

