#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# Offline tests for the organizational second brain (docs/knowledge-spec.md): the guard over
# knowledge/, in both scopes, the sensitive-text scan, app resolution, calibration and search.
# Each guard test copies the real knowledge/ to a temporary folder and breaks one thing.

BeforeAll {
  $script:root = Split-Path $PSScriptRoot -Parent
  Import-Module (Join-Path $script:root 'scripts/AvdBrain.psm1') -Force
  $script:today = [datetime]'2026-10-16'

  # A copy of the repo's knowledge/ and docs/ in a fresh folder; returns the knowledge path.
  function New-TestBrain {
    param([ValidateSet('public', 'organization')] [string] $Scope = 'public')
    $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    Copy-Item -Recurse (Join-Path $script:root 'knowledge') $dir
    Copy-Item -Recurse (Join-Path $script:root 'docs') $dir
    $brain = Join-Path $dir 'knowledge'
    if ($Scope -ne 'public') { Set-TestJson $brain 'knowledge.json' { param($j) $j.scope = $Scope } }
    $brain
  }
  function Get-TestJson { param($Brain, $Rel) Get-Content (Join-Path $Brain $Rel) -Raw | ConvertFrom-Json }
  function Set-TestJson {
    param($Brain, $Rel, [scriptblock] $Change)
    $j = Get-TestJson $Brain $Rel
    & $Change $j
    $j | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $Brain $Rel)
  }
  function Add-TestEngagement {
    param($Brain, [string] $Id = 'eng-2026-11-a7f3', [string] $Status = 'migrating', [bool] $Harvested = $false)
    $e = [ordered]@{
      id      = $Id
      period  = @{ start = '2026-11' }
      status  = $Status
      estate  = @{ usersBucket = '500-2k'; currentPlatforms = @('citrix'); sources = @('stratusphere-export', 'graph') }
      harvest = if ($Harvested) { @{ done = $true; date = '2027-02-01'; by = 'reviewer' } } else { @{ done = $false } }
    }
    $e | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Brain "engagements/$Id.json")
  }
  function Get-TestObservation {
    param([string] $Engagement = 'eng-2026-11-a7f3', [string] $Tier = 'medium', [string] $VmSize = 'Standard_E8as_v5',
      [string] $Family = 'E', [double] $Predicted = 14, [double] $Measured = 12)
    [pscustomobject]@{ engagement = $Engagement; wave = 1; tier = $Tier; vmSize = $VmSize; vmFamily = $Family
      predictedSessionsPerHost = $Predicted; measuredSessionsPerHost = $Measured; measuredOn = '2027-01-15' }
  }
  function Get-Errors { param($Brain) @(Test-BrainKnowledge -Path $Brain -Today $script:today | Where-Object Severity -eq 'Error') }
}

Describe 'The repository brain' {
  It 'passes every check with no errors' {
    $findings = @(Test-BrainKnowledge -Path (Join-Path $script:root 'knowledge') -Today $script:today)
    @($findings | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
  }
  It 'is the public scope, with no engagement trail' {
    (Get-TestJson (Join-Path $script:root 'knowledge') 'knowledge.json').scope | Should -Be 'public'
    @(Get-ChildItem (Join-Path $script:root 'knowledge/engagements') -Filter *.json) | Should -BeNullOrEmpty
    @((Get-TestJson (Join-Path $script:root 'knowledge') 'calibration/sizing.json').observations) | Should -BeNullOrEmpty
  }
  It 'cites a document for every catalog verdict' {
    foreach ($e in (Get-TestJson (Join-Path $script:root 'knowledge') 'catalog/apps.json').entries) {
      @($e.evidence | Where-Object kind -eq 'doc').Count | Should -BeGreaterThan 0 -Because $e.id
    }
  }
}

Describe 'Test-BrainKnowledge: schemas' {
  It 'fails a catalog entry missing a required property' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0].PSObject.Properties.Remove('category') }
    (Get-Errors $b).Check | Should -Contain 'schema'
  }
  It 'fails an unknown property (no free-form fields that could carry customer data)' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0] | Add-Member customer 'x' }
    (Get-Errors $b).Check | Should -Contain 'schema'
  }
  It 'fails an engagement ID that names a customer' {
    $b = New-TestBrain organization
    Add-TestEngagement $b -Id 'contoso-202611'
    (Get-Errors $b).Check | Should -Contain 'schema'
  }
  It 'fails a users count instead of a bucket' {
    $b = New-TestBrain organization
    Add-TestEngagement $b
    Set-TestJson $b 'engagements/eng-2026-11-a7f3.json' { param($j) $j.estate.usersBucket = '1317' }
    (Get-Errors $b).Check | Should -Contain 'schema'
  }
}

Describe 'Test-BrainKnowledge: catalog' {
  It 'fails a line-of-business app' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0].scope = 'customer-lob' }
    (Get-Errors $b).Check | Should -Contain 'catalog:customer-lob'
  }
  It 'fails a verdict without evidence' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0].evidence = @() }
    (Get-Errors $b).Check | Should -Contain 'catalog:verdict-without-evidence'
  }
  It 'allows an unknown verdict without evidence' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0].evidence = @(); $j.entries[0].multiSession = 'unknown' }
    Get-Errors $b | Should -BeNullOrEmpty
  }
  It 'fails a model-written entry without its metadata, and a model verdict nobody reviewed' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0].source = 'llm'; $j.entries[0].PSObject.Properties.Remove('reviewedBy') }
    $checks = (Get-Errors $b).Check
    $checks | Should -Contain 'catalog:llm-metadata'
    $checks | Should -Contain 'catalog:llm-verdict-unreviewed'
  }
  It 'fails two entries with the same match pattern' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[1].match = @($j.entries[0].match[0]) }
    (Get-Errors $b).Check | Should -Contain 'catalog:ambiguous-match'
  }
  It 'fails document evidence that is not an https URL' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0].evidence[0].ref = 'our wiki' }
    (Get-Errors $b).Check | Should -Contain 'catalog:doc-ref'
  }
  It 'warns, without failing, on an entry not verified for a year' {
    $findings = @(Test-BrainKnowledge -Path (New-TestBrain) -Today $script:today.AddDays(400))
    @($findings | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
    ($findings | Where-Object Severity -eq 'Warning').Check | Should -Contain 'catalog:stale'
  }
}

Describe 'Test-BrainKnowledge: scopes' {
  It 'fails an engagement record in the public brain' {
    $b = New-TestBrain
    Add-TestEngagement $b
    (Get-Errors $b).Check | Should -Contain 'scope:public-engagement-trail'
  }
  It 'fails calibration observations in the public brain' {
    $b = New-TestBrain
    Set-TestJson $b 'calibration/sizing.json' { param($j) $j.observations = @(Get-TestObservation) }
    (Get-Errors $b).Check | Should -Contain 'scope:public-engagement-trail'
  }
  It 'fails pilot evidence in the public brain' {
    $b = New-TestBrain
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0].evidence += [pscustomobject]@{ kind = 'pilot'; ref = 'eng-2026-11-a7f3'; date = '2027-01-10' } }
    (Get-Errors $b).Check | Should -Contain 'scope:public-engagement-trail'
  }
  It 'fails a denylist in the public brain' {
    $b = New-TestBrain
    Set-Content (Join-Path $b 'denylist.sha256') ('0' * 64)
    (Get-Errors $b).Check | Should -Contain 'scope:public-denylist'
  }
  It 'accepts an organization brain with an engagement, its observations and pilot evidence' {
    $b = New-TestBrain organization
    Add-TestEngagement $b
    Set-TestJson $b 'calibration/sizing.json' { param($j) $j.observations = @(Get-TestObservation) }
    Set-TestJson $b 'catalog/apps.json' { param($j) $j.entries[0].evidence += [pscustomobject]@{ kind = 'pilot'; ref = 'eng-2026-11-a7f3'; outcome = 'works'; date = '2027-01-10' } }
    Get-Errors $b | Should -BeNullOrEmpty
  }
}

Describe 'Test-BrainKnowledge: cross-references and harvest' {
  It 'fails evidence and observations that cite an engagement with no record' {
    $b = New-TestBrain organization
    Set-TestJson $b 'calibration/sizing.json' { param($j) $j.observations = @(Get-TestObservation -Engagement 'eng-2026-12-zz99') }
    (Get-Errors $b).Check | Should -Contain 'ref:unknown-engagement'
  }
  It 'fails a VM family that does not match the size' {
    $b = New-TestBrain organization
    Add-TestEngagement $b
    Set-TestJson $b 'calibration/sizing.json' { param($j) $j.observations = @(Get-TestObservation -Family 'D') }
    (Get-Errors $b).Check | Should -Contain 'calibration:vm-family'
  }
  It 'fails a closed engagement that was not harvested' {
    $b = New-TestBrain organization
    Add-TestEngagement $b -Status closed
    (Get-Errors $b).Check | Should -Contain 'engagement:not-harvested'
  }
  It 'accepts a closed, harvested engagement' {
    $b = New-TestBrain organization
    Add-TestEngagement $b -Status closed -Harvested $true
    Get-Errors $b | Should -BeNullOrEmpty
  }
  It 'fails a harvest that lists a catalog entry or a lesson that does not exist' {
    $b = New-TestBrain organization
    Add-TestEngagement $b -Status closed -Harvested $true
    Set-TestJson $b 'engagements/eng-2026-11-a7f3.json' { param($j)
      $j.harvest | Add-Member catalogEntries @('acme/nothing/1')
      $j.harvest | Add-Member lessons @('docs/lessons/9999-missing.md') }
    $checks = (Get-Errors $b).Check
    $checks | Should -Contain 'ref:unknown-catalog-entry'
    $checks | Should -Contain 'ref:missing-lesson'
  }
  It 'fails an engagement whose file name differs from its ID' {
    $b = New-TestBrain organization
    Add-TestEngagement $b
    Rename-Item (Join-Path $b 'engagements/eng-2026-11-a7f3.json') 'eng-2026-11-b000.json'
    (Get-Errors $b).Check | Should -Contain 'engagement:file-name'
  }
}

Describe 'Test-BrainKnowledge: rules' {
  It 'fails a version bump without a history entry' {
    $b = New-TestBrain
    Set-TestJson $b 'rules/workload-tiers.json' { param($j) $j.version = 2; $j.values.targetUtilization = 0.7 }
    (Get-Errors $b).Check | Should -Contain 'rule:history-version'
  }
  It 'accepts a version bump with its reason' {
    $b = New-TestBrain
    Set-TestJson $b 'rules/workload-tiers.json' { param($j)
      $j.version = 2
      $j.history += [pscustomobject]@{ version = 2; date = '2026-12-01'; change = 'Target utilization 0.8 to 0.75'; reason = 'Lesson from a lab run' } }
    Get-Errors $b | Should -BeNullOrEmpty
  }
  It 'fails a rule whose ID differs from its file name' {
    $b = New-TestBrain
    Set-TestJson $b 'rules/workload-tiers.json' { param($j) $j.id = 'tiers' }
    (Get-Errors $b).Check | Should -Contain 'rule:file-name'
  }
}

Describe 'Get-BrainSensitiveText' {
  It 'finds <Kind>' -ForEach @(
    @{ Kind = 'email-or-upn'; Text = 'Owner: jane.doe@fabrikam.com' }
    @{ Kind = 'ip-address'; Text = 'Hub at 10.20.30.40' }
    @{ Kind = 'guid'; Text = 'tenant 3fa85f64-5717-4562-b3fc-2c963f66afa6' }
    @{ Kind = 'unc-path'; Text = 'profiles on \\fs01\profiles$' }
    @{ Kind = 'unc-path'; Text = '"ref": "\\\\fs01\\profiles"' }
    @{ Kind = 'machine-name'; Text = 'seen on DESKTOP-7Q2K9LM' }
  ) {
    @(Get-BrainSensitiveText -Text $Text -Path 'x').Check | Should -Contain "sensitive:$Kind"
  }
  It 'masks what it found' {
    (Get-BrainSensitiveText -Text 'jane.doe@fabrikam.com' -Path 'x').Message | Should -Not -Match 'fabrikam'
  }
  It 'ignores <Why>' -ForEach @(
    @{ Why = 'documentation addresses and placeholder GUIDs'; Text = '192.0.2.10, 203.0.113.5, 00000000-0000-0000-0000-000000000001, x@example.com' }
    @{ Why = 'the contoso.com and GitHub noreply placeholders'; Text = 'user@contoso.com, 41898282+github-actions[bot]@users.noreply.github.com' }
    @{ Why = 'version numbers that are not addresses'; Text = 'Teams 25198.1112.3855.4568' }
    @{ Why = 'registry and program paths'; Text = '"HKLM\\Software\\Microsoft\\Teams" and C:\\Program Files\\Microsoft OneDrive' }
  ) {
    Get-BrainSensitiveText -Text $Text -Path 'x' | Should -BeNullOrEmpty
  }
  It 'finds a denylisted customer name of up to three words, in any case' {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('northwind traders'))).ToLowerInvariant()
    (Get-BrainSensitiveText -Text 'Learned at Northwind Traders.' -Path 'x' -DenyHash $hash).Check | Should -Contain 'sensitive:denylisted-name'
    Get-BrainSensitiveText -Text 'Northwind alone' -Path 'x' -DenyHash $hash | Should -BeNullOrEmpty
  }
  It 'reports the line' {
    (Get-BrainSensitiveText -Text "ok`nhost 10.1.2.3" -Path 'f.json').Path | Should -Be 'f.json:2'
  }
  It 'is applied to every file in the brain, including markdown' {
    $b = New-TestBrain organization
    Add-Content (Join-Path $b 'engagements/README.md') 'Ask jane.doe@fabrikam.com'
    (Get-Errors $b).Check | Should -Contain 'sensitive:email-or-upn'
  }
  It 'reads the denylist in an organization brain' {
    $b = New-TestBrain organization
    $sha = [System.Security.Cryptography.SHA256]::Create()
    Set-Content (Join-Path $b 'denylist.sha256') ([Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('microsoft'))).ToLowerInvariant())
    (Get-Errors $b).Check | Should -Contain 'sensitive:denylisted-name'
  }
}

Describe 'Resolve-BrainApp' {
  BeforeAll {
    $script:catalog = [pscustomobject]@{ entries = @(
        [pscustomobject]@{ id = 'acme/suite/5'; product = 'Acme Suite'; multiSession = 'works'; delivery = 'image'; match = @('Acme*') }
        [pscustomobject]@{ id = 'acme/viewer/5'; product = 'Acme Viewer'; multiSession = 'blocked'; delivery = 'personal'; match = @('Acme Viewer 5*') }
      ) }
  }
  It 'picks the most specific pattern' {
    (Resolve-BrainApp -Name 'Acme Viewer 5.2 (64-bit)' -Catalog $script:catalog).Id | Should -Be 'acme/viewer/5'
    (Resolve-BrainApp -Name 'Acme Suite 5.1' -Catalog $script:catalog).Id | Should -Be 'acme/suite/5'
  }
  It 'matches case-insensitively and cites the entry' {
    $r = Resolve-BrainApp -Name 'acme viewer 5' -Catalog $script:catalog
    $r.Citation | Should -Be 'knowledge/catalog/apps.json#acme/viewer/5'
  }
  It 'returns nothing for an unknown app' {
    Resolve-BrainApp -Name 'Other Tool 1' -Catalog $script:catalog | Should -BeNullOrEmpty
  }
  It 'resolves real inventory names with the repository catalog' {
    $c = Get-Content (Join-Path $script:root 'knowledge/catalog/apps.json') -Raw | ConvertFrom-Json
    (Resolve-BrainApp -Name 'Microsoft Teams (work or school) 25198.1112' -Catalog $c).Id | Should -Be 'microsoft/teams/2'
    (Resolve-BrainApp -Name 'Skype for Business 2016' -Catalog $c).MultiSession | Should -Be 'blocked'
  }
}

Describe 'Get-SizingCalibration' {
  BeforeAll {
    $script:rule = Get-Content (Join-Path $script:root 'knowledge/rules/calibration.json') -Raw | ConvertFrom-Json
  }
  It 'does not apply a factor below the minimum observations' {
    $r = Get-SizingCalibration -Observation @((Get-TestObservation), (Get-TestObservation)) -Rule $script:rule
    $r.Applied | Should -BeFalse
    $r.Factor | Should -Be 1.0
    $r.Observations | Should -Be 2
  }
  It 'applies the median ratio from the minimum observations' {
    $obs = @(
      Get-TestObservation -Predicted 10 -Measured 8
      Get-TestObservation -Predicted 10 -Measured 9
      Get-TestObservation -Predicted 10 -Measured 12
    )
    $r = Get-SizingCalibration -Observation $obs -Rule $script:rule
    $r.Applied | Should -BeTrue
    $r.Factor | Should -Be 0.9
    $r.MinRatio | Should -Be 0.8
    $r.MaxRatio | Should -Be 1.2
  }
  It 'averages the middle two for an even count' {
    $obs = 8, 9, 11, 12 | ForEach-Object { Get-TestObservation -Predicted 10 -Measured $_ }
    (Get-SizingCalibration -Observation $obs -Rule $script:rule).Factor | Should -Be 1.0
  }
  It 'clamps an extreme factor and says so' {
    $obs = 1..3 | ForEach-Object { Get-TestObservation -Predicted 10 -Measured 2 }
    $r = Get-SizingCalibration -Observation $obs -Rule $script:rule
    $r.Factor | Should -Be 0.5
    $r.Clamped | Should -BeTrue
    $r.MedianRatio | Should -Be 0.2
  }
  It 'groups by tier and VM family' {
    $obs = @(
      Get-TestObservation -Tier medium
      Get-TestObservation -Tier heavy
      Get-TestObservation -Tier medium -VmSize Standard_D8as_v5 -Family D
    )
    @(Get-SizingCalibration -Observation $obs -Rule $script:rule).Count | Should -Be 3
  }
  It 'returns nothing for no observations' {
    Get-SizingCalibration -Observation @() -Rule $script:rule | Should -BeNullOrEmpty
  }
}

Describe 'Search-BrainKnowledge' {
  It 'finds catalog entries, rules and docs with the path to cite' {
    $hits = @(Search-BrainKnowledge -Path (Join-Path $script:root 'knowledge') -Query 'workload tiers sizing prior')
    $hits.Ref | Should -Contain 'knowledge/rules/workload-tiers.json@v1'
    (Search-BrainKnowledge -Path (Join-Path $script:root 'knowledge') -Query 'teams')[0].Ref | Should -Be 'knowledge/catalog/apps.json#microsoft/teams/2'
  }
  It 'matches whole words, not parts of words' {
    $hits = @(Search-BrainKnowledge -Path (Join-Path $script:root 'knowledge') -Query 'media')
    $hits.Ref | Should -Not -Contain 'knowledge/rules/calibration.json@v1'
  }
  It 'returns nothing for an empty query' {
    Search-BrainKnowledge -Path (Join-Path $script:root 'knowledge') -Query '?' | Should -BeNullOrEmpty
  }
}

Describe 'Test-KbLeaks.ps1' {
  # The brain's guard over the family knowledge base (docs/knowledge/ and llms.txt).
  BeforeAll {
    function New-TestKb {
      $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
      Copy-Item -Recurse (Join-Path $script:root 'docs') (Join-Path $dir 'docs')
      Copy-Item (Join-Path $script:root 'llms.txt') $dir
      $dir
    }
    $script:kbLeaks = Join-Path $script:root 'scripts/Test-KbLeaks.ps1'
  }
  It 'passes on the repo as it is' {
    & pwsh -NoProfile -File $script:kbLeaks | Out-Null
    $LASTEXITCODE | Should -Be 0
  }
  It 'fails on a <Kind> in a KB page' -ForEach @(
    @{ Kind = 'guid'; Text = 'tenant 3fa85f64-5717-4562-b3fc-2c963f66afa6' }
    @{ Kind = 'unc-path'; Text = 'profiles on \\fs01\profiles$' }
    @{ Kind = 'machine-name'; Text = 'seen on DESKTOP-7Q2K9LM' }
  ) {
    $kb = New-TestKb
    Add-Content (Join-Path $kb 'docs/knowledge/fslogix/README.md') "`n$Text"
    $out = & pwsh -NoProfile -File $script:kbLeaks -Path $kb
    $LASTEXITCODE | Should -Be 1
    ($out -join "`n") | Should -Match "sensitive:$Kind"
  }
  It 'fails on a denylisted name in an organization fork' {
    $kb = New-TestKb
    New-Item -ItemType Directory (Join-Path $kb 'knowledge') | Out-Null
    $sha = [System.Security.Cryptography.SHA256]::Create()
    [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('northwind traders'))).ToLowerInvariant() |
      Set-Content (Join-Path $kb 'knowledge/denylist.sha256')
    Add-Content (Join-Path $kb 'docs/knowledge/troubleshooting/known-errors.yaml') '# seen at Northwind Traders'
    & pwsh -NoProfile -File $script:kbLeaks -Path $kb | Out-Null
    $LASTEXITCODE | Should -Be 1
  }
}

Describe 'Entry points' {
  It '<_> carries the project notice' -ForEach @('scripts/Test-Knowledge.ps1', 'scripts/Find-BrainKnowledge.ps1', 'scripts/AvdBrain.psm1', 'scripts/Test-KbLeaks.ps1') {
    Get-Content (Join-Path $script:root $_) -Raw | Should -Match 'Personal project, not for production use'
  }
}
