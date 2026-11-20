---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-18
resolves-checks: ["Identity-based auth", "SMB share RBAC", "Minimum TLS version"]
tags: [avd, fslogix, storage, kerberos]
---

# Fix FSLogix profile storage auth and TLS posture

## When to use

- `avd-current-state` reports `Identity-based auth`, `SMB share RBAC`, or `Minimum TLS version` as `FAIL` or `WARN`.
- Users hit temporary profiles or SMB access denied errors when attaching FSLogix VHDX profiles on Azure Files.

## Before you start

- Access needed: Storage Account Contributor and User Access Administrator (for SMB RBAC assignments) on the profile storage account.
- Change window / approval: Required before changing storage identity settings or TLS minimum version.
- Blast radius: All session hosts mounting the target FSLogix Azure Files share.

## Steps

1. Verify the storage account enforces `TLS1_2` minimum:
   ```powershell
   Set-AzStorageAccount -ResourceGroupName '<resource-group>' -Name '<storage-account>' -MinimumTlsVersion TLS1_2
   ```
2. Confirm identity-based authentication (`AzureKerberos` for Entra-joined hosts or `AD` / `AADDS` for domain-joined hosts) is enabled on the storage account (`Get-AzStorageAccount` -> `AzureFilesIdentityBasedAuth`).
3. Ensure the AVD user group holds **Storage File Data SMB Share Contributor** on the file share (or storage account), and admins hold **Storage File Data SMB Share Elevated Contributor**.
4. Confirm NTFS share root permissions allow `CREATOR OWNER` full control (subfolders/files only) and `Users` / AVD user group traverse + create folder at the root.

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `Identity-based auth`, `SMB share RBAC`, and `Minimum TLS version` report `PASS`.

## Roll back

Restore prior RBAC role assignments or `AzureFilesIdentityBasedAuth` configuration if existing clients lose share access.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-18 | avd-ops | Initial draft mapped to `avd-current-state` checks |
