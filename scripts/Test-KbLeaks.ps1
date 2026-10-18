<#
.SYNOPSIS
  Runs the brain's sensitive-text guard over the family knowledge base (docs/knowledge/) and llms.txt.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  The family checks (scripts/kb/validate.py) catch email addresses and public IPv4 addresses. This
  adds the rest of the brain's guard (docs/knowledge-spec.md §8): GUIDs other than placeholders, UNC
  paths, default Windows machine names, and, in an organization fork, phrases on the hashed customer
  denylist (knowledge/denylist.sha256). One line per finding, then RESULT PASS or RESULT FAIL
  (exit 1). CI runs it in kb-validate.

.EXAMPLE
  ./scripts/Test-KbLeaks.ps1
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  # The repo root to scan.
  [string] $Path = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$denyFile = Join-Path $root 'knowledge/denylist.sha256'
$denyHash = @()
if (Test-Path -LiteralPath $denyFile) {
  $denyHash = @(Get-Content -LiteralPath $denyFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9a-fA-F]{64}$' })
}

$files = @(Get-ChildItem -LiteralPath (Join-Path $root 'docs/knowledge') -Recurse -File -Include *.md, *.yaml, *.toml)
$llms = Join-Path $root 'llms.txt'
if (Test-Path -LiteralPath $llms) { $files += Get-Item -LiteralPath $llms }

$findings = @(foreach ($f in $files) {
    $rel = [IO.Path]::GetRelativePath($root, $f.FullName) -replace '\\', '/'
    Get-BrainSensitiveText -Text (Get-Content -LiteralPath $f.FullName -Raw) -Path $rel -DenyHash $denyHash
  })
foreach ($f in $findings | Sort-Object Path) {
  Write-Host ("{0,-7} {1,-34} {2}  {3}" -f 'ERROR', $f.Check, $f.Path, $f.Message) -ForegroundColor Red
}

Write-Host "Scanned $($files.Count) files under docs/knowledge/ and llms.txt"
if ($findings.Count) {
  Write-Host "RESULT FAIL ($($findings.Count) errors)" -ForegroundColor Red
  exit 1
}
Write-Host 'RESULT PASS' -ForegroundColor Green
