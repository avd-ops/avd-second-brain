---
name: harvest
description: Harvest what an engagement, a migration wave, a customer's estate vault or measured sizing evidence taught into the second brain's knowledge base (knowledge/). Use after a wave closes, when an engagement closes, after a vault has collected a few months of findings, or when asked to "harvest", "update the brain", "add this app to the catalog" or "record the sizing we measured".
---

# Harvest into the knowledge base

Spec: `docs/knowledge-spec.md` §5–§6; the sources: `docs/architecture.md` §4 (flows 2, 4 and 5). You read the customer's data locally and write only **generalized** knowledge into `knowledge/`. The harvest is a proposal: a person reviews and merges the PR.

## Before you start

1. Read `knowledge/knowledge.json`. Harvests with engagement trails (records, calibration observations, pilot evidence) go only into an `organization` brain. In the `public` brain, you may only add or update catalog entries backed by a public document (https), and rule changes.
2. Find the source. Each is customer data: never copy from it verbatim, never quote names, and never commit anything from it.
   - A factory **engagement folder** (`output/engagements/<customer>-<yyyymm>/` in the assessment project).
   - A customer's **estate vault**: run `./scripts/Get-VaultHarvest.ps1 -VaultPath <vault>` and work only from its proposal and the candidate files it lists.
   - A **sizing evidence** file (`avd-sizing-evidence/v1`): run `./scripts/Import-SizingEvidence.ps1 -EvidencePath <file>`, and with `-Apply` in an organization brain.
3. Find or create the engagement's pseudonymous ID: `eng-<yyyy>-<mm>-<4 lowercase letters or digits>`, random, not derived from the customer's name. Ask the person for the existing ID if `knowledge/engagements/` doesn't obviously hold it; never guess which record belongs to which customer.

## What to harvest

| Look at | Write | How |
|---|---|---|
| The app test plan's results, `waves/status.yaml`, the pilot notes | `knowledge/catalog/apps.json` | Public products only, never the customer's own apps. Add evidence `{kind: pilot, ref: <eng id>, outcome, summary, date}` to an existing entry, or a new entry. A verdict (`multiSession` other than `unknown`) needs evidence. If you normalized a name or category yourself, set `source: llm` with `llm: {model, promptVersion, date}` and leave the verdict to the evidence |
| `verify/` before/after results per host pool | `knowledge/calibration/sizing.json` | One observation per host pool per wave: tier, VM size and family, predicted sessions per host (from the manifest), measured sessions per host at the calibration rule's target utilization |
| Decisions that turned out wrong (a gate that let bad data through, a persona in the wrong pattern, a delivery choice that failed) | `knowledge/rules/<id>.json` | Change `values`, bump `version`, add a `history` entry: the change, the reason, and `ref` (the lesson path or engagement ID). Add or update a test if the engine has one |
| Real-run surprises (stage 0, deployment, rollout) | The lesson belongs in the repo where it happened (`docs/lessons/` there); this repo searches it in place | What happened, the cause, the fix, the guard |
| The vault harvest's verified runbooks that hold for any estate | `knowledge/runbooks/<kebab-name>.md` | Keep the front matter and `resolves-checks`; take out every name, address, ID and customer-specific step. `Get-VaultHarvest` shows the sensitive count; it must be 0 after you generalize |
| The vault harvest's estate facts | The engagement record's `estate` (`sessionHostsBucket`, `vmFamilies`) | Only when the vault belongs to a factory engagement |
| The engagement itself | `knowledge/engagements/<eng id>.json` | Period (year-month), status, estate in buckets (`<500`, `500-2k`, `2k-10k`, `>10k`), platforms, sources, outcome. When the engagement closes: `harvest: {done: true, date, by: <the reviewing person>, catalogEntries, ruleChanges, lessons, calibrationObservations}` |

## Generalize, then check

- Replace anything specific with the general fact: "the profile share" not its path, "a finance persona" not a department name, "500-2k users" not a count.
- Run `./scripts/Test-Knowledge.ps1`. It must end with `RESULT PASS`. A `sensitive:*` finding means customer data got through: remove it, don't work around the pattern.
- Run `./scripts/Find-BrainKnowledge.ps1 -Calibration` and say in the PR whether any factor changed or started to apply.

## The PR

Title `Harvest <eng id>: <wave or close>`. Body: what was added or changed and the evidence for each, any rule change with its reason, calibration changes, and anything you were unsure about for the reviewer. Never include customer names, even in the PR text.
