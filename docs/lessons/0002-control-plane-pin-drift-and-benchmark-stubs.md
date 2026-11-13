# Lesson 0002: Five-plane pin drift, hardcoded benchmark probes, and live-test coverage gaps

## What happened

A cross-repo live-test readiness sweep across all 15 sibling `avd-ops` repositories (excluding `avd-hcl`) surfaced three recurring gaps between offline CI coverage and live-tenant readiness:

1. **Five-plane pin and schema drift in `avd-landing-zone`:** After all five split control-plane repositories (`avd-entra`, `avd-intune`, `avd-m365`, `avd-azure`, `avd-power-platform`) merged Phase 4 US Gov (`C26`) changes and `avd-azure` added `azure-outputs.json` emission, `avd-landing-zone` still pinned pre-USGov commits and stale schema hashes across five places (`contracts/control-planes.json`, `contracts/PINS.json`, `site/portal/portal-core.js`, `site/portal/index.html`, and three test files).
2. **`avd-benchmark` Tier 1 probes are still stubbed:** `Invoke-AvdBenchmarkProfile` in `avd-benchmark/scripts/AvdBenchmark.psm1` returns hardcoded deterministic sample arrays rather than invoking `diskspd.exe`, PerfMon, Event Logs, or Azure Resource Graph queries—meaning the committed C25 `corpus.json` and `avd-assess/evidence/` records are simulated rather than live-measured.
3. **Zero live runs on the split control planes and partner tiers:** While `avd-landing-zone` Commercial deploys, `avd-swarm` S1a (`AzureOpenAI` fallback), `avd-linecheck` Commercial Chromium spikes, and basic `avd-current-state` collection have real-run evidence, the five split control planes, `avd-liquidware`, `avd-servicenow` (`-Mode LivePdi`), `avd-swarm` S2 (`--mode azure`), `avd-current-state` drift/local collectors, and all `usgov` (`C26`) paths have only been tested offline or with mocks.

## Cause

- Control-plane pins and short SHAs are duplicated across manifests, portal UI/engine JS, and test fixtures in `avd-landing-zone`, so updates to upstream control-plane repos do not automatically propagate without a coordinated pin-sync PR.
- Offline Pester/Node suites (`AzMock`, `Mock-PDI`, `OfflineFixture`) validate contract schemas and command construction but cannot detect Graph `beta` schema quirks, simulated probe outputs, or missing live-run coverage on their own.

## Fix

- Opened `avd-landing-zone` PR #146 (`chore/update-control-plane-pins`) to sync `contracts/control-planes.json`, `contracts/PINS.json`, `contracts/schemas/`, `site/portal/portal-core.js`, `site/portal/index.html`, and test expectations to the current `main` HEADs of all five control planes (`node --test "build/tests/portal/*.test.mjs"` 158/158 passing).
- Queued 12 `sandbox-run/v1` items across Phases 1–3 (five split control planes, `avd-current-state` + `avd-landing-zone` Day-2 ops, and `avd-swarm` S2/alert-path/Foundry), grouped by `deploymentKey: lz-dev-1xD2as` to share a single standing dev estate.
- Ordered remaining work into Phase 0 (`$0` `avd-servicenow` LivePdi + `avd-linecheck` `?cloud=gov`/packs), Phase 4 (`avd-benchmark` real probe wiring), Phase 5 (`avd-liquidware`, gated on BYO licenses), and Phase 6 (`usgov`/`C26`, gated on sovereign lab access).

## Guard

- `avd-landing-zone/build/tests/portal/portal-core.test.mjs` and `build/tests/AvdLandingZone.Tests.ps1` enforce lockstep between `contracts/control-planes.json`, `contracts/PINS.json`, and `site/portal/portal-core.js`.
- Every `sandbox-run/v1` item is pinned to a 40-character commit SHA and requires explicit owner approval (`go batch <id> $<total>`) before any Azure spend.
