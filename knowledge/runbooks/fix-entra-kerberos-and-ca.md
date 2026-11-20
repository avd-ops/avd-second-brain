---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-20
resolves-checks: ["Entra groups, Conditional Access and Kerberos posture", "Entra VM login role"]
tags: [avd, entra, kerberos, rbac, sso]
---

# Fix Entra VM login RBAC, Conditional Access, and Kerberos posture

## When to use

- `avd-current-state` reports `Entra groups, Conditional Access and Kerberos posture` or `Entra VM login role` as `FAIL` or `WARN`.
- Users cannot sign in to Entra-joined session hosts, hit MFA loops during RDP SSO, or fail FSLogix SMB auth with Entra Kerberos.

## Before you start

- Access needed: User Access Administrator (for VM login RBAC) and Entra Conditional Access / Application Administrator.
- Change window / approval: Required before modifying Conditional Access policies or Entra Kerberos server objects.
- Blast radius: Sign-in and SSO behavior for the targeted AVD user group and session host resource group.

## Steps

1. Confirm the AVD user group holds **Virtual Machine User Login** (and admins hold **Virtual Machine Administrator Login**) on the session host resource group:
   ```powershell
   New-AzRoleAssignment -ObjectId '<avd-users-group-object-id>' -RoleDefinitionName 'Virtual Machine User Login' -ResourceGroupName '<session-host-rg>'
   ```
2. Verify that Conditional Access policies targeting **Azure Virtual Desktop** (and **Microsoft Remote Desktop** client apps) allow SSO/MFA as designed without blocking the Windows App or Web Client.
3. For Entra-joined hosts using FSLogix on Azure Files, confirm Cloud Kerberos Ticket Retrieval is enabled on session hosts (`AllowCloudKerberosTicketRetrieval = 1`) and the storage account has Entra Kerberos configured.

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `Entra groups, Conditional Access and Kerberos posture` and `Entra VM login role` report `PASS`.

## Roll back

Remove unintended RBAC assignments (`Remove-AzRoleAssignment`) or revert the Conditional Access policy change in Entra ID.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-20 | avd-ops | Initial draft mapped to `avd-current-state` checks |
