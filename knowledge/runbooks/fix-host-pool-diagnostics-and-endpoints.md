---
type: runbook
status: draft
owner: avd-ops
last-verified: 2026-11-20
resolves-checks: ["Host pool diagnostics", "AVD required endpoints", "NSG egress to AVD"]
tags: [avd, diagnostics, networking, nsg]
---

# Fix host pool diagnostic settings and AVD required egress

## When to use

- `avd-current-state` reports `Host pool diagnostics`, `AVD required endpoints`, or `NSG egress to AVD` as `FAIL` or `WARN`.
- Connection telemetry (`WVDConnections`, `WVDErrors`, `WVDAgentHealthStatus`) is missing in Log Analytics, or session hosts cannot reach required AVD control-plane endpoints.

## Before you start

- Access needed: Monitoring Contributor on the host pool and Network Contributor on the session host subnet NSG.
- Change window / approval: Required before modifying NSG outbound rules.
- Blast radius: Diagnostic log ingestion and outbound network connectivity for the session host subnet.

## Steps

1. Verify the host pool has an active Azure Monitor diagnostic setting sending `Checkpoint`, `Error`, `Management`, `Connection`, `HostRegistration`, `AgentHealthStatus`, and `NetworkData` to the target Log Analytics workspace:
   ```powershell
   Get-AzDiagnosticSetting -ResourceId '<host-pool-resource-id>'
   ```
2. On the session host subnet NSG, confirm outbound HTTPS (`443`) is allowed to the `WindowsVirtualDesktop` service tag (plus Azure Monitor / storage / Entra endpoints as required).
3. From a session host, verify DNS resolution and TLS connectivity to the required AVD service endpoints (`rdbroker.wvd.microsoft.com`, `rdweb.wvd.microsoft.com`, `rdgateway.wvd.microsoft.com`).

## Verify

Re-run `avd_deployment_validator.ps1` and ingest the package into your estate vault. Confirm `Host pool diagnostics`, `AVD required endpoints`, and `NSG egress to AVD` report `PASS`.

## Roll back

Remove any added NSG rule (`Remove-AzNetworkSecurityRuleConfig`) or restore the prior diagnostic setting.

## History

| Date | Who | Note |
|---|---|---|
| 2026-11-20 | avd-ops | Initial draft mapped to `avd-current-state` checks |
