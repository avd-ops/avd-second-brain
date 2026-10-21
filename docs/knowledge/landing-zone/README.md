---
title: "Landing zone"
summary: "Bicep, networking, policy, quotas and resource providers for an AVD landing zone, and running it all from Cloud Shell"
topic: landing-zone
status: verified
last_reviewed: 2026-10-20
---

# Landing zone

How an AVD landing zone gets built and kept healthy with Azure-native tooling: Bicep and Azure Verified Modules, networking and private endpoints, vCPU quota, resource providers, and running every step from Azure Cloud Shell. Each rule below came out of a real run of [avd-landing-zone](https://github.com/nickprignano/avd-landing-zone) and links the lesson that holds the detail ([decision 0008](../decisions/0008-learned-knowledge-stays-where-it-happened.md)). The exact errors are in [known errors](../troubleshooting/README.md).

The landing zone's scope is Entra ID only, greenfield and private by default ([avd-landing-zone decision 0001](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0001-cloud-native-scope.md)).

## Quota and regions

- New subscriptions start with 0 vCPU quota for most VM families, separate from the regional limit. Check family and regional quota per region before deploying, and request small increases through `Microsoft.Quota` ([lesson 0013](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0013-vcpu-quota.md)).
- A quota check after deployment must not count the landing zone's own hosts twice: they are already in `used` ([lesson 0024](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0024-quota-counts-deployed-hosts.md)).
- Test in a region without availability zones (North Central US) as well as a zonal one. ARM leaves empty properties out, so a zone list can be missing rather than empty ([lesson 0001](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0001-nat-gateway-pip-zones.md), [lesson 0021](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0021-arm-omits-empty-properties.md)).
- Latency measured from Cloud Shell says nothing about users: measure from where they are, against endpoints verified to be regional ([lesson 0003](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0003-region-latency.md)).

## Resource providers

- `Get-AzResourceProvider -ProviderNamespace` returns one object per region. Read the provider through ARM REST when the cmdlet reshapes data ([lesson 0005](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0005-provider-per-region.md)).
- Register through the ARM `register` API, which returns at once, and show progress while waiting. EncryptionAtHost takes effect only after Microsoft.Compute is registered again ([lesson 0006](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0006-provider-registration.md)).

## Bicep and Azure Verified Modules

- An AVM module's nested defaults (zones, SKUs, locations) apply when the parent doesn't set them. Compile the template and walk the nested deployments before adopting a module ([lesson 0001](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0001-nat-gateway-pip-zones.md)).
- Don't assume where a module puts child resources. Private endpoints land in their target's resource group, so look them up by target ID ([lesson 0010](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0010-private-endpoint-rg.md)).
- `readEnvironmentVariable` returns an empty string, not its default, when the variable is set but empty. Guard optional variables with `empty(...)` ([lesson 0004](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0004-empty-env-var.md)).
- Keep `bicepconfig.json` strict and fix the cause rather than suppressing a rule ([lesson 0019](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0019-bicep-authoring.md)). For PSRule, suppress only with a reason and a narrow selector, and point it at an explicit Bicep binary ([lesson 0018](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0018-psrule.md)).
- Pin every CI tool (Bicep, PSRule and its Azure rules, PSScriptAnalyzer, Pester) and use the same versions wherever the same check runs, including PSRule's live Well-Architected review. A floating `latest` lets a release change a result with no commit, and the `microsoft/ps-rule` action always installs the newest rules module, so install pinned modules yourself ([ci.md](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/ci.md)).
- `bicep snapshot` gives an offline what-if: run it on a parameter file at the base commit, then `--mode validate` at the PR, and it prints the resource and property changes in what-if's format with placeholder IDs and no sign-in. `reference()` and `list*()` stay unevaluated, so a live what-if still has the last word. Checkov 3.3 added nothing for Bicep (parser errors on modern Bicep; on compiled ARM it sees only the top-level deployments), and ARM-TTK's useful tests already became the Bicep linter's defaults ([ci.md](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/ci.md)).
- Ignore build output where it's written, never `*.json` across the repo: a file Bicep loads at compile time must be committed ([lesson 0027](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0027-gitignore-json-data-files.md)).

## Scripts that run it

- Give operators self-contained command blocks for Cloud Shell, with no placeholders to fill in. Long operations must survive a disconnect and say how to check on them ([lesson 0015](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0015-cloud-shell-ergonomics.md)).
- Anything that can take more than a few seconds prints a line before it starts, and "fixed" means done, not started ([lesson 0006](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0006-provider-registration.md)).
- Every loop over remote calls ends on error, including non-terminating errors and empty results ([lesson 0008](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0008-non-terminating-loops.md)).
- Check each Az and Graph cmdlet call against its documented parameter sets, and keep mocks no more permissive than the real cmdlet ([lesson 0014](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0014-cmdlet-parameter-sets.md)). Emit items from functions instead of returning one array ([lesson 0009](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0009-array-unrolling.md)).
- Lint with the PSScriptAnalyzer version CI installs; use approved verbs and singular nouns ([lesson 0016](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0016-analyzer-version.md)). Offline tests provide every external tool they touch ([lesson 0020](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0020-hermetic-harness.md)).
- Never make a person remember a secret the platform can generate and reset, such as the break-glass password ([lesson 0002](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0002-break-glass-password.md)).

## Publishing the deployment portal

- Set the repo's **Settings > Pages > Source** to **GitHub Actions** before relying on a Pages workflow. While the source is a branch folder (`docs/`), GitHub's own branch build runs after the next push and replaces what the workflow deployed, so the portal vanishes. Switching the source doesn't republish anything: run the Pages workflow once after the switch ([GitHub Pages publishing sources](https://docs.github.com/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)).
- The portal is static and runs from any host that serves `site/portal` with `site/assets` beside it. To host a copy in a subscription instead of GitHub Pages, avd-landing-zone's `Publish-AvdPortal.ps1` offers Azure Static Web Apps or a storage static website ([avd-landing-zone decision 0017](https://github.com/nickprignano/avd-landing-zone/blob/master/build/decisions/0017-portal-hosting.md)). What decides between them:
  - Static Web Apps **Free** has only the preconfigured sign-in providers, and its Entra provider accepts any Microsoft account; GitHub sign-in is on too. "Signed in" is not access control: lock routes to a custom role given by invitation (25 invitations on Free). Single-tenant sign-in, IP restrictions and private endpoints need **Standard**, about $9 a month ([hosting plans](https://learn.microsoft.com/azure/static-web-apps/plans), [quotas](https://learn.microsoft.com/azure/static-web-apps/quotas), [authentication](https://learn.microsoft.com/azure/static-web-apps/authentication-authorization)).
  - Free has no SLA and 100 GB of bandwidth a month with no overage: past it, the site stops serving rather than costing money ([quotas](https://learn.microsoft.com/azure/static-web-apps/quotas)).
  - Static Web Apps resources are created only in centralus, eastus2, westus2, westeurope and eastasia. The landing zone's allowed-locations guardrail permits only its own region, so in any other region it denies the resource; check the policy before creating anything. *Unverified:* inferred from the policy and the region list, not yet seen in a real run.
  - Without a linked GitHub or Azure DevOps repo, the only way to upload is the Static Web Apps CLI (npm) with the site's deployment token, a long-lived secret. Pass it in `SWA_CLI_DEPLOYMENT_TOKEN`, never on a command line or in output, and reset it after the upload (`resetapikey`) ([CLI deploy](https://learn.microsoft.com/azure/static-web-apps/static-web-apps-cli-deploy), [token management](https://learn.microsoft.com/azure/static-web-apps/deployment-token-management)).
  - A storage static website needs neither npm nor a token: the operator's own sign-in uploads with Storage Blob Data Contributor, and turning the website on needs `blobServices/write` (Contributor has it). It has no sign-in at all (anonymous read of `$web`), though the storage firewall's IP and VNet rules do apply. Each blob is served with the Content-Type it was uploaded with, so set it on upload ([static website](https://learn.microsoft.com/azure/storage/blobs/storage-blob-static-website), [FAQ](https://learn.microsoft.com/azure/storage/blobs/static-website-hosting-faq)).
- Every GitHub Pages project site of one account shares the origin `<owner>.github.io`, and with it local storage, and Pages sends no CSP or framing headers. Give the portal its own origin with a custom domain, or host it where `staticwebapp.config.json` can send the headers. *Unverified:* from a design red team, not a real incident.
