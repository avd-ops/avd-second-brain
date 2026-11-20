---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-18
resolves-checks: ["Registration token", "Session host registration"]
tags: [avd, host-pool, registration]
---

# Rotate expired host pool registration token

## When to use

- `avd-current-state` reports `Registration token` or `Session host registration` as `FAIL` or `WARN`.
- New or re-imaged session hosts fail to join the host pool with an expired or missing registration token.

## Before you start

- Access needed: Desktop Virtualization Contributor (or equivalent) on the host pool resource group.
- Change window / approval: Low risk; generating a new token does not affect already-registered hosts.
- Blast radius: Single host pool registration key; existing sessions stay connected.

## Steps

1. Inspect the current token expiration on the target host pool (PowerShell `Az.DesktopVirtualization`):
   ```powershell
   Get-AzWvdRegistrationInfo -ResourceGroupName '<resource-group>' -HostPoolName '<host-pool>'
   ```
2. Generate a new short-lived registration token (for example, 4 hours):
   ```powershell
   $expires = (Get-Date).ToUniversalTime().AddHours(4).ToString('o')
   New-AzWvdRegistrationInfo -ResourceGroupName '<resource-group>' -HostPoolName '<host-pool>' -ExpirationTime $expires
   ```
3. Re-run host registration or the session host deployment step using the new token, then remove or let the token expire after enrollment completes.

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the new package into your estate vault (`vault/avd_second_brain.ps1 -PackagePath <output>`). Confirm `Registration token` and `Session host registration` report `PASS`.

## Roll back

Revoke the token if issued in error by clearing or rotating it with `Remove-AzWvdRegistrationInfo` / `New-AzWvdRegistrationInfo`.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-18 | avd-ops | Initial draft mapped to `avd-current-state` checks |
