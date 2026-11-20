---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-20
resolves-checks: ["Intune MDM readiness", "Intune multi-session enrollment and compliance posture"]
tags: [avd, intune, mdm, multisession]
---

# Fix Intune multi-session MDM enrollment and compliance posture

## When to use

- `avd-current-state` reports `Intune MDM readiness` or `Intune multi-session enrollment and compliance posture` as `FAIL` or `WARN`.
- Entra-joined Windows 11 multi-session hosts fail to enroll in Intune or report non-compliant / missing policy assignments.

## Before you start

- Access needed: Intune Administrator (or equivalent RBAC role for device enrollment and configuration profiles).
- Change window / approval: Required before changing MDM enrollment scope or compliance policies.
- Blast radius: Intune-managed session hosts in the targeted device group or assignment filter.

## Steps

1. Confirm MDM automatic enrollment is enabled for the session host scope (Entra ID -> Mobility -> Microsoft Intune) and hosts carry valid Windows Enterprise multi-session / Intune licensing.
2. Verify the session host deployment enables `mdmId` during Entra join so Windows 11 multi-session hosts auto-enroll into Intune at provisioning time.
3. Check Intune assignment filters so policies targeting **Windows 10/11 Enterprise multi-session** (`device.operatingSystemSKU -eq "ServerRdsh"`) are scoped cleanly rather than applied unfiltered to All Devices.
4. On a non-compliant or stalled host, inspect the MDM diagnostics event log (`Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin`) and trigger a policy sync.

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `Intune MDM readiness` and `Intune multi-session enrollment and compliance posture` report `PASS`.

## Roll back

Scope back or unassign the changed Intune configuration or compliance policy from the session host group/filter.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-20 | avd-ops | Initial draft mapped to `avd-current-state` checks |
