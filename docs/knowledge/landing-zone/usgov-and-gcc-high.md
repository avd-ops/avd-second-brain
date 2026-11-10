---
title: "Azure US Government and GCC High"
summary: "Sovereign cloud endpoints, Private DNS zones, ITAR/CUI redirection defaults, workload placement, and CI verification for Azure US Government and Microsoft 365 GCC High"
topic: landing-zone
status: verified
last_reviewed: 2026-11-10
sources:
  - https://learn.microsoft.com/azure/virtual-desktop/overview-gov
  - https://learn.microsoft.com/azure/virtual-desktop/Compare-us-gov-commercial
  - https://learn.microsoft.com/windows-365/enterprise/requirements-gov
  - https://learn.microsoft.com/intune/intune-service/fundamentals/intune-us-government-endpoints
  - https://learn.microsoft.com/office365/servicedescriptions/office-365-platform-service-description/office-365-us-government/gcc-high-and-dod
  - https://learn.microsoft.com/power-platform/admin/powerapps-us-government
  - https://learn.microsoft.com/azure/azure-government/compare-azure-government-global-azure
---

# Azure US Government and GCC High

How the five control planes ([avd-entra](https://github.com/avd-ops/avd-entra), [avd-intune](https://github.com/avd-ops/avd-intune), [avd-m365](https://github.com/avd-ops/avd-m365), [avd-azure](https://github.com/avd-ops/avd-azure), and [avd-power-platform](https://github.com/avd-ops/avd-power-platform)), the orchestrator ([avd-landing-zone](https://github.com/avd-ops/avd-landing-zone)), the collector and assessment engine ([avd-current-state](https://github.com/avd-ops/avd-current-state)), and the browser linecheck ([avd-linecheck](https://github.com/avd-ops/avd-linecheck)) support **Azure US Government (`AzureUSGovernment`)** paired with **Microsoft 365 GCC High** (`cloud = 'usgov'`) and **ITAR / CUI** (`complianceProfile = 'itar-cui'`) estates ([avd-ops decision 0013](https://github.com/avd-ops/avd-ops/blob/main/docs/knowledge/decisions/0013-azure-us-government-and-gcc-high-support.md)).

## Cloud environment contract (`C26: avd-cloud-environments/v1`)

All cloud-specific endpoints, DNS suffixes, Private Link zone names, allowed regions (`usgovvirginia`, `usgovarizona`, `usgovtexas`), and capability flags are defined once in [avd-assess `contracts/cloud-environments.json`](https://github.com/avd-ops/avd-assess/blob/main/contracts/cloud-environments.json) (`contracts/schemas/cloud-environments.schema.json`) and vendored across the family:

| Surface | Commercial (`commercial`) | US Government / GCC High (`usgov`) |
|---|---|---|
| Azure CLI / Az PowerShell cloud | `AzureCloud` | `AzureUSGovernment` |
| ARM endpoint | `https://management.azure.com` | `https://management.usgovcloudapi.net` |
| Microsoft Graph | `https://graph.microsoft.com` (`Global`) | `https://graph.microsoft.us` (`USGov`) |
| Entra authority | `https://login.microsoftonline.com` | `https://login.microsoftonline.us` |
| AVD feed / broker | `rdweb.wvd.microsoft.com`, `rdbroker.wvd.microsoft.com` | `rdweb.wvd.azure.us`, `rdbroker.wvd.azure.us` |
| Storage / Key Vault suffixes | `core.windows.net`, `vault.azure.net` | `core.usgovcloudapi.net`, `vault.usgovcloudapi.net` |
| Private DNS zones (Files, Vault, AVD) | `privatelink.file.core.windows.net`, `privatelink.vaultcore.azure.net`, `privatelink.wvd.microsoft.com` | `privatelink.file.core.usgovcloudapi.net`, `privatelink.vaultcore.usgovcloudapi.net`, `privatelink.wvd.azure.us` |
| Teams / Exchange PowerShell | Commercial (`O365Default`) | `-TeamsEnvironment GCCHigh`, `-ExchangeEnvironmentName O365USGovGCCHigh` |
| Power Platform BAP / Dataverse / CLI | `https://api.bap.microsoft.com`, `*.crm.dynamics.com`, `--cloud Public` | `https://high.api.bap.microsoft.us`, `*.crm9.dynamics.com`, `--cloud UsGovHigh` |

## Desktop DevOps workload placement and sizing rules in `usgov`

When evaluating or designing an estate with `cloud == "usgov"` (`C14`, `C18`, `C21`, and [decision 0027](../decisions/0027-desktop-devops-across-avd-win365-and-intune.md)), placement and cost rules respect the sovereign capability flags in `C26`:

- **Windows 365 Government requires an Azure Network Connection (ANC) (`windows365AncRequired: true`).** Microsoft Hosted Network (MHN) is not available in Windows 365 Government. Every Windows 365 Enterprise Cloud PC provisioning policy in `usgov` must attach a passing `onPremisesConnectionId` (Entra hybrid join or Entra join over an ANC VNet subnet in `usgovvirginia` or `usgovarizona`).
- **Windows 365 Frontline is excluded while unsupported in GCC High (`windows365FrontlineSupported: false`).** Shift and part-time multi-user personas that would otherwise evaluate Windows 365 Frontline in commercial clouds are placed on **AVD Pooled multi-session** host pools with autoscale in `usgov`.
- **Bastion `Developer` SKU is unavailable in `AzureUSGovernment` (`bastionDeveloperSkuSupported: false`).** When the opt-in jumpbox is enabled in `usgov`, the landing zone provisions **Azure Bastion `Basic`** (with `AzureBastionSubnet` `/26` and a Standard Public IP) instead of the zero-cost `Developer` SKU, and preflight cost estimates include the hourly Bastion Basic meter.
- **Service parity gaps are scored `not-applicable` (`reason: "unsupported-in-cloud"`), never `gap`.** Teams Multimedia Redirection (`teamsMmrSupported: false`, check `asm-m365-mmr`) and AVD screen capture watermarking (`watermarksSupported: false`) are not supported in `AzureUSGovernment` / GCC High; new Teams VDI uses SlimCore media optimization, and session protection uses screen capture protection (`EnableScreenCaptureProtection`) plus hardened RDP redirection controls.
- **Cross-cloud combinations are rejected.** An Azure US Government AVD deployment paired with a commercial Microsoft Entra ID / M365 tenant (or vice versa) requires Entra B2B / cross-cloud collaboration and breaks native single-tenant Entra join, Intune automatic MDM enrollment, and Windows Cloud Login SSO. All five control planes must share the same sovereign cloud boundary (`asm-gov-sovereign-cloud-alignment`).

## Lessons learned from the five-plane GovCloud design

- **`.onmicrosoft.us` and US Gov platform suffixes in redactors.** Initial tenant domains in Microsoft 365 GCC High / Azure US Government use `.onmicrosoft.us` alongside `.onmicrosoft.com`, and platform endpoints use `.azure.us`, `.usgovcloudapi.net`, `.microsoftonline.us`, `.microsoft.us`, `.sharepoint.us`, and `.appsplatform.us`. Redactors that only match `.onmicrosoft.com` or commercial `.com`/`.net` allowlists either leak sovereign tenant domains or misclassify sovereign platform hostnames as custom domains (fixed in `avd-ops` portal engine `redact.js`).
- **Sign-in context drift off Cloud Shell in sovereign clouds.** `if (-not (Get-AzContext))` and `az account show` succeed even when a local workstation is signed into `AzureCloud` instead of `AzureUSGovernment`, and `Connect-MgGraph` defaults to `Global`. Sovereign cloud preambles and preflight guards must check `(Get-AzContext).Environment.Name -eq 'AzureUSGovernment'`, run `az cloud set --name AzureUSGovernment`, pass `-Environment USGov` to `Connect-MgGraph` (`--cloud UsGovHigh` to `pac`), and fail closed before the first API call if `Az`, `az` CLI, `MgGraph`, `pac`, and stage manifests disagree on the active cloud.
- **Retail Prices API (`prices.azure.com`) in boundary-monitored ITAR / GCC High networks.** Microsoft's Retail Prices API serves `usgovvirginia`, `usgovarizona`, and `usgovtexas` meter prices from a `.com` endpoint (`https://prices.azure.com/api/retail/prices`) with no `.us` mirror, and browser probes to `.com` / `.windows.net` trip GCC High boundary monitoring. In `usgov`, portals must probe only `.azure.us` / `.usgovcloudapi.net` hosts, and preflight pricing needs an automatic fallback (`-OfflinePricing`) to a dated, pinned US Gov retail rate snapshot when `.com` egress is blocked.
- **Offline CI verification (`standing: guarded`) for sovereign clouds.** Without a standing `AzureUSGovernment` lab subscription, `usgov` support is proven to `standing: guarded` in CI by compiling Bicep with `cloudEnvironment = 'usgov'` under PSRule `Azure.USGov`, asserting zero `.windows.net` / `.azure.com` / `wvd.microsoft.com` / `login.microsoftonline.com` strings in compiled ARM JSON and PowerShell ASTs when `usgov` is selected, and running Pester mocks with `Environment.Name = 'AzureUSGovernment'`.
- **Sovereign Private DNS zones and Bicep `environment()` suffixes.** Hardcoding `.file.core.windows.net`, `privatelink.file.core.windows.net`, `privatelink.vaultcore.azure.net`, or `privatelink.wvd.microsoft.com` in Bicep breaks Private Link resolution and Entra Kerberos storage app naming in `AzureUSGovernment`. Derive storage and authority endpoints from `environment().suffixes.storage` and `environment().authentication.loginEndpoint`, and map Private DNS zone names from `cloudEnvironment` (`privatelink.file.core.usgovcloudapi.net`, `privatelink.vaultcore.usgovcloudapi.net`, `privatelink.wvd.azure.us`, `privatelink.global.wvd.azure.us`) (`asm-gov-private-dns-zones`).
- **ITAR / CUI data-exfiltration redirection defaults (`complianceProfile = 'itar-cui'`).** Commercial AVD host pools often leave clipboard or drive redirection relaxed until hardened by policy. Under `complianceProfile = 'itar-cui'`, host pool `customRdpProperty` and matching Intune Settings Catalog policies (`avd-itar-cui-redirection.json`) disable clipboard (`redirectclipboard:i:0`), drive (`redirectdrives:i:0`), printer (`redirectprinters:i:0`), USB (`usbdevicestoredirect:s:`), and PnP (`redirectpnpdevices:i:0`) redirection by default (`asm-gov-itar-redirection-lockdown`) and enforce TLS 1.2+ and AES-256-GCM SMB channel encryption (`asm-gov-fips-tls-baseline`).
