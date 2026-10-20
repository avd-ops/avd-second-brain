# Changelog

All notable changes, in the format of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). New lines come from the `Changelog:` line in each merged pull request's body (`scripts/Update-BrainDocs.ps1 -PullRequestPath`); earlier history is in the merged pull requests.

## Unreleased

### Added

- Assessment contracts C19 to C21 (docs/assess-spec.md): `avd-intake/v1`, `avd-assess-index/v1`, `avd-assess-method/v1` and `avd-assessment/v1` schemas with examples, `Test-AssessMethod`, `Get-AssessScore` and `Test-AssessmentReport`. The fact register's five `intake.*` facts are built, at their C19 paths (`intake.existingHub` is now an enum).
- Docs consistency, phase D0 (docs/docs-spec.md): `scripts/Test-DocConsistency.ps1` with checks D1 to D11, the generator `scripts/Update-BrainDocs.ps1`, reference pages, the handbook in `wiki/` with its agent index, `Find-BrainKnowledge.ps1 -Wiki`, the C13 schema, the shared `docs-check.yml` workflow and the nightly `docs-sweep.yml`.
