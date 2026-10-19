---
title: "Golden images"
summary: "Golden images for session hosts: Azure Image Builder, the Windows Desktop Optimization Tool, the gallery and promotion"
topic: images
status: partial
last_reviewed: 2026-10-18
---

# Golden images

Building and rotating golden images for AVD session hosts with Azure Image Builder, the Windows Desktop Optimization Tool and an Azure Compute Gallery, promoted by a person and rotated blue/green. Packer-based images for Nerdio Manager belong to the [Nerdio HCL kit](https://github.com/nickprignano/nerdio-hcl/tree/main/docs/knowledge).

## Pipeline

- avd-landing-zone builds one generic golden image with Azure Image Builder ([avd-landing-zone decision 0013](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0013-image-pipeline.md)). *Unverified:* no lesson yet records a real build.
- Ignore build output where it's written, never `*.json` across the repo: the pipeline's data files are loaded at compile time and must be committed ([lesson 0027](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0027-gitignore-json-data-files.md)).
