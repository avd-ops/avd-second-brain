<#
.SYNOPSIS
  Reports avd-current-state validator checks covered or uncovered by knowledge/runbooks/*.md, and optionally generates draft runbook stubs.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  Reads -Check '<name>' entries from avd-current-state's avd_deployment_validator.ps1 and compares
  them against resolves-checks front matter in knowledge/runbooks/*.md. With -WriteDrafts, writes
  up to -MaxDrafts status: draft runbook stubs for uncovered checks using the vault runbook template.

.EXAMPLE
  ./scripts/Get-RunbookCoverage.ps1
.EXAMPLE
  ./scripts/Get-RunbookCoverage.ps1 -WriteDrafts -MaxDrafts 5
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  # Path to avd-current-state's avd_deployment_validator.ps1.
  [string] $ValidatorPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'avd-current-state/avd_deployment_validator.ps1'),
  # Path to the shared runbooks folder.
  [string] $RunbooksPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'knowledge/runbooks'),
  # Write status: draft stubs for uncovered checks.
  [switch] $WriteDrafts,
  # Maximum number of draft stubs to write in one run.
  [int] $MaxDrafts = 5,
  # Emit JSON instead of a summary table.
  [switch] $Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ValidatorPath)) {
  throw "Validator script not found at '$ValidatorPath'. Pass -ValidatorPath."
}
if (-not (Test-Path $RunbooksPath)) {
  throw "Runbooks directory not found at '$RunbooksPath'."
}

$validatorChecks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($m in (Select-String -Path $ValidatorPath -Pattern "-Check\s+'([^']+)'" -AllMatches)) {
  foreach ($match in $m.Matches) {
    $null = $validatorChecks.Add($match.Groups[1].Value.Trim())
  }
}

$coveredChecks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in (Get-ChildItem -Path $RunbooksPath -Filter '*.md' | Where-Object { $_.Name -ne 'README.md' })) {
  $raw = Get-Content -Path $file.FullName -Raw
  if ($raw -match '(?ms)^---\r?\n(.*?)\r?\n---') {
    $fm = $Matches[1]
    if ($fm -match '(?m)^resolves-checks:\s*\[([^\]]*)\]') {
      $items = $Matches[1] -split ','
      foreach ($item in $items) {
        $clean = $item.Trim().Trim('"', "'")
        if ($clean) { $null = $coveredChecks.Add($clean) }
      }
    }
  }
}

$allChecks = @($validatorChecks | Sort-Object)
$covered = @($allChecks | Where-Object { $coveredChecks.Contains($_) })
$uncovered = @($allChecks | Where-Object { -not $coveredChecks.Contains($_) })

$created = @()
if ($WriteDrafts -and $uncovered.Count -gt 0) {
  $today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
  foreach ($check in ($uncovered | Select-Object -First $MaxDrafts)) {
    $slug = ($check.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    $target = Join-Path $RunbooksPath "fix-$slug.md"
    if (Test-Path $target) { continue }
    $body = @"
---
type: runbook
status: draft
owner: avd-ops
last-verified: $today
resolves-checks: ["$check"]
tags: [avd, draft]
---

# Remediate $check

## When to use

- ``avd-current-state`` reports ``$check`` as ``FAIL`` or ``WARN``.

## Before you start

- Access needed: Least-privilege reader/contributor role for the affected control plane.
- Change window / approval: Required before making state changes.
- Blast radius: Scope of the failing ``$check`` finding.

## Steps

1. Inspect the failing ``$check`` detail in the ``avd-current-state`` validator output.
2. Apply the minimal fix for the affected resource or policy.
3. Document any environment-specific prerequisites before promoting this draft to ``verified``.

## Verify

Re-run ``avd_deployment_validator.ps1`` and ingest the package into your estate vault. Confirm ``$check`` reports ``PASS``.

## Roll back

Revert the resource or policy change made in Steps.

## History

| Date | Who | Note |
|---|---|---|
| $today | runbook-coverage | Auto-drafted stub for uncovered validator check |
"@
    Set-Content -Path $target -Value ($body + "`n") -Encoding utf8NoBOM
    $created += "knowledge/runbooks/fix-$slug.md"
  }
}

$result = [ordered]@{
  totalChecks     = $allChecks.Count
  coveredCount    = $covered.Count
  uncoveredCount  = $uncovered.Count
  uncoveredChecks = $uncovered
  createdDrafts   = $created
}

if ($Json) {
  $result | ConvertTo-Json -Depth 4
  return
}

Write-Host "Runbook coverage: $($covered.Count)/$($allChecks.Count) validator checks covered ($($uncovered.Count) uncovered)." -ForegroundColor Cyan
if ($created.Count -gt 0) {
  Write-Host "Created $($created.Count) draft runbook stub(s):" -ForegroundColor Green
  $created | ForEach-Object { Write-Host "  + $_" }
}
