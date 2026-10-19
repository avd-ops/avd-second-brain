<#
.SYNOPSIS
  Checks the organizational second brain's knowledge base (knowledge/): schemas, scope, cross-references and customer data.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  Runs every check in docs/knowledge-spec.md §8 and prints one line per finding. Errors fail
  (exit 1): a file that doesn't match its schema, customer data (LOB apps, engagement trails in the
  public scope, sensitive text, denylisted customer names), a verdict without evidence, a rule
  change without history, a closed engagement without a harvest. Warnings (stale catalog entries)
  don't fail. CI runs it; run it before every harvest PR. The last line is RESULT PASS or RESULT FAIL.

.EXAMPLE
  ./scripts/Test-Knowledge.ps1
.EXAMPLE
  ./scripts/Test-Knowledge.ps1 -Path ../my-org-brain/knowledge
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  # The knowledge base to check.
  [string] $Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'knowledge')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$scope = (Get-Content -LiteralPath (Join-Path $Path 'knowledge.json') -Raw | ConvertFrom-Json).scope
Write-Host "Second brain: $Path (scope: $scope)"

$findings = @(Test-BrainKnowledge -Path $Path)
foreach ($f in $findings | Sort-Object Severity, Path) {
  $color = if ($f.Severity -eq 'Error') { 'Red' } else { 'Yellow' }
  Write-Host ("{0,-7} {1,-34} {2}  {3}" -f $f.Severity.ToUpperInvariant(), $f.Check, $f.Path, $f.Message) -ForegroundColor $color
}

$errors = @($findings | Where-Object Severity -eq 'Error').Count
$warnings = @($findings | Where-Object Severity -eq 'Warning').Count
if ($errors) {
  Write-Host "RESULT FAIL ($errors errors, $warnings warnings)" -ForegroundColor Red
  exit 1
}
Write-Host "RESULT PASS ($warnings warnings)" -ForegroundColor Green
