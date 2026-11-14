---
title: "AVD Hybrid and Azure Arc"
summary: "Platform-agnostic architecture, OS/identity constraints, networking, storage, and Arc onboarding learnings for running AVD Hybrid session hosts on non-Azure clouds and on-premises hypervisors"
topic: landing-zone
status: verified
last_reviewed: 2026-11-14
sources:
  - https://learn.microsoft.com/azure/virtual-desktop/hybrid-overview
  - https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop-hybrid
  - https://docs.cloud.google.com/netapp/volumes/docs/configure-and-use/active-directory/about-ad
---

# AVD Hybrid and Azure Arc

Platform-agnostic reference for running Azure Virtual Desktop (AVD) Hybrid session hosts on non-Azure infrastructure (GCP, AWS, VMware vSphere, Hyper-V, Nutanix AHV, or headless physical servers) while keeping the AVD brokering and management control plane in Azure.

## Core architecture (platform-agnostic)

1. **Azure control plane**: Standard AVD workspace, application groups, and a host pool created without Azure VMs or Session Host Configuration. The host pool requires a managed identity granted `Reader` on the Azure Resource Group holding the Arc-enabled servers.
2. **External compute**: Any Windows VM or dedicated headless physical server on the target platform.
3. **Azure Arc bridge**: Install `AzureConnectedMachineAgent` (`azcmagent`) to project each host into the target Azure Resource Group, then install `Microsoft.AzureVirtualDesktop.CloudDeviceExtension` with the host pool registration token.

## Hard constraints across every platform

- **No Windows 10/11 Enterprise multi-session**: AVD Hybrid supports single-session **Windows 10/11 Enterprise** (Entra-joined, AD DS-joined, or hybrid-joined) and **Windows Server 2016–2025** (AD DS-joined or hybrid-joined only, due to RDS licensing).
- **No Azure-managed VM lifecycle**: Power management, AVD Autoscale, Start VM on Connect, and Session Host Configuration are unsupported. The hosting platform (e.g., GCP Managed Instance Groups + Cloud Instance Schedules, AWS ASG, or hypervisor automation) owns provisioning, scaling, and power schedules.
- **Outbound-only networking**: Session hosts require outbound TCP `443` to both AVD service endpoints and Azure Arc endpoints (plus optional outbound UDP `3478` for RDP Shortpath TURN/STUN relays). Block inbound internet RDP (`3389`).
- **Licensing**: Users require both an eligible OS entitlement (M365/Windows Enterprise/VDA for client OS; RDS CAL with SA or RDS USL for Windows Server) and the per-user AVD Hybrid service license.

## Storage and FSLogix for Entra-only estates

- **Third-party managed SMB services (such as Google Cloud NetApp Volumes) require AD DS**: They do not support workgroup mode or native Entra ID / Entra Kerberos authentication.
- **Entra-joined only (no AD DS / Entra DS / Managed AD)** estates have two options:
  1. **Local profiles (`fslogixStorageMode = "disabled"`)**: Best fit for single-session Windows 11 Personal desktops with persistent boot disks.
  2. **Azure Files with Microsoft Entra Kerberos**: For pooled/non-persistent single-session hosts without AD DS, reachable over VPN or SMB over QUIC.

## Reusable onboarding & contract pattern

- **Onboarding script**: Keep `azcmagent` installation and connection idempotent (`azcmagent show --json` check before `azcmagent connect`), parameterized by subscription, Arc resource group, tenant, location, scoped service principal, and host pool name (see [avd-gcp `scripts/arc-onboard.ps1`](https://github.com/avd-ops/avd-gcp/blob/main/scripts/arc-onboard.ps1)).
- **Handoff contract**: Use redacted JSON output contracts (such as C32 `avd-gcp-outputs/v1` in `avd-assess`) to pass `osFamily`, `identityMode`, `egressMode`, `fslogixStorageMode`, `arcResourceGroup`, and `hostPoolName` back to `avd-azure`, `avd-landing-zone`, and `avd-current-state`.
