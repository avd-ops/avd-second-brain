# Changelog

All notable changes, in the format of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). New lines come from the `Changelog:` line in each merged pull request's body (`scripts/Update-BrainDocs.ps1 -PullRequestPath`); earlier history is in the merged pull requests.

## Unreleased

### Added

- Azure US Government and Microsoft 365 GCC High (`usgov`) contract and KB support: registered C26 (`avd-cloud-environments/v1`, `contracts/cloud-environments.json` and `contracts/schemas/cloud-environments.schema.json`), added `cloud` (`commercial` | `usgov`) and `complianceProfile` (`standard` | `itar-cui`) across C9, C10, C11, C14, C18, C19, and C21, bumped `contracts/FOUNDATION-PINS.json` to `avd-assess` v10, and documented sovereign workload placement and lessons learned in `docs/knowledge/landing-zone/usgov-and-gcc-high.md`.
- Five-plane foundation contract pin bump (`avd-assess` v5): C11 `planesCollected` and `/entra/*`, `/intune/*`, `/m365/*`, `/powerPlatform/*` paths; C15 231 facts across five control planes; C19 `m365PlaneScope` and `powerPlatformPlaneScope`; C20 `plane` on checks and remediation hints; C21 `planes` score/coverage rollup and `not-applicable` outcome; C24 `remediation-plan.schema.json` with required `plane`.
- Fact register: `c11.storage.kind` and `c11.storage.sku` (already in C11), for avd-assess's first storage checks; `avd-assess-method/v1` collection rows may name the ARM resource type.
- Assessment contracts C19 to C21 (docs/assess-spec.md): `avd-intake/v1`, `avd-assess-index/v1`, `avd-assess-method/v1` and `avd-assessment/v1` schemas with examples, `Test-AssessMethod`, `Get-AssessScore` and `Test-AssessmentReport`. The fact register's five `intake.*` facts are built, at their C19 paths (`intake.existingHub` is now an enum).
- Docs consistency, phase D0 (docs/docs-spec.md): `scripts/Test-DocConsistency.ps1` with checks D1 to D11, the generator `scripts/Update-BrainDocs.ps1`, reference pages, the handbook in `wiki/` with its agent index, `Find-BrainKnowledge.ps1 -Wiki`, the C13 schema, the shared `docs-check.yml` workflow and the nightly `docs-sweep.yml`.
