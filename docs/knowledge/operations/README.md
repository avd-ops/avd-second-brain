---
title: "Operating an estate"
summary: "Day-2 operations: detections, playbooks, episodes, and the handoff to avd-swarm for anything that changes an estate"
topic: operations
status: partial
last_reviewed: 2026-10-21
---

# Operating an estate

Running an AVD estate after deployment: detections and signals, playbooks as tested procedure, episodes that become lessons, and the handoff to avd-swarm, which makes every change through a person's approval and one kill switch ([decision 0003](../decisions/0003-brain-thinks-swarm-acts.md)). The design is in the [operations spec](../../operations-spec.md) and its [red team](../../operations-redteam.md); avd-swarm's [governance](https://github.com/avd-ops/avd-swarm/blob/main/docs/governance.md) covers the gate, the observers and the kill switch. *Unverified:* the detections, playbooks and the swarm handoff are designed, not built.

The rules below came from real runs of [avd-landing-zone](https://github.com/avd-ops/avd-landing-zone); the exact errors are in [known errors](../troubleshooting/README.md).

## Diagnosing

- When a real run fails in an external API, first report everything the API returned. Change behavior only once the evidence names the cause ([lesson 0012](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0012-diagnose-first.md)).

## Redeploying

- Anything a deployment changes inside a VM (extensions, run commands) needs the VM running. With power management on, assume hosts are stopped: start them for the change, then put them back ([lesson 0026](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0026-redeploy-stopped-hosts.md)).

## Tearing down and deploying again

- Deleting a resource group only soft-deletes some of what's in it. A Log Analytics workspace comes back when one with the same name is created; delete it permanently or let the next deployment handle the recovered state ([lesson 0023](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0023-log-analytics-soft-delete.md)).
- A purge-protected Key Vault is recovered, not waited out, and recovery needs its original resource group. A safe, reversible remedy like this belongs in a `-Fix` action, not in advice ([lesson 0022](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0022-key-vault-recovery.md)).
- Delete a cleanup step's inputs only after the step that needs them has succeeded ([lesson 0029](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0029-device-cleanup-rerun.md)).

## Tracking risks, actions and decisions

*Proposed:* the brain keeps each estate's RAID log and action tracker beside its lifecycle record ([raid spec](../../raid-spec.md), [decision 0022](../decisions/0022-the-brain-keeps-the-raid-log.md)). Checked 2026-10-20:

- CAF Govern's risk register gives the fields to use as they are: ID, status, category, description, probability, impact, priority (impact weighted higher), strategy (mitigate, accept, avoid, transfer), enforcement, owner and closure date, reviewed on a schedule and after events ([Assess cloud risks](https://learn.microsoft.com/azure/cloud-adoption-framework/govern/assess-cloud-risks)).
- Azure Advisor separates a recommendation a person *marked* completed from one the system *verified*, and a verified one can't be reopened; postponed items come back on their own ([Manage recommendation state](https://learn.microsoft.com/azure/advisor/advisor-azure-state-management)). The tracker copies that split for actions.
- Well-Architected advises putting review recommendations into the workload's backlog with an owner and tracking them to resolution; WARP's DevOps scripts import them into Azure DevOps or GitHub ([implementing recommendations](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations)). An estate's items stay in its private vault, so a ticket system can only be a view.
- No widely used open schema for RAID logs was found.

## Checking compliance after a change

- Defender for Cloud's free Foundational CSPM gives the secure score and the Microsoft cloud security benchmark. Other regulatory standards, such as CIS or NIST, need the paid Defender CSPM plan, so a gate built on them needs a cost estimate first ([CSPM plans](https://learn.microsoft.com/azure/defender-for-cloud/concept-cloud-security-posture-management), [support matrix](https://learn.microsoft.com/azure/defender-for-cloud/support-matrix-defender-for-cloud#cloud-support)).
- Don't wait on Defender's assessments to verify a change: they lag. Azure Policy's standard compliance scan runs every 24 hours and changed resources show up in about 15 minutes; an on-demand evaluation scan of the resource group (`Start-AzPolicyComplianceScan`, or a POST to `policyStates/latest/triggerEvaluation`) is asynchronous and slow, so poll its location URI until it returns 200 ([evaluation triggers](https://learn.microsoft.com/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers), [troubleshooting](https://learn.microsoft.com/azure/governance/policy/troubleshoot/general#general-errors)). avd-swarm's compliance gate verifies plans this way ([governance section 2.5](https://github.com/avd-ops/avd-swarm/blob/main/docs/governance.md)). *Unverified:* not yet run against a real estate.

## Detecting drift

*Proposed:* a read-only drift check in avd-current-state compares the live estate with the landing zone parameter file and its last deployment, and fixes go through the landing zone's deploy workflow after a person approves ([drift spec](https://github.com/avd-ops/avd-current-state/blob/main/docs/drift-spec.md)). Checked against Microsoft Learn and the projects' own pages on 2026-10-21:

- Resource Graph's `resourcechanges` table keeps property-level changes for 14 days at no charge, with `changedBy`, `clientType` and `operation`. `changedBy` can be `System` (a platform change with no user action), and `changedBy`, `clientType` and `operation` can be `Unspecified`; `clientType` can also be `Unknown`. Create and delete records carry no property list, data-plane changes aren't recorded, and properties that arrive with a new API version don't show as changes ([get resource changes](https://learn.microsoft.com/azure/governance/resource-graph/changes/get-resource-changes), [change analysis](https://learn.microsoft.com/azure/governance/resource-graph/changes/resource-graph-changes)). A daily check stays inside the window; anything longer needs its own record. It records only types in the `resources`, `resourcecontainers` and `healthresources` tables, so session hosts, role assignments, locks and policy assignments need the Activity Log (90 days, free, readable as Reader) for who and when, with no property values.
- A what-if needs the same rights as a deployment: write on the resources and `Microsoft.Resources/deployments/*`. `--validation-level ProviderNoRbac` relaxes only the RBAC part of preflight. So a Reader-only audit identity can't run one ([what-if prerequisites](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-what-if#prerequisites)). What-if also doesn't evaluate `reference()`, secure parameters, nondeterministic functions or template links, and over Bicep modules it short-circuits ([Azure Verified Modules known issues](https://azure.github.io/Azure-Verified-Modules/help-support/known-issues/#bicep)).
- Deployment stacks' what-if filters noise against a baseline recorded at the stack's last create or update, only for stacks created or updated on or after 2026-08-13, and it still reports new differences such as a portal edit or a reordered list. A stack what-if result is a resource of its own (`deploymentStacksWhatIfResults/write`), kept 1 to 3 hours ([stack what-if](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deployment-stacks-what-if), [noise reduction](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deployment-stacks-what-if-noise-reduction)).
- Machine Configuration has three modes: `Audit` reports only, `ApplyAndMonitor` applies once and reports drift, `ApplyAndAutoCorrect` fixes drift at the next evaluation and leaves no record that it did. The agent rechecks every 15 minutes and results land in Resource Graph ([remediation options](https://learn.microsoft.com/azure/governance/machine-configuration/concepts/remediation-options), [prerequisites](https://learn.microsoft.com/azure/governance/machine-configuration/overview/02-setup-prerequisites)). Azure Automation State Configuration and Automanage machine best practices both retire on 2027-09-30.
- Microsoft Entra Tenant Governance's configuration management (the Graph Tenant Configuration Management APIs, GA) monitors a JSON baseline of Entra, Intune, Exchange, Teams and Security and Compliance resources every six hours, fixed. Limits: 30 monitors, 200 resources per baseline, 800 resource checks a day, and updating a monitor's baseline deletes its results and drifts. It needs Microsoft Entra ID P1 or above; Free has no configuration monitoring ([licensing](https://learn.microsoft.com/entra/id-governance/tenant-governance/licensing), [API limits](https://learn.microsoft.com/graph/api/resources/unified-tenant-configuration-management-api-overview?view=graph-rest-1.0#api-limits), [configuration management](https://learn.microsoft.com/entra/id-governance/tenant-governance/configuration-management)).
- Open source checked: PSRule for Azure has one AVD rule (AZR-000437) and its last stable release is 1.47.0 from January 2026; Steampipe's Azure plugin has no AVD tables; Prowler (Apache-2.0) and ScoutSuite (GPL-2.0, last release May 2024) check posture, not AVD; InSpec 6 needs a license key for commercial use. None compares an AVD estate with a declared state.

## Learning from real runs

What a real run did is worth keeping, and most of it is already kept by Azure. A run recorder and resume point for the landing zone is *proposed*, not built: [run recorder spec](https://github.com/avd-ops/avd-landing-zone/blob/master/build/specs/run-recorder-spec.md).

- Read the Activity Log after a run instead of exporting it: Azure keeps control-plane writes for 90 days at no charge, so a diagnostic setting is only needed for longer retention ([Activity log in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/fundamentals/activity-log)).
- Don't put a locked immutability policy on a sandbox's log store. A locked time-based retention policy can't be shortened or removed, and the storage account can't be deleted while a container holds a blob under it, so teardown fails until the policy expires. Unlocked policies don't protect from deletion ([container-level WORM policies](https://learn.microsoft.com/azure/storage/blobs/immutable-container-level-worm-policies)).
- Cloud Shell keeps files only in `clouddrive` and the `$HOME` image, and only when a storage account is mounted; an ephemeral session keeps nothing, and any session ends after 20 minutes without input. Where a run stands has to come from Azure (deployment history, resource groups), not from the shell ([Cloud Shell FAQ](https://learn.microsoft.com/azure/cloud-shell/faq-troubleshooting)). *Unverified in a real run:* that a subscription-scope deployment keeps running after the session ends.
- Graph activity logs need Entra ID P1 or P2; Entra audit and sign-in logs are available on Free ([Microsoft Entra licensing](https://learn.microsoft.com/entra/fundamentals/licensing#microsoft-entra-monitoring-and-health)).

## Backup and disaster recovery

Checked against Microsoft Learn on 2026-10-20; the landing zone's design for it is the [recovery spec](https://github.com/avd-ops/avd-landing-zone/blob/master/build/specs/recovery-spec.md) (*unverified:* the recovery region setting and preflight checks are built, nothing has run against Azure). Microsoft's implementation guide is [Multiregion BCDR for Azure Virtual Desktop](https://learn.microsoft.com/azure/architecture/example-scenario/azure-virtual-desktop/azure-virtual-desktop-multi-region-bcdr).

- AVD has no disaster recovery features of its own. Microsoft fails over the control plane; session hosts, profiles, apps, user data and identities are the operator's ([AVD BCDR concepts](https://learn.microsoft.com/azure/virtual-desktop/disaster-recovery-concepts)).
- Microsoft's RPO and RTO figures are estimates to validate by testing: active-passive pooled with FSLogix Cloud Cache is seconds to minutes of RPO and 15 to 60 minutes of RTO. Availability zones are high availability, not disaster recovery.
- Deallocated standby hosts, a fresh deployment and Site Recovery don't guarantee capacity in the recovery region; only running resources or on-demand capacity reservations do, and Azure reservations don't.
- Never use Site Recovery test failover on session hosts: the duplicate VM registers with the control plane and conflicts with the original. Test with a separate test group assigned to the standby pool instead.
- A session host that stays deallocated must start for a few hours at least every 90 days to refresh its control plane token.
- A Key Vault backup restores only into a vault in the same subscription and geography, so it can't carry secrets to a new subscription. Regenerate secrets on recovery instead of copying them.
- Only some Entra objects are soft deleted for 30 days (users, Microsoft 365 and cloud security groups, app registrations, service principals, administrative units, Conditional Access policies, named locations); the rest are hard deleted. Keep Conditional Access and similar configuration as JSON in git and redeploy the last known-good version ([Recover from deletions](https://learn.microsoft.com/entra/architecture/recover-from-deletions)).

## Moving a repo to another GitHub owner

Learned moving the public family repos into the avd-ops organization on 2026-10-21 ([GitHub's transfer docs](https://docs.github.com/en/repositories/creating-and-managing-repositories/transferring-a-repository) and the runs that day).

- A transfer keeps issues, PRs, secrets and webhooks. Web links, `git clone`, `git push` and REST API calls to the old `owner/name` redirect, and so do `raw.githubusercontent.com` links. The redirect lasts until someone creates a repo at the old name, so never do that.
- GitHub Pages doesn't redirect. A project site moves from `<old-owner>.github.io/<repo>/` to `<new-owner>.github.io/<repo>/`, so every URL a script prints or a talk showed breaks. A user site (`<old-owner>.github.io` repo) whose `404.html` forwards the old paths covers them.
- A reusable workflow's `uses: <owner>/<repo>/...@<sha>` doesn't follow the redirect. Callers fail with "workflow was not found" until the line names the new owner, so move the called repo first and fix its callers right away.
- GitHub's OIDC subject changes to `repo:<new-owner>/<repo>:...`. Add the federated credential for the new subject before the move (an app takes up to 20), then delete the old one after the first sign-in.
- Anything keyed to the repo owner breaks quietly once an organization owns the repo: owner-only workflow steps, the handoff and auto-merge checks (set the organization variable `HANDOFF_OWNER`).
- On a Free organization, private repos get no environments, environment variables or secrets, deployment branch rules or required reviewers, so a private repo that depends on them stays with an owner whose plan has them (GitHub Pro or Team).
