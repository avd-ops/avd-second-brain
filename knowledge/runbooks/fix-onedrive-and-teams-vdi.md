---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-20
resolves-checks: ["M365 Apps and OneDrive VDI readiness", "OneDrive KFM, Shared Computer Activation and Teams VDI policies"]
tags: [avd, m365, onedrive, teams, vdi]
---

# Fix OneDrive KFM, Shared Computer Activation, and Teams VDI policies

## When to use

- `avd-current-state` reports `M365 Apps and OneDrive VDI readiness` or `OneDrive KFM, Shared Computer Activation and Teams VDI policies` as `FAIL` or `WARN`.
- Users hit Office activation prompts on multi-session hosts, OneDrive fails to sync per-machine, or Microsoft Teams falls back to unoptimized audio/video.

## Before you start

- Access needed: Intune Administrator (or GPO / image administrator for golden-image settings).
- Change window / approval: Required before updating golden images or Intune Settings Catalog policies.
- Blast radius: M365 Apps, OneDrive, and Teams behavior across multi-session hosts in the targeted pool.

## Steps

1. Verify **Shared Computer Activation** (`SharedComputerLicensing = 1`) is enabled for Microsoft 365 Apps on multi-session hosts via Intune Settings Catalog or ODT configuration.
2. Verify **OneDrive** is installed per-machine (`AllUsers`) rather than per-user, and **Known Folder Move (KFM)** + **Files On-Demand** are configured via Intune policy for the multi-session device group.
3. Verify **Microsoft Teams VDI** media optimization (`IsWVDEnvironment = 1` in `HKLM\SOFTWARE\Microsoft\Teams`) and the Remote Desktop WebRTC Redirector Service (or SlimCore plugin) are present and running on the session host image.

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `M365 Apps and OneDrive VDI readiness` and `OneDrive KFM, Shared Computer Activation and Teams VDI policies` report `PASS`.

## Roll back

Revert the Intune Settings Catalog assignment or restore the previous session host image version.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-20 | avd-ops | Initial draft mapped to `avd-current-state` checks |
