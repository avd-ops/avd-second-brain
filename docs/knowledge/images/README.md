---
title: "Golden images"
summary: "Golden images for session hosts: Azure Image Builder, the Windows Desktop Optimization Tool, the gallery and promotion"
topic: images
status: partial
last_reviewed: 2026-10-20
---

# Golden images

Building and rotating golden images for AVD session hosts with Azure Image Builder, the Windows Desktop Optimization Tool and an Azure Compute Gallery, promoted by a person and rotated blue/green. Packer-based images for Nerdio Manager belong to the [Nerdio HCL kit](https://github.com/nickprignano/nerdio-hcl/tree/main/docs/knowledge).

## Pipeline

- avd-landing-zone builds one generic golden image with Azure Image Builder ([avd-landing-zone decision 0013](https://github.com/nickprignano/avd-landing-zone/blob/master/build/decisions/0013-image-pipeline.md)). *Unverified:* no lesson yet records a real build.
- Ignore build output where it's written, never `*.json` across the repo: the pipeline's data files are loaded at compile time and must be committed ([lesson 0027](https://github.com/nickprignano/avd-landing-zone/blob/master/build/lessons/0027-gitignore-json-data-files.md)).

## Optimization (WDOT)

- The [Windows Desktop Optimization Tool](https://github.com/The-Virtual-Desktop-Team/Windows-Desktop-Optimization-Tool) is the family's one image optimization tool. The landing zone runs release v1.1 by commit, hash-checked file by file, with a reviewed profile ([scripts/image/wdot](https://github.com/nickprignano/avd-landing-zone/tree/master/scripts/image/wdot)); avd-assess pins the same commit as its reference ([references/wdot.yaml](https://github.com/nickprignano/avd-assess/blob/main/references/wdot.yaml)).
- WDOT's `LICENSE` is MIT, but its README and `EULA.txt` describe Microsoft's sample code terms (illustration only, as is, test before production), and a non-interactive run passes `-AcceptEULA`. Operators accept those terms when they run the image pipeline.
- What WDOT did inside the guest isn't visible from the control plane. The landing zone's build tags each gallery image version `avdlz-wdot` (release@commit) and `avdlz-wdot-profile` (profile SHA-256), so a Reader can see the pin an image claims; avd-current-state's validator reports it, and an untagged image is unknown, not failed ([avd-assess observation](https://github.com/nickprignano/avd-assess/blob/main/observations/wdot-pin-on-image-version.yaml)).

## Rotation (blue/green)

- The landing zone rotates hosts blue/green inside one host pool: a new host generation (`a`/`b`) from a promoted gallery version, then drain, wait and remove the old one, resumable through a host pool tag ([image pipeline spec, section 6.5](https://github.com/nickprignano/avd-landing-zone/blob/master/build/specs/image-pipeline-spec.md)). Built offline as `Invoke-AvdHostRotation.ps1` ([avd-landing-zone #81](https://github.com/nickprignano/avd-landing-zone/pull/81), draft). *Unverified:* not run against a real tenant.
- Microsoft's native alternative, [session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update), now lists Microsoft Entra as a join option in the session host configuration ([configure session host update](https://learn.microsoft.com/azure/virtual-desktop/session-host-update-configure)), which was decision 0013's main reason for a custom script. The other limits stand (read 2026-10-20): the management approach is fixed when a host pool is created, so an existing pool can't adopt it ([host pool management approaches](https://learn.microsoft.com/azure/virtual-desktop/host-pool-management-approaches)); autoscale must be disabled for the whole update; hosts are replaced in place in batches, so capacity drops rather than surges; the gallery must be in the host pool's subscription; the Azure Monitor agent isn't reinstalled. Moving to it means a new pool and a shift of application group assignments.
- The host pool's tags (`avdlz-image`, `avdlz-generation`) are the one record of what its hosts run. A routine deployment must keep them: Azure rejects a new image on an existing VM, and a new generation deploys a second set of hosts. So `deploy.sh` reads them before every deployment, passes them back, and refuses a different image or generation, or any deployment while a rotation is in progress, except from the rotation script ([avd-landing-zone #81](https://github.com/nickprignano/avd-landing-zone/pull/81), draft). *Unverified:* offline only.
- A resumable script that keeps its state in tags must read the tags again before each step, not once at the start: the first offline run of the rotation deployed the old image, because the step that started the rotation wrote the target to a tag and the deploy step then read a stale copy (avd-landing-zone #81, `Rotation.Scenario.ps1`).
- A rotation must deploy the new hosts with the settings the landing zone was last deployed with, not the parameter file's defaults: the rotation reads them from the last succeeded subscription deployment record (`properties.parameters`) and passes them to `deploy.sh` as flags.
- A pool whose hosts run different images is mid-rotation or has drifted (marketplace `latest` resolves to a new build each time a host is added). avd-current-state's validator reports image consistency per pool ([avd-current-state #17](https://github.com/nickprignano/avd-current-state/pull/17), draft).
- Multi-region: Microsoft's multiregion guide replicates the gallery image to both regions so both pools deploy the same version ([multiregion BCDR](https://learn.microsoft.com/azure/architecture/example-scenario/azure-virtual-desktop/azure-virtual-desktop-multi-region-bcdr)); a second-region pool should rotate after the primary, from the same version.
