---
title: "Upstream asks for Microsoft"
summary: "Gaps, API asks and doc fixes we could raise with Microsoft, with evidence"
topic: microsoft
status: verified
last_reviewed: 2026-10-18
---

# Upstream asks for Microsoft

Things only Microsoft can change: gaps in AVD, Azure Files and FSLogix, Entra, Image Builder or Foundry, and docs fixes. The
tables are generated from [upstream.yaml](upstream.yaml). Nothing is raised upstream without the
maintainer's go-ahead, and every entry carries its evidence. An entry for another upstream, such as
a community tool, goes here too and names its target in `note` until the family format has a
`target` field ([decision 0011](../decisions/0011-family-format-upstream-sources.md)).

To raise one: draft its text in [drafts/](drafts/README.md), get the draft reviewed in a pull
request, then a person files it under their own account and sets `status: raised` and `link`.

## Feature gaps

<!-- BEGIN GENERATED: feature_gaps (edit the YAML, then run scripts/kb/build.py) -->
| Gap | Evidence | Why it matters | Status |
|---|---|---|---|
| AVM nat-gateway: public IPs default to zones 1-3 even when the NAT Gateway is non-zonal | https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0001-nat-gateway-pip-zones.md | Deploying to a region without availability zones fails with LocationNotSupportAvailabilityZones unless the caller overrides a nested default it can't see from the parent module | candidate (Check the current module version in Azure/bicep-registry-modules before raising) |
<!-- END GENERATED: feature_gaps -->

## API asks

<!-- BEGIN GENERATED: api_asks (edit the YAML, then run scripts/kb/build.py) -->
| Ask | Evidence | Why it matters | Status |
|---|---|---|---|
| Microsoft Graph's service principal doesn't list every delegated permission it issues | https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0030-graph-unlisted-delegated-scope.md | Tooling that looks scopes up in oauth2PermissionScopes reports a real delegated permission as missing | candidate |
<!-- END GENERATED: api_asks -->

## Docs and packaging

<!-- BEGIN GENERATED: docs_packaging (edit the YAML, then run scripts/kb/build.py) -->
| Item | Evidence | Suggested fix | Status |
|---|---|---|---|
| Azure Files: say that Entra Kerberos sessions are denied when AES-256-GCM is the only SMB channel encryption | https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0028-smb-channel-encryption-entra-kerberos.md | A note in the Entra Kerberos and SMB security settings pages | candidate (Check the current docs before raising) |
| AVD prerequisites: FSLogix on Entra joined hosts no longer needs hybrid users | https://github.com/avd-ops/avd-assess/blob/main/observations/fslogix-cloud-only-users-work.yaml | Say on both AVD pages that cloud-only and external identities work in the Azure public cloud, and link the Entra Kerberos page | candidate (Pages checked 2026-10-21 (avd-assess references avd-prerequisites, avd-entra-joined-hosts); check again before raising) |
<!-- END GENERATED: docs_packaging -->
