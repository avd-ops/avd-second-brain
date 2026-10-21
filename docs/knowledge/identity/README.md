---
title: "Identity and Entra"
summary: "Entra ID joined hosts, Entra Kerberos, Microsoft Graph sign-in for operators, and agent identities"
topic: identity
status: partial
last_reviewed: 2026-10-21
---

# Identity and Entra

Identity for AVD on Entra ID: Entra-joined session hosts, Entra Kerberos for profile storage, Microsoft Graph sign-in for the people and scripts that operate an estate, and the identities AI agents run under. Each rule below came from a real run and links where the detail lives. Entra Kerberos on the profile share is on the [FSLogix page](../fslogix/README.md).

## Assessing identity

- avd-assess maps the identity pillar: the review checklist's identity items, the Learn pages they rest on, and which parts a Reader-only run sees (join type, the host pool's single sign-on property, the profile share's identity source, role assignment counts), which need a directory read (Conditional Access, per-user MFA, the tenant's single sign-on setting, LAPS), and which only the operator knows ([gap:identity-scope](https://github.com/avd-ops/avd-assess/blob/main/gaps/identity-scope.md)). The directory read doesn't exist yet; its rows stay `unknown` unless the operator answers the intake question.
- Learn disagrees with itself on FSLogix for cloud-only users: the AVD prerequisites and Entra joined host pages still ask for hybrid accounts, the Azure Files and FSLogix pages don't, and the landing zone's run shows cloud-only users work ([observation](https://github.com/avd-ops/avd-assess/blob/main/observations/fslogix-cloud-only-users-work.yaml); [upstream ask](../microsoft/upstream-contributions.md#docs-and-packaging)).
- Conditional Access for AVD is two aligned policies, the AVD app and Windows Cloud Login, with the feed app never under MFA and per-user MFA off; per-user MFA alongside Conditional Access breaks sign-in to Entra joined hosts.

## Microsoft Graph sign-in for operators

- Operators sign in to Microsoft Graph once per session through one operator app with one set of delegated scopes ([avd-landing-zone decision 0016](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/decisions/0016-graph-operator-app.md)). An explicit client ID beats relying on a sign-in that happens to have the scopes ([lesson 0030](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0030-graph-unlisted-delegated-scope.md)).
- In Cloud Shell, never pipe `Connect-MgGraph` to `Out-Null`: the device code goes to the output stream. Check a sign-in with a real request before trusting it, and identify the Azure user with `Get-AzADUser -SignedIn` ([lesson 0007](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0007-graph-sign-in.md)).
- Microsoft Graph's service principal doesn't list every delegated permission it issues in `oauth2PermissionScopes`. Grant scopes by value ([lesson 0030](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0030-graph-unlisted-delegated-scope.md)).

## Cleaning up identities

- Delete the hosts' Entra ID and Intune device records before the Azure resources whose names they come from, so a failed cleanup can run again ([lesson 0029](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0029-device-cleanup-rerun.md)).

## Agent identities

- avd-swarm gives each agent its own identity and keeps every write behind a person's approval ([identities](https://github.com/avd-ops/avd-swarm/blob/main/docs/identities.md)). *Unverified:* not yet run end to end; see the [agents page](../agents/README.md).
