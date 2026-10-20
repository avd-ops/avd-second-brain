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
