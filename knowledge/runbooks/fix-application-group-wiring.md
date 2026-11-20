---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-20
resolves-checks: ["Application group wiring"]
tags: [avd, draft]
---

# Remediate Application group wiring

## When to use

- `avd-current-state` reports `Application group wiring` as `FAIL` or `WARN`.

## Before you start

- Access needed: Least-privilege reader/contributor role for the affected control plane.
- Change window / approval: Required before making state changes.
- Blast radius: Scope of the failing `Application group wiring` finding.

## Steps

1. Inspect the failing `Application group wiring` detail in the `avd-current-state` validator output.
2. Apply the minimal fix for the affected resource or policy.
3. Document any environment-specific prerequisites before promoting this draft to `verified`.

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `Application group wiring` reports `PASS`.

## Roll back

Revert the resource or policy change made in Steps.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-20 | runbook-coverage | Auto-drafted stub for uncovered validator check |

