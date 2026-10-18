---
title: "Golden images"
summary: "Golden images for session hosts: Azure Image Builder, the Windows Desktop Optimization Tool, the gallery and promotion"
topic: images
status: plan
last_reviewed: 2026-10-18
---

# Golden images

Building and rotating golden images for AVD session hosts with Azure Image Builder, the Windows Desktop Optimization Tool and an Azure Compute Gallery, promoted by a person and rotated blue/green. Nothing is written here yet; what's known today is listed below. Packer-based images for Nerdio Manager belong to the [Nerdio HCL kit](https://github.com/nickprignano/nerdio-hcl/tree/main/docs/knowledge).

## Where it lives today

- [A generic golden image built by Azure Image Builder](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0013-image-pipeline.md) (avd-landing-zone decision 0013)
- [A repo-wide `*.json` ignore rule kept the image pipeline's data files out of git](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0027-gitignore-json-data-files.md) (avd-landing-zone lesson 0027)
