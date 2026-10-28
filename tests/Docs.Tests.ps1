#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# Offline tests for the docs consistency check (docs/docs-spec.md): each check D1 to D11 against a
# small fixture repo, the generator, and this repo's own docs.

BeforeAll {
  $script:root = Split-Path $PSScriptRoot -Parent
  Import-Module (Join-Path $script:root 'scripts/AvdBrain.psm1') -Force
  $script:notice = '  Personal project, not for production use. Provided as is.'

  function Write-TestFile { param($Root, $Path, $Text) $f = Join-Path $Root $Path; New-Item -ItemType Directory -Force (Split-Path $f) | Out-Null; Set-Content -LiteralPath $f -Value $Text -NoNewline }

  # A connected repo with one entry point, a README and a doc; each test adds what it needs.
  function New-TestRepo {
    param([string] $Name = 'avd-example', [hashtable] $File = @{})
    $r = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
    Write-TestFile $r 'scripts/Get-Thing.ps1' @"
<#
.SYNOPSIS
  Gets the thing. More words here.
$script:notice

.PARAMETER Name
  The thing's name.
.EXAMPLE
  ./scripts/Get-Thing.ps1 -Name x
#>
[CmdletBinding(DefaultParameterSetName = 'One')]
param(
  [Parameter(Mandatory)] [string] `$Name,
  # How many.
  [Parameter(ParameterSetName = 'One')] [int] `$Count = 3,
  [switch] `$Quiet
)
"@
    Write-TestFile $r 'README.md' "# $Name`n`nRun ``scripts/Get-Thing.ps1``.`n"
    Write-TestFile $r 'docs/guide.md' "# Guide`n`nSee [the README](../README.md).`n"
    foreach ($k in $File.Keys) { Write-TestFile $r $k $File[$k] }
    Get-DocRepo -Path $r -Name $Name -Commit 'abc1234def'
  }

  function New-TestFact {
    [pscustomobject]@{
      Contracts = @(Get-DocContract -Text @'
| # | Contract | Producer | Consumer | Format | Status |
|---|---|---|---|---|---|
| C11 | Facts | a | b | `avd-current-state-facts/v1` (`contracts/schemas/current-state-facts.schema.json`) | Built |
| C13 | Docs findings | a | b | `avd-doc-findings/v1` (`contracts/schemas/doc-findings.schema.json`) | Built |
| C14 | Target | a | b | `avd-target-state/v1` (`contracts/schemas/missing.schema.json`) | Built |
'@)
      Sources = @(
        [pscustomobject]@{ name = 'avd-example'; url = 'https://github.com/nickprignano/avd-example'; ref = 'main'; stage = 'Example'; index = @('docs'); feeds = @('C11 facts'); reads = @() }
        [pscustomobject]@{ name = 'avd-other'; url = 'https://github.com/nickprignano/avd-other'; ref = 'main'; stage = 'Other'; index = @('docs'); feeds = @(); reads = @('C99') }
        [pscustomobject]@{ name = 'avd-third'; url = 'https://github.com/nickprignano/avd-third'; ref = 'main'; stage = 'Third'; index = @('docs'); feeds = @(); reads = @() }
      )
      Terms = @([pscustomobject]@{ use = 'Microsoft Entra ID'; avoid = @('Azure AD'); caseSensitive = $true; why = 'renamed' })
      TermSkip = @()
      Schemas = @{ 'current-state-facts.schema.json' = (Get-DocTextHash -Text "{`n  `"a`": 1`n}`n"); 'doc-findings.schema.json' = 'x' }
      ConnectorTests = "Describe 'C11' { 'current-state-facts.schema.json' }"
      Rules = @{ 'quality-gate.json' = [pscustomobject]@{ Version = 2; History = @(1, 2) } }
      CatalogIds = @('microsoft/teams/2')
      KnowledgeFiles = @('knowledge/catalog/apps.json', 'knowledge/rules/quality-gate.json')
    }
  }
}

Describe 'Reading a repo' {
  It 'marks fenced code and quotes' {
    $l = @(Get-DocMarkdownLine -Text "a`n``````powershell`nb`n```````n> c")
    $l.Code | Should -Be @($false, $true, $true, $true, $false)
    $l[4].Quote | Should -BeTrue
  }
  It 'reads a script''s help and parameters without running it' {
    $s = (New-TestRepo).Scripts[0]
    $s.Synopsis | Should -Be 'Gets the thing.'
    $s.HasNotice | Should -BeTrue
    $s.Parameters.Name | Should -Be @('Name', 'Count', 'Quiet')
    ($s.Parameters | Where-Object Name -eq 'Name').Mandatory | Should -BeTrue
    ($s.Parameters | Where-Object Name -eq 'Count').Help | Should -Be 'How many.'
    ($s.Parameters | Where-Object Name -eq 'Count').Default | Should -Be '3'
    ($s.Parameters | Where-Object Name -eq 'Count').Set | Should -Be 'One'
    $s.Examples | Should -Be @('./scripts/Get-Thing.ps1 -Name x')
  }
  It 'reads a Bicep file''s descriptions, parameters and outputs' {
    $r = New-TestRepo -File @{ 'bicep/main.bicep' = @"
metadata description = 'The main template.'
@description('Where it goes.')
@allowed([
  'eastus'
])
param location string = 'eastus'
param tags object = {
  a: 'b'
}
@description('The ID.')
output id string = x.id
"@ }
    $b = $r.Bicep[0]
    $b.Description | Should -Be 'The main template.'
    $b.Parameters.Name | Should -Be @('location', 'tags')
    $b.Parameters[0].Description | Should -Be 'Where it goes.'
    $b.Parameters[1].Default | Should -Be '(see the file)'
    $b.Outputs[0].Description | Should -Be 'The ID.'
  }
  It 'parses the contracts table' {
    $c = @((New-TestFact).Contracts)
    $c.Id | Should -Be @('C11', 'C13', 'C14')
    $c[0].Formats | Should -Be @('avd-current-state-facts/v1')
    $c[0].Schemas | Should -Be @('current-state-facts.schema.json')
    $c[0].Built | Should -BeTrue
  }
}

Describe 'D1 links and paths' {
  It 'flags a broken relative link as an error and a missing named path as a warning' {
    $r = New-TestRepo -File @{ 'docs/bad.md' = "[x](missing.md) [ok](guide.md#guide) [web](https://example.com) ``docs/nothere.md`` ``scripts/Get-Thing.ps1`` ``other/repo.md``" }
    $f = @(Test-DocLink -Repo $r)
    $f.Count | Should -Be 2
    ($f | Where-Object severity -eq 'error').says | Should -Be 'links to missing.md'
    ($f | Where-Object severity -eq 'warning').says | Should -Be 'names docs/nothere.md'
  }
  It 'flags a link that leaves the repo, and ignores code blocks' {
    $r = New-TestRepo -File @{ 'docs/up.md' = "[x](../../elsewhere.md)`n``````n[y](nope.md)`n``````" }
    @(Test-DocLink -Repo $r).truth | Should -Be @('the link leaves the repository; link to GitHub instead')
  }
}

Describe 'D2 entry points' {
  It 'passes a script the README names' { @(Test-DocEntryPoint -Repo (New-TestRepo)).Count | Should -Be 0 }
  It 'flags an entry point the README doesn''t name, and one without a synopsis' {
    $r = New-TestRepo -File @{ 'scripts/New-Thing.ps1' = "<#`n.DESCRIPTION`n  x`n$script:notice`n#>`nparam()" }
    $f = @(Test-DocEntryPoint -Repo $r)
    $f.Count | Should -Be 2
    $f.says | Should -Contain 'no .SYNOPSIS in its comment-based help'
    ($f | Where-Object path -eq 'README.md').generated | Should -BeTrue
  }
}

Describe 'D3 parameters' {
  It 'flags a parameter the docs use that the script doesn''t have' {
    $r = New-TestRepo -File @{ 'docs/use.md' = "``````powershell`n./scripts/Get-Thing.ps1 -Name a -Cou 2 -Verbose -Colour red`n```````nAlso ``Get-Thing.ps1 -Nmae b``." }
    $f = @(Test-DocParameter -Repo $r | Where-Object severity -eq 'error')
    $f.says | Should -Be @('Get-Thing.ps1 -Colour', 'Get-Thing.ps1 -Nmae')
  }
  It 'skips a script passed as another command''s argument' {
    $r = New-TestRepo -File @{ 'docs/lint.md' = "``````bash`npwsh -c ""Invoke-ScriptAnalyzer -Path ./scripts/Get-Thing.ps1 -Settings ./s.psd1 -EnableExit""`npwsh -File ./scripts/Get-Thing.ps1 -Nmae x`n``````" }
    @(Test-DocParameter -Repo $r | Where-Object severity -eq 'error').says | Should -Be @('Get-Thing.ps1 -Nmae')
  }
  It 'checks scripts in other repos the docs name' {
    $other = New-TestRepo -Name 'avd-other'
    $r = New-TestRepo -File @{ 'docs/x.md' = '`Get-Thing.ps1 -Wrong`' }
    Remove-Item (Join-Path $r.Root 'scripts') -Recurse; $r = Get-DocRepo -Path $r.Root -Name 'avd-example'
    @(Test-DocParameter -Repo $r -Script $other.Scripts).says | Should -Be @('Get-Thing.ps1 -Wrong')
  }
  It 'flags .PARAMETER help for a parameter that is gone, and warns on a parameter without help' {
    $r = New-TestRepo -File @{ 'scripts/Get-Thing.ps1' = "<#`n.SYNOPSIS`n  x.`n$script:notice`n.PARAMETER Old`n  gone`n#>`nparam([string] `$New)" }
    $f = @(Test-DocParameter -Repo $r)
    ($f | Where-Object severity -eq 'error').says | Should -Be '.PARAMETER Old'
    ($f | Where-Object severity -eq 'warning').says | Should -Be '-New has no help'
  }
}

Describe 'D4 contracts' {
  It 'flags a format next to the wrong contract ID, and a contract that doesn''t exist' {
    $r = New-TestRepo -File @{ 'docs/c.md' = "C13 writes ``avd-current-state-facts/v1``.`nSee contract C42.`nC11 is ``avd-current-state-facts/v1``." }
    $f = @(Test-DocContract -Repo $r -Fact (New-TestFact))
    $f.truth | Should -Be @('avd-current-state-facts/v1 is contract C11', 'docs/contracts.md has no C42')
  }
  It 'flags a vendored schema that differs from the authority, ignoring line endings' {
    $fact = New-TestFact
    $ok = New-TestRepo -File @{ 'contracts/current-state-facts.schema.json' = "{`r`n  `"a`": 1`r`n}`r`n" }
    @(Test-DocContract -Repo $ok -Fact $fact).Count | Should -Be 0
    $bad = New-TestRepo -File @{ 'contracts/current-state-facts.schema.json' = '{ "a": 2 }' }
    (Test-DocContract -Repo $bad -Fact $fact).check | Should -Be 'D4'
  }
  It 'in the brain: flags a built contract without its schema or test, and sources naming unknown contracts' {
    $r = New-TestRepo -Name 'avd-second-brain'
    $f = @(Test-DocContract -Repo $r -Fact (New-TestFact))
    $f.says | Should -Contain 'C14 is Built with missing.schema.json'
    $f.says | Should -Contain 'no test names C13 or doc-findings.schema.json'
    $f.says | Should -Contain 'avd-other feeds or reads C99'
  }
}

Describe 'D5 paired decisions' {
  BeforeAll {
    function New-PairRepo {
      param($Name, $Path, $Status, $Pair, $Owner = 'avd-ops')
      New-TestRepo -Name $Name -File @{ $Path = "---`nstatus: $Status`n---`n# Decision`n`n- **Pair:** [theirs](https://github.com/$Owner/$Pair)`n" }
    }
  }
  It 'passes a pair that links both ways with the same status' {
    $a = New-PairRepo 'avd-a' 'docs/decisions/0001-x.md' 'accepted' 'avd-b/blob/main/docs/decisions/0002-y.md'
    $b = New-PairRepo 'avd-b' 'docs/decisions/0002-y.md' 'accepted' 'avd-a/blob/main/docs/decisions/0001-x.md'
    @(Test-DocDecisionPair -Repo $a, $b).Count | Should -Be 0
  }
  It 'reads links that still use the owner from before the org move' {
    $a = New-PairRepo 'avd-a' 'docs/decisions/0001-x.md' 'accepted' 'avd-b/blob/main/docs/decisions/0002-y.md' -Owner 'nickprignano'
    $b = New-PairRepo 'avd-b' 'docs/decisions/0002-y.md' 'proposed' 'avd-a/blob/main/docs/decisions/0001-x.md'
    (Test-DocDecisionPair -Repo $a, $b).truth | Should -Match 'is proposed'
  }
  It 'flags a status mismatch, a missing link back and a broken link' {
    $a = New-PairRepo 'avd-a' 'docs/decisions/0001-x.md' 'accepted' 'avd-b/blob/main/docs/decisions/0002-y.md'
    $b = New-PairRepo 'avd-b' 'docs/decisions/0002-y.md' 'proposed' 'avd-a/blob/main/docs/decisions/0001-x.md'
    (Test-DocDecisionPair -Repo $a, $b).truth | Should -Match 'is proposed'
    $c = New-PairRepo 'avd-b' 'docs/decisions/0002-y.md' 'accepted' 'avd-a/blob/main/docs/decisions/0009-gone.md'
    $f = @(Test-DocDecisionPair -Repo $a, $c)
    $f.truth | Should -Contain 'docs/decisions/0009-gone.md does not exist in avd-a'
  }
}

Describe 'D6 changelog' {
  It 'warns when a PR changes an entry point and records nothing' {
    $r = New-TestRepo -File @{ 'CHANGELOG.md' = "# Changelog`n`n## Unreleased`n" }
    @(Test-DocChangelog -Repo $r -ChangedFile 'scripts/Get-Thing.ps1').check | Should -Be 'D6'
    @(Test-DocChangelog -Repo $r -ChangedFile 'scripts/Get-Thing.ps1' -PullRequestBody "x`nChangelog: Fixed: the thing").Count | Should -Be 0
    @(Test-DocChangelog -Repo $r -ChangedFile 'docs/guide.md').Count | Should -Be 0
  }
  It 'warns when there is no changelog' { (Test-DocChangelog -Repo (New-TestRepo)).says | Should -Be 'no CHANGELOG.md' }
}

Describe 'D7 connection tables' {
  It 'flags a connected repo missing from a table with a stage column' {
    $r = New-TestRepo -Name 'avd-second-brain' -File @{ 'README.md' = "| Repo | Lifecycle stage |`n|---|---|`n| [avd-example](x) | a |`n| avd-other | b |`n`n| Repo | Notes |`n|---|---|`n| avd-example | a |`n" }
    $f = @(Test-DocConnectionTable -Repo $r -Source (New-TestFact).Sources)
    $f.Count | Should -Be 1
    $f.truth | Should -Be 'sources/sources.json connects avd-third'
  }
  It 'leaves out the repo the table is in' {
    $r = New-TestRepo -Name 'avd-third' -File @{ 'README.md' = "| Repo | Stage |`n|---|---|`n| avd-example | a |`n| avd-other | b |`n" }
    @(Test-DocConnectionTable -Repo $r -Source (New-TestFact).Sources).Count | Should -Be 0
  }
}

Describe 'D8 terms' {
  It 'flags wording to avoid in prose, not in code, quotes or skipped folders' {
    $r = New-TestRepo -File @{ 'docs/t.md' = "Sign in with Azure AD.`n``Azure AD`` in code is fine.`n> Azure AD quoted.`n``````n Azure AD`n``````"; 'vault/x.md' = 'Azure AD' }
    $f = @(Test-DocTerm -Repo $r -Term (New-TestFact).Terms -Skip 'vault/')
    $f.Count | Should -Be 1
    $f.line | Should -Be 1
  }
  It 'the terms list matches its schema' {
    Test-Json -Path (Join-Path $script:root 'sources/terms.json') -SchemaFile (Join-Path $script:root 'sources/terms.schema.json') | Should -BeTrue
  }
}

Describe 'D9 knowledge citations' {
  It 'flags a missing file, catalog entry or rule version' {
    $r = New-TestRepo -File @{ 'docs/k.md' = "knowledge/catalog/apps.json#microsoft/teams/2 knowledge/catalog/apps.json#nope/x/1`nknowledge/rules/quality-gate.json@v2 knowledge/rules/quality-gate.json@v3 knowledge/rules/gone.json@v1" }
    (Test-DocKnowledgeCitation -Repo $r -Fact (New-TestFact)).says | Should -Be @('knowledge/catalog/apps.json#nope/x/1', 'knowledge/rules/quality-gate.json@v3', 'knowledge/rules/gone.json@v1')
  }
}

Describe 'D10 and D11 generated text' {
  It 'flags generated files that are missing, out of date or have no source' {
    $r = New-TestRepo -File @{ 'docs/reference/old.md' = 'x'; 'docs/reference/scripts-Get-Thing.md' = 'stale' }
    $f = @(Test-DocGenerated -Repo $r -Expected (Get-DocOutput -Repo $r))
    $f.says | Should -Be @('out of date', 'generated page with no source')
    $f.generated | Should -Be @($true, $true)
  }
  It 'flags what looks like tenant data in generated text, but not a listed public ID' {
    $r = New-TestRepo -File @{ 'scripts/public-ids.txt' = '# public: a role definition' + "`n" + '11111111-2222-3333-4444-555555555555' }
    @(Test-DocPrivate -Repo $r -Output @{ 'a.md' = 'id 11111111-2222-3333-4444-555555555555' }).Count | Should -Be 0
    (Test-DocPrivate -Repo $r -Output @{ 'a.md' = "x`nmail someone@realcompany.com" }).says | Should -Be 'sensitive:email-or-upn'
  }
  It 'never copies addresses or IDs into a reference page' {
    $r = New-TestRepo -File @{ 'bicep/net.bicep' = "@description('Range, like 10.1.0.0/16.')`nparam prefix string = '10.20.0.0/24'`nparam role string = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'`nparam docs string = '192.0.2.0/24'" }
    $page = Get-DocReferencePage -Info $r.Bicep[0]
    $page | Should -Not -Match '10\.(1|20)\.0\.0|acdd72a7'
    $page | Should -Match '192\.0\.2\.0/24'
    @(Test-DocPrivate -Repo $r -Output @{ 'p.md' = $page }).Count | Should -Be 0
  }
}

Describe 'The generator' {
  It 'replaces only the text between a block''s markers' {
    $t = "keep`n<!-- generated:x begin -->`nold`n<!-- generated:x end -->`nkeep too"
    $n = Get-DocUpdatedText -Text $t -Name x -Body 'new'
    $n | Should -Match "keep`n<!-- generated:x begin -->`n<!--[^\n]*-->`nnew`n<!-- generated:x end -->`nkeep too"
    Get-DocUpdatedText -Text 'no markers' -Name x -Body 'new' | Should -Be 'no markers'
  }
  It 'writes a reference page and an entry point table from the help' {
    $s = (New-TestRepo).Scripts[0]
    $page = Get-DocReferencePage -Info $s
    $page | Should -Match '\| `-Name` \| string \| yes \|  \| The thing''s name\. \|'
    $page | Should -Match '\| `-Count` \| int \| no \| `3` \| How many\. \|'
    Get-DocEntryPointTable -Script @($s) | Should -Match '\[`scripts/Get-Thing.ps1`\]\(docs/reference/scripts-Get-Thing.md\) \| Gets the thing\. \|'
  }
  It 'builds the connections table from sources.json' {
    $t = Get-DocConnectionTable -Source (New-TestFact).Sources
    ($t -split "`n").Count | Should -Be 5
    $t | Should -Match '\| \[avd-other\]\(https://github.com/nickprignano/avd-other\) \| Other \| {2}\| C99 \|'
  }
  It 'adds each pull request''s Changelog: lines once, under Unreleased' {
    $text = "# Changelog`n`n## Unreleased`n`n### Fixed`n`n- Old fix. (#1)`n`n## 1.0.0`n"
    $prs = @(
      [pscustomobject]@{ number = 1; body = 'Changelog: Fixed: old fix' }
      [pscustomobject]@{ number = 2; body = "Text`nChangelog: Added: a thing`nChangelog: Fixed: a bug." }
      [pscustomobject]@{ number = 3; body = 'Changelog: none' }
    )
    $n = Get-DocChangelog -Text $text -PullRequest $prs
    $n | Should -Match "## Unreleased`n`n### Fixed`n`n- Old fix. \(#1\)`n- A bug. \(#2\)|- a bug. \(#2\)"
    $n | Should -Match '### Added\s+- a thing. \(#2\)'
    $n | Should -Not -Match '#3'
    Get-DocChangelog -Text $n -PullRequest $prs | Should -Be $n
  }
}

Describe 'Running the checks' {
  It 'numbers findings per check and leaves out accepted ones, never D11' {
    $r = New-TestRepo -File @{ 'docs/a.md' = '[x](gone.md) [y](gone2.md)' }
    $f = @(Test-DocConsistency -Repo @($r) -Fact (New-TestFact) | Where-Object check -eq 'D1')
    $f.id | Should -Be @('D1-0001', 'D1-0002')
    Write-TestFile $r.Root 'docs/accepted-findings.json' (@{ accepted = @(@{ key = $f[0].key; reason = 'test' }) } | ConvertTo-Json)
    @(Test-DocConsistency -Repo @($r) -Fact (New-TestFact) | Where-Object check -eq 'D1').says | Should -Be @('links to gone2.md')
  }
  It 'the key stays the same when the line moves' {
    $a = Get-DocFinding -Check D1 -Severity error -Repo r -Path p -Line 1 -Says s -Truth t
    $b = Get-DocFinding -Check D1 -Severity error -Repo r -Path p -Line 9 -Says s -Truth t
    $a.key | Should -Be $b.key
  }
  It 'this repo''s own docs have no errors' {
    $brain = Get-DocRepo -Path $script:root -Name 'avd-second-brain'
    $f = @(Test-DocConsistency -Repo @($brain) -Fact (Get-DocFact -BrainPath $script:root) | Where-Object severity -eq 'error')
    $f | ForEach-Object { "$($_.id) $($_.path):$($_.line) $($_.says) / $($_.truth)" } | Should -BeNullOrEmpty
  }
}
