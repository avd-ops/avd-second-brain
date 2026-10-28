# Lesson 0001: Cross-repo contract pin order and five-plane assessment invariants

## What happened

While expanding assessment and current-state collection across five control planes (`azure`, `entra`, `intune`, `m365`, `power-platform`) in `avd-assess`, `avd-second-brain`, `avd-current-state`, and `avd-ops`:

1. Updating `contracts/examples/assess/method.example.json` in `avd-assess` changed its SHA-256 hash, which caused `Test-AssessmentReport` in `avd-second-brain` (`tests/Connectors.Tests.ps1`) to fail when validating `contracts/examples/assess/assessment.example.json` against `contracts/examples/assess/method.example.json`.
2. Adding `c12.group.scaling.failedEvaluations` (`privacy: "count"`) to `contracts/fact-register.json` triggered the `c12.group.*` privacy assertion in `tests/Connectors.Tests.ps1`, which expected `group-behavior` for all `c12.group.*` facts except `c12.group.hostCount`.
3. Singleton plane objects (`/entra`, `/intune`, `/m365`, `/powerPlatform`) and nested subscription objects (`/subscriptions/*/powerPlatform`) did not carry their own `id` field, requiring ancestor pseudonym inheritance in subject evaluation.
4. Repository name regexes in cross-repo validators that matched only `[a-z-]+` rejected pinned evidence URLs for `avd-m365`.

## Cause

- Foundation contracts (C11, C15, C19–C24) are byte-pinned across `avd-assess`, `avd-second-brain`, `avd-current-state`, and `avd-ops`, and `contracts/examples/assess/assessment.example.json` embeds the exact SHA-256 of `contracts/examples/assess/method.example.json`.
- Earlier C11 checks targeted only array elements (`/subscriptions/*`, `/hostPools/*`, `/storageAccounts/*`) that each held an `id` property, whereas control-plane posture objects are singletons under the estate or subscription.

## Fix

- Updated `method.sha256` in `contracts/examples/assess/assessment.example.json` whenever `contracts/examples/assess/method.example.json` changed, committed `avd-assess` first, and synced byte-for-byte into `avd-second-brain` (`contracts/FOUNDATION-PINS.json`), `avd-current-state`, and `avd-ops`.
- Updated `Get-AssessScore` and `Test-AssessmentReport` in `scripts/AvdBrain.psm1` to accept `not-applicable` outcomes and exclude them from score and coverage denominators.
- Added `c12.group.scaling.failedEvaluations` to the count-valued exception list in `tests/Connectors.Tests.ps1`.

## Guard

- `tests/Connectors.Tests.ps1` verifies `contracts/FOUNDATION-PINS.json` hashes, `method.sha256` in `contracts/examples/assess/assessment.example.json`, and `not-applicable` scoring in `Get-AssessScore`.
