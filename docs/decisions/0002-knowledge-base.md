# 0002. The knowledge base: reviewed knowledge in Git, no customer data

- **Status:** Proposed
- **Origin:** avd-readiness-stratusphere decision 0002, moved here with the knowledge base ([0001](0001-one-brain-for-the-avd-lifecycle.md)). "The factory spec" is avd-readiness-stratusphere's `docs/factory-spec.md`.

## Context
The factory spec's last stage (§10.5, Learn) says every engagement should improve the app catalog, the sizing model and the rules for the next one. Without a home and a contract for that knowledge, it stays in people's heads and leaves with them. The knowledge also comes from customer data (per-user telemetry, inventories, LOB app names), so the place where it accumulates must not become a second copy of that data.

## Decision
- The factory's cross-engagement memory lives in `knowledge/` as JSON validated by JSON Schemas: an app catalog, versioned rules with a reason for every change, calibration observations, and pseudonymous engagement records. Lessons and decisions stay in `docs/`. Spec: [knowledge-spec.md](../knowledge-spec.md).
- Knowledge enters only by a **harvest PR** that a person merges. The engine and models propose; they never edit the brain.
- Three scopes: engagement (customer's environment), organization (a private fork), public (this repo). Knowledge moves up only after it is generalized. A guard, `scripts/Test-Knowledge.ps1`, fails CI on customer data: LOB apps, engagement trails in the public scope, sensitive text, and hashed customer names.
- Derived values (calibration factors) are computed when read, never stored.
- JSON over YAML so the guard needs no PowerShell module (`Test-Json`) and Python reads it natively. The factory spec's `catalog/` and `rules/` paths move under `knowledge/`.

## Consequences
- A closed engagement without a harvest fails CI, so learning is part of finishing an engagement.
- The engine reads its thresholds from `knowledge/rules/` and records the brain commit it used, so designs are reproducible.
- The public repo ships schemas, rules and documented public products only; real engagement knowledge lives in organization forks.
- One more set of schemas to maintain, and the sensitive-text scan will need tuning as real harvests hit false positives.
