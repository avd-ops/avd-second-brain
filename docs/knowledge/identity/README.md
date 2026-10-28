---
title: "Identity and Entra"
summary: "Entra ID joined hosts, Entra Kerberos, Microsoft Graph sign-in for operators, unattended read identities, and agent identities"
topic: identity
status: partial
last_reviewed: 2026-10-28
---

# Identity and Entra

Identity for AVD on Entra ID: Entra-joined session hosts, Entra Kerberos for profile storage, Microsoft Graph sign-in for the people and scripts that operate an estate, and the identities AI agents run under. Each rule below came from a real run and links where the detail lives. Entra Kerberos on the profile share is on the [FSLogix page](../fslogix/README.md).

## Assessing identity

- avd-assess maps the identity pillar: the review checklist's identity items, the Learn pages they rest on, and which parts a Reader-only run sees (join type, the host pool's single sign-on property, the profile share's identity source, role assignment counts), which need a directory read (Conditional Access, per-user MFA, the tenant's single sign-on setting, LAPS), and which only the operator knows ([gap:identity-scope](https://github.com/avd-ops/avd-assess/blob/main/gaps/identity-scope.md)). The directory read doesn't exist yet; its rows stay `unknown` unless the operator answers the intake question.
- Learn disagrees with itself on FSLogix for cloud-only users: the AVD prerequisites and Entra joined host pages still ask for hybrid accounts, the Azure Files and FSLogix pages don't, and the landing zone's run shows cloud-only users work ([observation](https://github.com/avd-ops/avd-assess/blob/main/observations/fslogix-cloud-only-users-work.yaml); [upstream ask](../microsoft/upstream-contributions.md#docs-and-packaging)).
- Conditional Access for AVD is two aligned policies, the AVD app and Windows Cloud Login, with the feed app never under MFA and per-user MFA off; per-user MFA alongside Conditional Access breaks sign-in to Entra joined hosts.
- Entra enforces a Content Security Policy on browser sign-in at `login.microsoftonline.com` from mid-to-late October 2026: only scripts from Microsoft's own domains run there, so a browser extension or tool that injects script into the sign-in page (some security, monitoring and password tools) stops working on it, the AVD web client's sign-in included. Sign-in itself still works, and MSAL and API flows aren't affected. Check with the browser's developer console during a sign-in before blaming AVD ([Entra CSP](https://learn.microsoft.com/entra/identity-platform/content-security-policy), checked 2026-10-28; from digest #15).

## Microsoft Graph sign-in for operators

- Operators sign in to Microsoft Graph once per session through one operator app with one set of delegated scopes ([avd-landing-zone decision 0016](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/decisions/0016-graph-operator-app.md)). An explicit client ID beats relying on a sign-in that happens to have the scopes ([lesson 0030](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0030-graph-unlisted-delegated-scope.md)).
- In Cloud Shell, never pipe `Connect-MgGraph` to `Out-Null`: the device code goes to the output stream. Check a sign-in with a real request before trusting it, and identify the Azure user with `Get-AzADUser -SignedIn` ([lesson 0007](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0007-graph-sign-in.md)).
- Microsoft Graph's service principal doesn't list every delegated permission it issues in `oauth2PermissionScopes`. Grant scopes by value ([lesson 0030](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0030-graph-unlisted-delegated-scope.md)).

## Unattended reads

- An app registration saves a person no sign-ins in Az PowerShell: Cloud Shell is already signed in, Az saves the context elsewhere, and `Connect-AzAccount -ApplicationId` exists only in the service principal parameter sets. What an app gives is runs with nobody signed in, and least privilege ([avd-current-state reader guide](https://github.com/avd-ops/avd-current-state/blob/main/docs/reader-identity.md)).
- One app can't carry per-tool permission sets: Entra grants rights to the app, so a shared app holds the union of its callers' rights. A family-wide identity is safe for reads only; writes keep their own identities.
- Bind a GitHub Actions federated credential to GitHub's immutable subject (`repo:<owner>@<owner id>/<repo>@<repo id>:environment:<env>`). A name-only subject can be claimed by whoever re-registers a deleted or renamed repo's name. GitHub uses the immutable form by default only for repos created, renamed or transferred from 2026-07-15; older repos opt in ([Learn](https://learn.microsoft.com/entra/workload-id/workload-identities-github-immutable-subjects)).
- "No secret" needs the tenant, not a script: app owners and Application or Cloud Application Administrators can add credentials. An app management policy blocks passwords and symmetric keys (a free Workload ID feature, one custom policy per app); no restriction blocks a certificate, so a check has to catch one ([Learn](https://learn.microsoft.com/entra/identity/enterprise-apps/configure-app-management-policies)).
- An app-only identity can't read its own app object without a Graph permission. With Reader only on a resource group, a workspace or a container, it can't list role assignments at subscription scope either (403); Resource Graph's `authorizationresources` shows its assignments wherever it can read.
- Reader is control plane only but not harmless: deployment history with non-secure parameters and outputs, unencrypted Automation variables, and Resource Graph over the whole scope. Reading a host pool's registration token is an action (`retrieveRegistrationToken`), so Reader gets 403 and a check must not read that as "no token".
- A Role Based Access Control Administrator limited to certain roles needs two conditions, one on `roleAssignments/write` (`@Request`) and one on `roleAssignments/delete` (`@Resource`) ([Learn](https://learn.microsoft.com/azure/role-based-access-control/delegate-role-assignments-examples#example-constrain-roles)).

## Cleaning up identities

- Delete the hosts' Entra ID and Intune device records before the Azure resources whose names they come from, so a failed cleanup can run again ([lesson 0029](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0029-device-cleanup-rerun.md)).

## Agent identities

- avd-swarm gives each agent its own identity and keeps every write behind a person's approval ([identities](https://github.com/avd-ops/avd-swarm/blob/main/docs/identities.md)). *Unverified:* not yet run end to end; see the [agents page](../agents/README.md).
