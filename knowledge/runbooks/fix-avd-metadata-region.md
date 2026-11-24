---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-24
resolves-checks: ["AVD metadata region"]
tags: [avd, draft]
---

# Remediate AVD metadata region

## When to use

- `avd-current-state` reports `AVD metadata region` as `FAIL` or `WARN`.

## Before you start

- Access needed: Least-privilege reader/contributor role for the affected control plane.
- Change window / approval: Required before making state changes.
- Blast radius: Scope of the failing `AVD metadata region` finding.

## Steps

1. Inspect the failing `AVD metadata region` detail in the `avd-current-state` validator output.
2. Apply the minimal fix for the affected resource or policy.
3. Document any environment-specific prerequisites before promoting this draft to `verified`.

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `AVD metadata region` reports `PASS`.

## Roll back

Revert the resource or policy change made in Steps.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-24 | runbook-coverage | Auto-drafted stub for uncovered validator check |

