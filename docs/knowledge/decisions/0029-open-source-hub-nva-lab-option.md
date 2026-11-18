---
status: accepted
date: 2026-11-18
decision-makers: [maintainers]
---

# 0029. Open-source Linux Hub NVA option for lab and sandbox egress

## Context and Problem Statement

`avd-networking` supports Azure Firewall (`Basic` in `lab`, `Standard`/`Premium` in `enterprise`) and an external `'nva'` mode (`hubFirewallPrivateIp`). Even Azure Firewall Basic costs roughly $290+/month, which dominates spend in personal lab and sandbox runs where the main requirements are centralized NAT, L3/L4 egress control, and FQDN/SNI allowlisting for AVD Reverse Connect and Entra ID. How should `avd-networking` provide a near-zero-cost egress firewall option for lab and sandbox topologies without weakening security or breaking Azure platform traffic?

## Considered Options

- **Option 1: Keep Azure Firewall Basic as the only built-in hub firewall.** Simple and managed, but ~$290+/month makes always-on or frequent lab runs expensive.
- **Option 2: NSGs + UDRs only (`firewallMode: 'none'`).** Zero cost, but lacks FQDN/SNI egress filtering, DNS query logging, and centralized NAT.
- **Option 3: Opt-in open-source Linux Hub NVA (`nftables` + `squid-openssl` peek-and-splice + local DNS) in `avd-networking`.** Runs on a `Standard_B1s` (1 vCPU, 1 GB RAM) + 1 Static Standard Public IP (~$14–16/month always-on, ~$7–8/month on a lab schedule), providing stateful L3/L4 filtering, transparent HTTP/HTTPS SNI allowlisting, and centralized DNS logging.

## Decision Outcome

Chosen option: "Option 3: Opt-in open-source Linux Hub NVA (`nftables` + `squid-openssl` peek-and-splice + local DNS) in `avd-networking`", gated behind `deployOssNva = false` (opt-in via `parameters/oss-nva-lab.bicepparam`) so production and enterprise presets are unchanged.

### Required Hardening and Red-Team Mitigations

1. **Anti-SNI-spoofing:** Enable `host_verify_strict on` and `client_dst_passthru off` in Squid so claimed TLS SNI / HTTP `Host` headers are validated against resolved IPs; drop raw non-80/443 TCP/UDP in `nftables` `forward` (`policy drop`) so spokes cannot bypass Squid.
2. **DoH / DoT bypass prevention:** Block external `53` and `853` in `nftables` `forward`, force DNS to the NVA, and deny known DoH endpoints (`.dns.google`, `.cloudflare-dns.com`, `.quad9.net`) in Squid's SNI ACL.
3. **Azure platform IP exclusions:** Exclude Azure WireServer and IMDS link-local platform endpoints from `nftables` `prerouting` redirect, `postrouting` masquerade, and `forward`.
4. **Zero public management ports:** Hub NVA NSG denies inbound SSH (`22`) from the internet; operator access uses Tailscale/WireGuard or Azure Serial Console.
5. **AVD protocol trade-off:** TCP `443` Reverse Connect passes through Squid's SNI allowlist (`.wvd.microsoft.com`, `.servicebus.windows.net`, `.login.microsoftonline.com`); UDP `3478` (RDP Shortpath public STUN/TURN) is disabled by default in `nftables` and opt-in only.
6. **Lab-only SLA & sizing floor:** `Standard_B1s` (1 GB RAM) is the minimum floor for `squid-openssl` (512 MB `B1ls` risks OOM); B-series CPU credits can exhaust under bulk Windows Update/FSLogix traffic, so high-bandwidth Azure Storage should use Private Endpoints.

### Consequences

- Good, because lab and sandbox runs get FQDN/SNI egress filtering and centralized NAT for ~95% less than Azure Firewall Basic.
- Good, because `avd-networking` still emits the standard C31 `avd-networking-outputs/v1` contract (`firewallMode: 'nva'`, `hubFirewallPrivateIp`).
- Bad, because a single-VM NVA is a single point of failure with no built-in HA or autoscaling, and requires OS patching (`unattended-upgrades`).

## More Information

- Implemented in `avd-networking` (`bicep/modules/oss-nva.bicep`, `scripts/nva/`, `parameters/oss-nva-lab.bicepparam`).
- Related: [Landing zone topic](../landing-zone/README.md).
