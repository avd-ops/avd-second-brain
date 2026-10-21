# The knowledge base

What the organization has learned across engagements and estates, in a form the engine reads and people review. Design: [docs/knowledge-spec.md](../docs/knowledge-spec.md). Decision: [0002](../docs/knowledge/decisions/0002-knowledge-base.md).

| Path | Holds | Schema |
|---|---|---|
| `knowledge.json` | The scope: `public` here, `organization` in a private fork | `schemas/knowledge.schema.json` |
| `catalog/apps.json` | Public products: match patterns for inventory names, category, multi-session verdict, delivery, evidence | `schemas/app-catalog.schema.json` |
| `rules/*.json` | The engine's thresholds and decision tables, each with a version and a reason for every change | `schemas/rule.schema.json` |

The factory's stage rules (the delivery table and the quality gate) live in the private assessment factory repo (its decision 0004, [decision 0024](../docs/knowledge/decisions/0024-the-brain-is-the-estate-brain.md)); their last copies here are in this folder's history. `rules/workload-tiers.json` stays: it is the prior calibration learns against and target-state manifests (C14) cite it by version. Its users-per-vCPU values follow avd-assess `baselines.yaml`; change them there first.
| `calibration/sizing.json` | Predicted vs measured sessions per host, per wave (organization scope only) | `schemas/calibration.schema.json` |
| `engagements/eng-*.json` | One pseudonymous record per engagement (organization scope only) | `schemas/engagement.schema.json` |
| `denylist.sha256` | SHA-256 of the lowercase names of your customers, one per line (organization scope only) | — |

Lessons stay in `docs/lessons/`; decisions are in `docs/knowledge/decisions/`, the family knowledge base's decision records.

## Ask it

```powershell
./scripts/Find-BrainKnowledge.ps1 'teams media optimization'      # search, with the path to cite
./scripts/Find-BrainKnowledge.ps1 -App 'Skype for Business 2016'  # resolve an inventory name
./scripts/Find-BrainKnowledge.ps1 -Calibration                    # sizing factors per tier and VM family
```

## Add to it

Only by a PR a person merges, normally a harvest after a wave or an engagement closes (spec §6; the `harvest` skill in `.claude/skills/harvest/` drafts one). Before opening the PR:

```powershell
./scripts/Test-Knowledge.ps1      # RESULT PASS, or it lists what to fix
```

Rules the guard enforces:

- **No customer data.** No customer, person or machine names, addresses, tenant or subscription IDs, or the customer's own (line-of-business) apps. Engagements are `eng-<yyyy>-<mm>-<4 chars>`, sizes are buckets.
- **The public brain has no engagement trail.** Engagement records, calibration observations and pilot evidence live only in an organization's private fork.
- **Every verdict has evidence,** and a model never sets one on its own: an entry with `source: llm` needs `reviewedBy` before its verdict counts.
- **Every rule change records why:** bump `version` and add a `history` entry with the reason and the lesson or engagement behind it.
- **A closed engagement has finished its harvest.**

Derived values are never stored: calibration factors are computed from the observations when they are read.
