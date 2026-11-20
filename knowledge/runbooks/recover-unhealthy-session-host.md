---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-18
resolves-checks: ["Session host status", "Agent heartbeat", "Drain mode"]
tags: [avd, session-host, agent]
---

# Recover an unhealthy or drained session host

## When to use

- `avd-current-state` reports `Session host status`, `Agent heartbeat`, or `Drain mode` as `FAIL` or `WARN`.
- A session host shows `Unavailable`, `NeedsAssistance`, or stale heartbeat in the host pool.

## Before you start

- Access needed: Desktop Virtualization Session Host Operator and Virtual Machine Contributor on the host resource group.
- Change window / approval: Required before restarting services or draining active user sessions.
- Blast radius: Single session host VM; active users should be drained or notified before any restart.

## Steps

1. Put the affected host into drain mode if it is still accepting connections:
   ```powershell
   Update-AzWvdSessionHost -ResourceGroupName '<resource-group>' -HostPoolName '<host-pool>' -Name '<session-host>' -AllowNewSession:$false
   ```
2. Check active user sessions on the host (`Get-AzWvdUserSession`) and wait for logoff or coordinate sign-out.
3. On an empty, drained host, check and restart `RDAgentBootLoader` (or run `Restart-AvdAgent.ps1` via Run Command):
   ```powershell
   Get-Service RDAgentBootLoader, RDAgent | Format-Table Name, Status, StartType
   Restart-Service RDAgentBootLoader -Force
   ```
4. Once the host reports `Available` and a fresh heartbeat, re-enable new sessions if appropriate:
   ```powershell
   Update-AzWvdSessionHost -ResourceGroupName '<resource-group>' -HostPoolName '<host-pool>' -Name '<session-host>' -AllowNewSession:$true
   ```

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `Session host status`, `Agent heartbeat`, and `Drain mode` report `PASS`.

## Roll back

Re-enable drain mode (`-AllowNewSession:$false`) if the host returns to an unhealthy state after accepting connections.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-18 | avd-ops | Initial draft mapped to `avd-current-state` checks |
