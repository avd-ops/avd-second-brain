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
