---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-18
resolves-checks: ["Scaling plan", "Power role sufficiency", "AVD power management role"]
tags: [avd, scaling-plan, rbac, cost]
---

# Fix scaling plan assignment and AVD power management role

## When to use

- `avd-current-state` reports `Scaling plan`, `Power role sufficiency`, or `AVD power management role` as `FAIL` or `WARN`.
- Autoscale fails to start or deallocate session host VMs during ramp-up or off-peak windows.

## Before you start

- Access needed: User Access Administrator (or Owner) on the session host resource group or subscription, plus Desktop Virtualization Contributor.
- Change window / approval: Low risk for RBAC assignment; schedule changes take effect on the next scaling evaluation window.
- Blast radius: Target host pool scaling behavior.

## Steps

1. Look up the Azure Virtual Desktop first-party service principal (`Azure Virtual Desktop` / `Windows Virtual Desktop`).
2. Grant **Desktop Virtualization Power On Off Contributor** to that service principal at the narrowest scope that covers the host pool and its session host VMs (typically the session host resource group):
   ```powershell
   $sp = Get-AzADServicePrincipal -DisplayName 'Azure Virtual Desktop'
   New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName 'Desktop Virtualization Power On Off Contributor' -ResourceGroupName '<resource-group>'
   ```
3. Verify the scaling plan is assigned and enabled on the host pool (`Get-AzWvdScalingPlan` -> `HostPoolReference`).

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `Scaling plan`, `Power role sufficiency`, and `AVD power management role` report `PASS`.

## Roll back

Remove the role assignment (`Remove-AzRoleAssignment`) or disable the host pool reference on the scaling plan (`Update-AzWvdScalingPlan`).

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-18 | avd-ops | Initial draft mapped to `avd-current-state` checks |
