---
title: "Port plan: an AVD-native Terraform kit from the nerdio-hcl approach"
summary: "Plan to port nerdio-hcl's approach to Terraform that deploys and operates AVD directly, with no Nerdio Manager in the path; awaits the owner's yes"
topic: roadmap
status: plan
last_reviewed: 2026-10-21
---

# Port plan: an AVD-native Terraform kit from the nerdio-hcl approach

The owner asked for a plan to port the approach of
[nerdio-hcl](https://github.com/nickprignano/nerdio-hcl) (Apache-2.0) to Terraform that deploys
and operates Azure Virtual Desktop directly, with no Nerdio Manager in the path. This page is the
plan only. No code is written until the owner says yes, and the first open question below decides
where the code may live at all. The decision it needs is
[0025](../decisions/0025-avd-native-terraform-kit.md).

nerdio-hcl was read at commit `75f59bc` (2026-10-21), read-only. Nothing was copied from it yet;
any file reused later keeps its Apache-2.0 header and a NOTICE line. Nothing is taken from Nerdio's
own repositories or from other unlicensed Nerdio projects, which are reference only in nerdio-hcl
too (its decision 0013).

## The constraint that comes first

The family's lanes ([0012](../decisions/0012-family-format-project-lanes.md),
[family.yaml](../family.yaml) `not_here`) forbid HCL in every AVD repo, and CI enforces it
(this KB's `validate.py`, the landing zone's `lanes.yml`, avd-swarm's `no-hcl` Guard). The lane
for Terraform and Packer is owned by nerdio-hcl. So an AVD-native Terraform kit can't land in
avd-landing-zone, avd-current-state, avd-swarm, avd-assess, avd-ops or this repo as things stand.
Two ways through, both the owner's call (question 1): a new sibling repo in the HCL lane, or a
change to decision 0012. No lane file changes until the owner answers.

## 1. Maps one to one

Design that carries over almost unchanged, minus the Nerdio parts.

| nerdio-hcl piece | In the AVD-native kit | Notes |
|---|---|---|
| Eight phases: discover, prepare, configure, bootstrap, deploy, wizard, verify, handover | Same eight. "Wizard" becomes **first sign-in and assignment** (no vendor wizard exists) | Phase list in `schema/parameters.json` |
| One parameter schema driving chat, `init` and the Actions form | Same shape, new parameters (section 3) | Discover questions (environment, identity model, users, workload, region) carry over as is |
| `modules/foundation` (resource groups, provider registration, Log Analytics) | Same | Adds `Microsoft.DesktopVirtualization` and AVD Insights prerequisites |
| `modules/network` (spoke, subnets, NSGs, NAT gateway, private DNS, hub peering) | Same, minus the App Service subnet | Landing zone lesson 0001 (NAT gateway public IP zones) and 0010 (private endpoint resource group) apply |
| `modules/fslogix-storage` (Premium Azure Files, private endpoint, Entra Kerberos / AD DS / Entra DS, SMB RBAC) | Same, plus the landing zone's SMB channel encryption fix | Channel encryption must allow AES-128-GCM with AES-256-GCM for Entra Kerberos (landing zone lesson 0028) |
| `modules/image-gallery` + `packer/avd-win11` with WDOT | Same gallery and Packer build | See the WDOT pin difference in question 7 |
| `modules/deploy-pipeline` (state storage, plan and apply OIDC identities, required-reviewer environment, saved-plan hash) | Same | Keyless; apply only after a named reviewer approves |
| `modules/github-repo` (labels, read-only token, ruleset) | Same | |
| Least privilege, `docs/access.md`, constrained RBAC Administrator, PIM for one-time steps | Same rule; a much smaller Graph footprint | No vendor app registration, so no `Application.ReadWrite.All` or consent roles by default |
| Read-only readiness engine (check registry, stable IDs, Reader-only, `no-access` and `skipped`, masked JSON) | Same engine; Nerdio checks removed | Keeps `op.*`, `sub.providers`, `sub.region`, `sub.policy_list`, `net.*`, `avd.vcpu`, `avd.vm_size`, `avd.licenses`, `id.sub_owner`, `id.entra_roles`, `id.domain_join_account` |
| Key Vault for secret hand-off, ephemeral reads, write-only attributes | Same, for the few secrets left (local admin, domain join account) | Operators never type them (landing zone decision 0004 does the same in Bicep) |
| Cloud Shell baseline, `cloudshell-bootstrap.sh`, Codespaces optional | Same | iPad is the test case |
| `terraform test`, tflint, gitleaks, no tracked tfvars or state | Same | |
| KB format, decisions, known errors, curator | Same family format | |

## 2. Must be redesigned

| Area | Why it changes | Redesign |
|---|---|---|
| Ownership of AVD objects (nerdio-hcl 0002: "Nerdio owns AVD objects", never `azurerm_virtual_desktop_*`) | Reversed: nothing else owns them now | Terraform owns host pools, app groups, workspaces, scaling plans and their associations through `azurerm`. Runtime state that the service changes (scaling, drain, power) is ignored in `lifecycle` so Terraform and autoscale don't fight |
| Two stages, two states (platform, then Nerdio config) | Stage 2 existed only because Nerdio had to be running first | One **platform** stage plus an **estate** stage per host pool (so a pool can be planned and replaced alone), plus an **image** stage |
| Session host lifecycle | Nerdio created, resized and replaced hosts | Option A: Terraform VMs (count or for_each) with Run Command / extensions for join and agent registration, rotation by name generation, like the landing zone's blue/green. Option B: the service's own **session host configuration and session host update** (preview, pooled only, through `azapi`). Recommend A as default, B as an opt-in for pooled pools (question 5) |
| Registration token | Nerdio handled it | `azurerm_virtual_desktop_host_pool_registration_info` with a short expiry, consumed by the agent install, never output |
| Readiness checks | Nerdio-specific ones go | Drop `sub.nerdio_license`, `sub.app_service`, `sub.sql`, `id.app_registration`. Add AVD ones (section 3) |
| Chat assistant's tool surface | It drove a two-stage Nerdio flow | Same assistant design (Container Apps, Entra sign-in, Claude API by workload identity federation, can start plans, can't approve); new questions and explanations |
| Hardening module | Built for Nerdio's App Service, SQL and Key Vault | Private endpoints for profile storage, Key Vault and the AVD private link (optional), not for a management app |
| `Mastercard/restapi` gap fillers | No vendor API left | `azapi` for anything `azurerm` lacks (session host configuration, newer AVD properties) |

## 3. New: what Nerdio used to do

| Nerdio did | Native replacement | Built how |
|---|---|---|
| Auto-scale profiles (CPU triggers, burst, min active, scale-in messaging) | **AVD scaling plans** (schedules, ramp-up/peak/ramp-down/off-peak, capacity thresholds, drain and notify), pooled and personal | `azurerm_virtual_desktop_scaling_plan` + host pool association; the service principal role assignment it needs. Dynamic autoscale (create and delete hosts) only with session host configuration (preview) |
| Image management: import, set as image, rollout | Compute Gallery versions, pinned by version in tfvars; rollout by host rotation (or session host update) | Packer stage behind approval; a new version is a PR that changes the pin |
| Scripted actions | Run Commands (protected parameters), image-time Packer provisioners | Terraform `azurerm_virtual_machine_run_command`; nothing ad hoc from chat |
| User-driven provisioning for personal desktops | Personal host pools with automatic assignment plus Start VM on Connect | Start VM on Connect role assignment for the AVD service principal; pre-provisioned hosts sized by a parameter. A request-a-desktop flow is a gated workflow, later |
| Power management and cost savings | Scaling plans, auto shutdown, budgets | Budget and alert per environment; tags for cost |
| Monitoring and alerts | **AVD Insights**: Log Analytics, the data collection rule, diagnostic settings on host pools, app groups and workspaces, Azure Monitor Agent | `azurerm_monitor_data_collection_rule` and association; note session host update does not install the agent itself |
| Desktop and RemoteApp assignment | App groups + `Desktop Virtualization User` on Entra groups; `Virtual Machine User Login` for Entra-joined hosts | `azurerm_role_assignment`, groups from the schema |
| Auto-heal and broken host handling | No native auto-heal | Out of the first build; read-only health checks in the verify phase |
| Its own dashboards and reports | Azure portal, AVD Insights workbooks | Link them in the handover runbook |
| New readiness checks | | `avd.region` (AVD metadata location), `avd.host_pool_limits`, `avd.scaling_plan_role`, `id.vm_user_login`, `net.avd_endpoints` (required URLs from the session host subnet, read-only where possible) |

## 4. How it relates to avd-landing-zone

The landing zone already deploys and operates this in Bicep: control plane, session hosts, FSLogix,
AVD Insights, Azure Image Builder with WDOT, blue/green rotation, auto shutdown, backup, Bastion,
budgets, readiness preflight and the portal, with 30 lessons from real runs. A Terraform kit is a
second engine for the same estate shape. Options (question 2):

1. **Separate repo, shared contracts (recommended).** The kit reads the same target-state
   manifest (C14) the landing zone reads, with its own capability list, and keeps its own
   parameter schema. avd-current-state can check a kit-built estate read-only. The landing zone
   and avd-current-state don't change and never depend on the kit, so they stay a self-contained
   pair; the brain and avd-swarm are not involved.
2. **Shared parameter schema** used by the landing zone's portal and the kit. More reuse, but the
   landing zone would have to adopt a schema it doesn't need, so it fails the self-contained rule
   for now.
3. **Parallel option inside the landing zone.** Blocked by the lane rule, and two engines in one
   repo double every test and review.

Lessons and design facts from the landing zone (MIT) are reused by link and in our own words;
where a fix is the same (lesson 0028, lesson 0021 on ARM omitting empty properties, lesson 0024
on quota), the kit gets its own test.

## 5. Build or adopt

Under [0023](../decisions/0023-family-format-best-open-source-or-build.md), adopt only what is
the best and open source. Candidates to check in phase 0, each with a pinned version: Azure
Verified Modules for Terraform (AVD host pool, application group, workspace, scaling plan and the
AVD pattern modules), and Microsoft's AVD landing zone accelerator Terraform. If they hold up, the
kit wraps them like the landing zone wraps AVM Bicep modules; if not, it writes its own, and the
reason goes in the record. Phase 0 also runs the prior-art check.

## 6. Open questions for the owner

1. **Where does the code live?** Answered 2026-10-21: a sibling repo in the HCL lane, separate
   from the AVD repos, so decision 0012 and its guards stay as they are. The owner keeps it
   private for now, so it isn't named here and gets no family.yaml row until it goes public.
   Still open: its license (Apache-2.0 recommended, to match nerdio-hcl's reused files) and
   which Claude project builds in it.
2. **How does it relate to the landing zone?** Separate repo with shared contracts
   (recommended), shared parameter schema, or parallel option (section 4).
3. **Scope of the first build:** pooled, Entra-joined, one host pool, FSLogix on Azure Files,
   marketplace image first (recommended), with personal pools, AD DS and the custom image in
   later phases?
4. **Images:** Packer (HCL first, nerdio-hcl's build reused with attribution) or Azure Image
   Builder through `azapi` (what the landing zone uses)? Recommend Packer.
5. **Session hosts:** Terraform-managed VMs with rotation (recommended default) or session host
   configuration and session host update (preview, pooled only) as an opt-in?
6. **The chat assistant:** port it in the first build, or ship the engine, CLI and Actions form
   first and add the chat after? Recommend the engine first, chat in phase 3; the schema is built
   for both from day one.
7. **WDOT pin:** nerdio-hcl pins WDOT `main` at a later commit because its KB infers that v1.1
   breaks a first run on a VM with no WDOT event log and that WDOT can fail without an exit code.
   The family's mainline (landing zone, avd-assess) pins v1.1. The kit should follow the family
   pin, and the landing zone should check its own build for that failure mode (a separate
   follow-up there).
8. **Sandbox runs:** each phase's live test needs a written estimate and the owner's exact
   `go batch <id> $<total>`. Fine to queue one batch per phase?

## 7. Phased order

Each phase is one PR (or a small set) with `terraform test`, tflint and gitleaks green before any
sandbox run.

0. **Decide and set up.** Owner answers questions 1 to 3. Prior-art check, AVM and accelerator
   review, name check. Set up the sibling repo (LICENSE, NOTICE with nerdio-hcl attribution),
   guardrails, KB skeleton; family.yaml rows and lanes follow when it goes public. Record 0025 as accepted.
1. **Engine core, offline.** Parameter schema, `init`, foundation, network, FSLogix storage, Key
   Vault, control plane (host pool, desktop app group, workspace, assignments), session hosts
   from a marketplace image, AVD Insights. `terraform test` with mocked providers only.
2. **Gated pipeline and readiness.** Deploy pipeline (plan and apply identities, reviewer gate),
   readiness engine with the Nerdio checks removed and the AVD ones added, verify phase checks.
   First sandbox run after an estimate and the owner's go.
3. **Day 2.** Scaling plans, auto shutdown and budget, host rotation, Packer image stage and
   gallery pin, personal pools with Start VM on Connect.
4. **Chat front door.** The assistant over the same schema and pipeline, handover runbook.
5. **Later.** AD DS and Entra DS join, hardening (private endpoints, self-hosted runner), session
   host configuration opt-in, RemoteApp groups, Azure Government.
