# The organizational second brain (docs/knowledge-spec.md): checks on the knowledge in knowledge/,
# app resolution, sizing calibration and search. Every check takes data already read from disk
# and returns findings, so it is tested offline. PowerShell 7 (Test-Json), no modules.
# Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

$script:EngagementIdPattern = '^eng-[0-9]{4}-[0-9]{2}-[a-z0-9]{4}$'

function Get-BrainFinding {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [ValidateSet('Error', 'Warning')] [string] $Severity,
    [Parameter(Mandatory)] [string] $Check,
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $Message
  )
  [pscustomobject]@{ Severity = $Severity; Check = $Check; Path = $Path; Message = $Message }
}

function Get-BrainProperty {
  # Optional properties: $null when absent, without tripping strict mode in callers.
  param($Object, [string] $Name)
  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) { return $Object[$Name] }
  $p = $Object.PSObject.Properties[$Name]
  if ($p) { $p.Value } else { $null }
}

function Get-BrainSensitiveText {
  # Finds text that must not be in the brain (spec §5): email addresses and UPNs, IPv4 addresses
  # outside the documentation ranges, non-placeholder GUIDs, UNC paths, default Windows machine
  # names, and phrases whose SHA-256 is on the denylist. Matches are masked in the message.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
    [Parameter(Mandatory)] [string] $Path,
    [string[]] $DenyHash = @()
  )
  $deny = [System.Collections.Generic.HashSet[string]]::new([string[]]@($DenyHash | ForEach-Object { $_.ToLowerInvariant() }))
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $lines = $Text -split "`r?`n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $where = "${Path}:$($i + 1)"
    $hits = @()

    foreach ($m in [regex]::Matches($line, '[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}')) {
      if ($m.Value -notmatch '@example\.(com|org|net)$') { $hits += , @('email-or-upn', $m.Value) }
    }
    foreach ($m in [regex]::Matches($line, '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])')) {
      $octets = $m.Value -split '\.' | ForEach-Object { [int]$_ }
      if (@($octets | Where-Object { $_ -gt 255 }).Count) { continue }
      $doc = $m.Value -match '^(0\.0\.0\.0|127\.|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)'
      if (-not $doc) { $hits += , @('ip-address', $m.Value) }
    }
    foreach ($m in [regex]::Matches($line, '(?i)(?<![0-9a-f])[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?![0-9a-f])')) {
      if ($m.Value -notmatch '^[01-]+$') { $hits += , @('guid', $m.Value) }
    }
    foreach ($m in [regex]::Matches($line, '(?<![A-Za-z0-9])\\{2,4}[A-Za-z0-9][A-Za-z0-9._-]*\\{1,2}[A-Za-z0-9$._-]+')) {
      $hits += , @('unc-path', $m.Value)
    }
    foreach ($m in [regex]::Matches($line, '\b(?:DESKTOP|LAPTOP|WIN)-[A-Z0-9]{6,}\b')) {
      $hits += , @('machine-name', $m.Value)
    }
    if ($deny.Count) {
      $words = @([regex]::Matches($line.ToLowerInvariant(), "[a-z0-9][a-z0-9&'.-]*") | ForEach-Object { $_.Value.TrimEnd('.') })
      for ($w = 0; $w -lt $words.Count; $w++) {
        for ($n = 1; $n -le 3 -and $w + $n -le $words.Count; $n++) {
          $phrase = $words[$w..($w + $n - 1)] -join ' '
          $hash = [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($phrase))).ToLowerInvariant()
          if ($deny.Contains($hash)) { $hits += , @('denylisted-name', $null) }
        }
      }
    }

    foreach ($h in $hits) {
      $shown = if ($h[1]) { $h[1].Substring(0, [Math]::Min(3, $h[1].Length)) + '***' } else { 'a phrase on the denylist' }
      Get-BrainFinding -Severity Error -Check "sensitive:$($h[0])" -Path $where -Message "Looks like customer data ($($h[0]): $shown). Generalize it or remove it."
    }
  }
}

function Test-BrainCatalog {
  # Catalog rules beyond the schema (spec §5, §6, §8).
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Catalog,
    [Parameter(Mandatory)] [ValidateSet('public', 'organization')] [string] $Scope,
    [string[]] $EngagementId = @(),
    [string] $Path = 'knowledge/catalog/apps.json',
    [datetime] $Today = (Get-Date),
    [int] $StaleAfterDays = 365
  )
  $seen = @{}
  $patterns = @{}
  foreach ($e in @($Catalog.entries)) {
    $at = "$Path#$($e.id)"
    if ($seen.ContainsKey($e.id)) { Get-BrainFinding Error 'catalog:duplicate-id' $at "Duplicate catalog ID '$($e.id)'." }
    $seen[$e.id] = $true

    foreach ($p in @($e.match)) {
      $key = $p.ToLowerInvariant()
      if ($patterns.ContainsKey($key) -and $patterns[$key] -ne $e.id) {
        Get-BrainFinding Error 'catalog:ambiguous-match' $at "Match pattern '$p' is also on '$($patterns[$key])', so an inventory name could resolve to either."
      }
      $patterns[$key] = $e.id
    }

    if ($e.scope -eq 'customer-lob') {
      Get-BrainFinding Error 'catalog:customer-lob' $at "A customer's own application is customer data. Keep it in the engagement's overrides, not in the brain."
    }

    $evidence = @($e.evidence)
    if ($e.multiSession -ne 'unknown' -and $evidence.Count -eq 0) {
      Get-BrainFinding Error 'catalog:verdict-without-evidence' $at "multiSession '$($e.multiSession)' needs evidence (a document, a pilot or an engagement)."
    }
    if ($e.source -eq 'llm') {
      if (-not (Get-BrainProperty $e 'llm')) {
        Get-BrainFinding Error 'catalog:llm-metadata' $at 'An entry the model wrote records the model, prompt version and date (llm).'
      }
      if ($e.multiSession -ne 'unknown' -and -not (Get-BrainProperty $e 'reviewedBy')) {
        Get-BrainFinding Error 'catalog:llm-verdict-unreviewed' $at 'The model never decides: a verdict on an entry it wrote needs reviewedBy.'
      }
    }

    foreach ($ev in $evidence) {
      if ($ev.kind -eq 'doc') {
        if ($ev.ref -notmatch '^https://') { Get-BrainFinding Error 'catalog:doc-ref' $at "Document evidence must be an https URL, not '$($ev.ref)'." }
      }
      elseif ($Scope -eq 'public') {
        Get-BrainFinding Error 'scope:public-engagement-trail' $at "The public brain cites documents only; '$($ev.kind)' evidence points at an engagement."
      }
      elseif ($ev.ref -notin $EngagementId) {
        Get-BrainFinding Error 'ref:unknown-engagement' $at "Evidence cites '$($ev.ref)', which has no record in knowledge/engagements/."
      }
    }

    $verified = [datetime]::MinValue
    if ([datetime]::TryParse([string]$e.lastVerified, [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$verified)) {
      if (($Today - $verified).TotalDays -gt $StaleAfterDays) {
        Get-BrainFinding Warning 'catalog:stale' $at "Last verified $($e.lastVerified), more than $StaleAfterDays days ago."
      }
    }
    else { Get-BrainFinding Error 'catalog:date' $at "lastVerified '$($e.lastVerified)' is not a date." }
  }
}

function Test-BrainRule {
  # A rule's ID matches its file, and its latest history entry is its current version (spec §8).
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Rule,
    [Parameter(Mandatory)] [string] $Path
  )
  $name = [IO.Path]::GetFileNameWithoutExtension($Path)
  if ($Rule.id -ne $name) { Get-BrainFinding Error 'rule:file-name' $Path "Rule ID '$($Rule.id)' doesn't match the file name '$name'." }
  $versions = @($Rule.history | ForEach-Object { [int]$_.version })
  $sorted = @($versions | Sort-Object)
  if (($versions -join ',') -ne ($sorted -join ',') -or @($versions | Select-Object -Unique).Count -ne $versions.Count) {
    Get-BrainFinding Error 'rule:history-order' $Path 'History versions must be unique and in ascending order.'
  }
  if ($versions.Count -and $sorted[-1] -ne [int]$Rule.version) {
    Get-BrainFinding Error 'rule:history-version' $Path "Version $($Rule.version) has no history entry (latest is $($sorted[-1])). Every change records its reason."
  }
}

function Test-BrainCalibration {
  # Observations are an engagement trail: none in the public brain, and each one cites a known
  # engagement and a VM family that matches its size.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Calibration,
    [Parameter(Mandatory)] [ValidateSet('public', 'organization')] [string] $Scope,
    [string[]] $EngagementId = @(),
    [string] $Path = 'knowledge/calibration/sizing.json'
  )
  $obs = @($Calibration.observations)
  if ($Scope -eq 'public' -and $obs.Count) {
    Get-BrainFinding Error 'scope:public-engagement-trail' $Path "The public brain holds no calibration observations ($($obs.Count) found). They belong in an organization fork."
    return
  }
  for ($i = 0; $i -lt $obs.Count; $i++) {
    $o = $obs[$i]
    $at = "$Path#observations[$i]"
    if ($o.engagement -notin $EngagementId) {
      Get-BrainFinding Error 'ref:unknown-engagement' $at "Observation cites '$($o.engagement)', which has no record in knowledge/engagements/."
    }
    if ($o.vmSize -match '^Standard_([A-Z]+)\d') {
      if ($Matches[1] -ne $o.vmFamily) {
        Get-BrainFinding Error 'calibration:vm-family' $at "vmFamily '$($o.vmFamily)' doesn't match $($o.vmSize) ('$($Matches[1])')."
      }
    }
  }
}

function Test-BrainEngagement {
  # An engagement record: pseudonymous ID matching its file, only in an organization brain, and a
  # closed engagement has finished its harvest (spec §6).
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Engagement,
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [ValidateSet('public', 'organization')] [string] $Scope,
    [string[]] $CatalogId = @(),
    [string] $RepoRoot
  )
  if ($Scope -eq 'public') {
    Get-BrainFinding Error 'scope:public-engagement-trail' $Path 'Engagement records belong in an organization fork, never in the public brain.'
  }
  $name = [IO.Path]::GetFileNameWithoutExtension($Path)
  if ($Engagement.id -ne $name) { Get-BrainFinding Error 'engagement:file-name' $Path "Engagement ID '$($Engagement.id)' doesn't match the file name '$name'." }

  $harvest = $Engagement.harvest
  if ($Engagement.status -eq 'closed' -and -not $harvest.done) {
    Get-BrainFinding Error 'engagement:not-harvested' $Path 'A closed engagement must finish its harvest: every engagement leaves the brain better.'
  }
  if ($harvest.done -and (-not (Get-BrainProperty $harvest 'date') -or -not (Get-BrainProperty $harvest 'by'))) {
    Get-BrainFinding Error 'engagement:harvest-record' $Path 'A finished harvest records its date and who reviewed it (by).'
  }
  foreach ($id in @(Get-BrainProperty $harvest 'catalogEntries')) {
    if ($id -and $id -notin $CatalogId) { Get-BrainFinding Error 'ref:unknown-catalog-entry' $Path "The harvest lists catalog entry '$id', which isn't in the catalog." }
  }
  if ($RepoRoot) {
    foreach ($lesson in @(Get-BrainProperty $harvest 'lessons')) {
      if ($lesson -and -not (Test-Path (Join-Path $RepoRoot $lesson))) {
        Get-BrainFinding Error 'ref:missing-lesson' $Path "The harvest lists lesson '$lesson', which doesn't exist."
      }
    }
  }
}

function Test-BrainJson {
  # Schema validation with the built-in Test-Json. Returns the parsed document, or findings.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $File,
    [Parameter(Mandatory)] [string] $SchemaFile,
    [Parameter(Mandatory)] [string] $Display
  )
  $text = Get-Content -LiteralPath $File -Raw
  $errs = $null
  $ok = $false
  try { $ok = Test-Json -Json $text -SchemaFile $SchemaFile -ErrorAction SilentlyContinue -ErrorVariable errs }
  catch { $errs = @($_) }
  if (-not $ok) {
    $detail = (@($errs) | ForEach-Object { $_.Exception.Message -replace '\s+', ' ' } | Select-Object -First 3) -join ' | '
    return [pscustomobject]@{ Document = $null; Findings = @(Get-BrainFinding Error 'schema' $Display "Doesn't validate against $(Split-Path $SchemaFile -Leaf): $detail") }
  }
  [pscustomobject]@{ Document = ($text | ConvertFrom-Json); Findings = @() }
}

function Test-BrainKnowledge {
  # Every check over a brain folder (spec §8). Returns findings; errors fail CI, warnings don't.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Path,
    [datetime] $Today = (Get-Date)
  )
  $brain = (Resolve-Path -LiteralPath $Path).Path
  $repoRoot = Split-Path $brain -Parent
  $schemas = Join-Path $brain 'schemas'
  $rel = { param($f) [IO.Path]::GetRelativePath($repoRoot, $f) -replace '\\', '/' }

  $cfg = Test-BrainJson -File (Join-Path $brain 'knowledge.json') -SchemaFile (Join-Path $schemas 'knowledge.schema.json') -Display (& $rel (Join-Path $brain 'knowledge.json'))
  $cfg.Findings
  if (-not $cfg.Document) { return }
  $scope = $cfg.Document.scope
  $stale = if (Get-BrainProperty $cfg.Document 'staleAfterDays') { [int]$cfg.Document.staleAfterDays } else { 365 }

  # Engagements first: everything else cross-references them.
  $engagements = @()
  foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $brain 'engagements') -Filter *.json -File -ErrorAction SilentlyContinue)) {
    $r = Test-BrainJson -File $f.FullName -SchemaFile (Join-Path $schemas 'engagement.schema.json') -Display (& $rel $f.FullName)
    $r.Findings
    if ($r.Document) { $engagements += [pscustomobject]@{ File = $f.FullName; Doc = $r.Document } }
  }
  $engagementIds = @($engagements | ForEach-Object { $_.Doc.id })
  foreach ($dup in @($engagementIds | Group-Object | Where-Object Count -gt 1)) {
    Get-BrainFinding Error 'engagement:duplicate-id' 'knowledge/engagements' "Duplicate engagement ID '$($dup.Name)'."
  }

  $catalogIds = @()
  $catalogFile = Join-Path $brain 'catalog/apps.json'
  $r = Test-BrainJson -File $catalogFile -SchemaFile (Join-Path $schemas 'app-catalog.schema.json') -Display (& $rel $catalogFile)
  $r.Findings
  if ($r.Document) {
    $catalogIds = @($r.Document.entries | ForEach-Object { $_.id })
    Test-BrainCatalog -Catalog $r.Document -Scope $scope -EngagementId $engagementIds -Path (& $rel $catalogFile) -Today $Today -StaleAfterDays $stale
  }

  foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $brain 'rules') -Filter *.json -File)) {
    $r = Test-BrainJson -File $f.FullName -SchemaFile (Join-Path $schemas 'rule.schema.json') -Display (& $rel $f.FullName)
    $r.Findings
    if ($r.Document) { Test-BrainRule -Rule $r.Document -Path (& $rel $f.FullName) }
  }

  $calFile = Join-Path $brain 'calibration/sizing.json'
  $r = Test-BrainJson -File $calFile -SchemaFile (Join-Path $schemas 'calibration.schema.json') -Display (& $rel $calFile)
  $r.Findings
  if ($r.Document) { Test-BrainCalibration -Calibration $r.Document -Scope $scope -EngagementId $engagementIds -Path (& $rel $calFile) }

  foreach ($e in $engagements) {
    Test-BrainEngagement -Engagement $e.Doc -Path (& $rel $e.File) -Scope $scope -CatalogId $catalogIds -RepoRoot $repoRoot
  }

  # The denylist itself is a customer list (hashed): only in a private organization fork.
  $denyFile = Join-Path $brain 'denylist.sha256'
  $denyHash = @()
  if (Test-Path -LiteralPath $denyFile) {
    if ($scope -eq 'public') {
      Get-BrainFinding Error 'scope:public-denylist' (& $rel $denyFile) 'The hashed customer denylist belongs in an organization fork only.'
    }
    $denyHash = @(Get-Content -LiteralPath $denyFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9a-fA-F]{64}$' })
  }
  foreach ($f in @(Get-ChildItem -LiteralPath $brain -Recurse -File | Where-Object { $_.FullName -ne $denyFile })) {
    $text = Get-Content -LiteralPath $f.FullName -Raw
    Get-BrainSensitiveText -Text $text -Path (& $rel $f.FullName) -DenyHash $denyHash
    # Estate pseudonyms (C11, C12, C14) link a record to a tenant: knowledge holds buckets, never these.
    foreach ($m in [regex]::Matches($text, '\b(est|hp|st|sub)-[0-9a-f]{8}\b')) {
      Get-BrainFinding Error 'sensitive:estate-pseudonym' (& $rel $f.FullName) "Holds an estate pseudonym ($($m.Value.Substring(0, 3))***). Harvest buckets, never pseudonyms (contracts C14)."
    }
  }
}

function Resolve-BrainApp {
  # Resolves a raw inventory name to a catalog entry (spec §7.1). The most specific match pattern
  # (most literal characters) wins; $null means the app goes to the normalizer and the test plan.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Name,
    [Parameter(Mandatory)] $Catalog
  )
  $best = $null
  foreach ($e in @($Catalog.entries)) {
    foreach ($p in @($e.match)) {
      if ($Name -like $p) {
        $specificity = ($p -replace '[*?]', '').Length
        if (-not $best -or $specificity -gt $best.Specificity) {
          $best = [pscustomobject]@{ Entry = $e; Pattern = $p; Specificity = $specificity }
        }
      }
    }
  }
  if ($best) {
    [pscustomobject]@{
      Name         = $Name
      Id           = $best.Entry.id
      Product      = $best.Entry.product
      MultiSession = $best.Entry.multiSession
      Delivery     = Get-BrainProperty $best.Entry 'delivery'
      Pattern      = $best.Pattern
      Citation     = "knowledge/catalog/apps.json#$($best.Entry.id)"
    }
  }
}

function Get-SizingCalibration {
  # Calibration factors from observations, computed on read and never stored (spec §4). Per tier
  # and VM family: the median of measured/predicted sessions per host, applied only from the
  # rule's minimum number of observations, and clamped.
  [CmdletBinding()]
  param(
    [AllowEmptyCollection()] [object[]] $Observation = @(),
    [Parameter(Mandatory)] $Rule
  )
  $values = $Rule.values
  $min = [int](Get-BrainProperty $values 'minObservations')
  $lo = [double](Get-BrainProperty $values 'minFactor')
  $hi = [double](Get-BrainProperty $values 'maxFactor')
  foreach ($g in @($Observation | Group-Object { "$($_.tier)/$($_.vmFamily)" } | Sort-Object Name)) {
    $ratios = @($g.Group | ForEach-Object { [double]$_.measuredSessionsPerHost / [double]$_.predictedSessionsPerHost } | Sort-Object)
    $n = $ratios.Count
    $median = if ($n % 2) { $ratios[[int][Math]::Floor($n / 2)] } else { ($ratios[$n / 2 - 1] + $ratios[$n / 2]) / 2 }
    $applied = $n -ge $min
    $clamped = [Math]::Min($hi, [Math]::Max($lo, $median))
    [pscustomobject]@{
      Tier         = $g.Group[0].tier
      VmFamily     = $g.Group[0].vmFamily
      Observations = $n
      MedianRatio  = [Math]::Round($median, 3)
      MinRatio     = [Math]::Round($ratios[0], 3)
      MaxRatio     = [Math]::Round($ratios[-1], 3)
      Applied      = $applied
      Clamped      = $applied -and $clamped -ne $median
      Factor       = if ($applied) { [Math]::Round($clamped, 3) } else { 1.0 }
      Rule         = "knowledge/rules/calibration.json@v$($Rule.version)"
    }
  }
}

function Search-BrainKnowledge {
  # Searches the catalog, the rules, the docs here, and optionally a vault and the connected repos'
  # docs, and returns each hit with the path to cite (docs/knowledge-spec.md §7.2). Score is the
  # number of query words found; ties go to hits with the words in their title.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $Query,
    [int] $Top = 10,
    # A customer vault built by vault/avd_second_brain.ps1; searched locally, never committed here.
    [string] $VaultPath,
    # Where Sync-BrainSources.ps1 checked out the connected repos (sources/sources.json).
    [string] $SourcesRoot
  )
  $brain = (Resolve-Path -LiteralPath $Path).Path
  $repoRoot = Split-Path $brain -Parent
  $words = @([regex]::Matches($Query.ToLowerInvariant(), '[a-z0-9]{2,}') | ForEach-Object Value | Select-Object -Unique)
  if (-not $words.Count) { return }

  $items = @()
  $catalog = Get-Content -LiteralPath (Join-Path $brain 'catalog/apps.json') -Raw | ConvertFrom-Json
  foreach ($e in @($catalog.entries)) {
    $items += [pscustomobject]@{
      Kind = 'app'; Ref = "knowledge/catalog/apps.json#$($e.id)"; Title = $e.product
      Text = "$($e.id) $($e.vendor) $($e.product) $(@($e.match) -join ' ') $(Get-BrainProperty $e 'notes')"
      Snippet = "multi-session: $($e.multiSession); delivery: $(Get-BrainProperty $e 'delivery'). $(Get-BrainProperty $e 'notes')"
    }
  }
  foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $brain 'rules') -Filter *.json -File)) {
    $r = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
    $items += [pscustomobject]@{
      Kind = 'rule'; Ref = "knowledge/rules/$($f.Name)@v$($r.version)"; Title = $r.title
      Text = "$($r.id) $($r.title) $(Get-BrainProperty $r 'usedBy') $($r.values | ConvertTo-Json -Depth 10 -Compress)"
      Snippet = "$($r.status), used by: $(Get-BrainProperty $r 'usedBy')"
    }
  }
  $items += @(Get-BrainMarkdownItem -Root $repoRoot -Include @('docs', 'knowledge/runbooks'))
  if ($VaultPath) {
    $items += @(Get-BrainMarkdownItem -Root $VaultPath -Include @('decisions', 'runbooks', 'lessons', 'glossary.md') -Prefix 'vault')
  }
  if ($SourcesRoot -and (Test-Path -LiteralPath $SourcesRoot)) {
    $lock = @{}
    $lockFile = Join-Path $SourcesRoot 'lock.json'
    if (Test-Path -LiteralPath $lockFile) {
      foreach ($l in @((Get-Content -LiteralPath $lockFile -Raw | ConvertFrom-Json).sources)) { $lock[$l.name] = $l.commit }
    }
    foreach ($src in @(Get-BrainSource -Path (Join-Path $repoRoot 'sources/sources.json'))) {
      $dir = Join-Path $SourcesRoot $src.name
      if (-not (Test-Path -LiteralPath $dir)) { continue }
      $prefix = if ($lock[$src.name]) { "$($src.name)@$($lock[$src.name].Substring(0, 7))" } else { $src.name }
      $items += @(Get-BrainMarkdownItem -Root $dir -Include @($src.index) -Prefix $prefix)
    }
  }

  # Whole words, with an optional plural: 'media' doesn't match 'median'.
  $patterns = @($words | ForEach-Object { [regex]::new("\b$([regex]::Escape($_))(s|es)?\b", 'IgnoreCase') })
  $items | ForEach-Object {
    $t = $_.Text
    $score = @($patterns | Where-Object { $_.IsMatch($t) }).Count
    $title = $_.Title
    $inTitle = @($patterns | Where-Object { $_.IsMatch($title) }).Count
    if ($score) {
      $s = $_.Snippet
      if (-not $s) {
        $line = $_.Text -split "`r?`n" | Where-Object { $l = $_; @($patterns | Where-Object { $_.IsMatch($l) }).Count } | Select-Object -First 1
        $s = if ($line) { $line.Trim() } else { '' }
      }
      if ($s.Length -gt 160) { $s = $s.Substring(0, 157) + '...' }
      [pscustomobject]@{ Score = $score; InTitle = $inTitle; Kind = $_.Kind; Ref = $_.Ref; Title = $_.Title; Snippet = $s }
    }
  } | Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'InTitle'; Descending = $true },
    @{ Expression = { $_.Kind -eq 'doc' } }, Ref | Select-Object -First $Top
}

function Get-BrainSource {
  # The connected repositories (sources/sources.json).
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $Path)
  @((Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json).sources)
}

function Get-BrainMarkdownItem {
  # Markdown files under -Root for search: each with a kind, a citable ref and its title.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Root,
    [Parameter(Mandatory)] [string[]] $Include,
    [string] $Prefix
  )
  $rootFull = (Resolve-Path -LiteralPath $Root).Path
  foreach ($inc in $Include) {
    $target = Join-Path $rootFull $inc
    $files = if (Test-Path -LiteralPath $target -PathType Leaf) { @(Get-Item -LiteralPath $target) }
    elseif (Test-Path -LiteralPath $target) { @(Get-ChildItem -LiteralPath $target -Recurse -Filter *.md -File) }
    else { @() }
    foreach ($f in $files) {
      $text = Get-Content -LiteralPath $f.FullName -Raw
      if (-not $text) { continue }
      $rel = [IO.Path]::GetRelativePath($rootFull, $f.FullName) -replace '\\', '/'
      $kind = switch -Regex ("/$rel") { '/lessons/' { 'lesson' } '/decisions/' { 'decision' } '/runbooks/' { 'runbook' } default { 'doc' } }
      [pscustomobject]@{
        Kind = $kind; Ref = if ($Prefix) { "${Prefix}:$rel" } else { $rel }
        Title = ([regex]::Match($text, '(?m)^#\s+(.+)$')).Groups[1].Value; Text = $text; Snippet = $null
      }
    }
  }
}

function Get-SessionHostBucket {
  param([int] $Count)
  if ($Count -le 10) { '1-10' } elseif ($Count -le 50) { '11-50' } elseif ($Count -le 200) { '51-200' } else { '>200' }
}

function Get-VmFamily {
  # Standard_E8as_v5 -> E, Standard_NV12ads_A10_v5 -> NV
  param([string] $VmSize)
  if ($VmSize -match '^Standard_([A-Z]+)\d') { $Matches[1] }
}

function Get-VaultHarvest {
  # Reads a customer vault (vault/avd_second_brain.ps1, fed by avd-current-state packages) and
  # proposes what may cross into the knowledge base (docs/architecture.md, flow 2). Only
  # generalized facts: buckets, VM families, check names, never names, scopes or IDs. Runbooks
  # and lessons are candidates with their sensitive-text count; a person generalizes them.
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $VaultPath)
  $vault = (Resolve-Path -LiteralPath $VaultPath).Path
  $envDirs = @(Get-ChildItem -LiteralPath (Join-Path $vault 'environments') -Directory -ErrorAction SilentlyContinue)

  $hosts = 0; $pools = 0; $types = @{}; $families = @{}; $limits = @{}
  $checks = @{}
  foreach ($env in $envDirs) {
    $snap = Join-Path $env.FullName 'snapshots'
    $inv = Get-ChildItem -LiteralPath $snap -Filter '*-inventory.json' -File -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if ($inv) {
      $facts = Get-Content -LiteralPath $inv.FullName -Raw | ConvertFrom-Json
      foreach ($hp in @($facts.HostPools)) {
        if (-not $hp) { continue }
        $pools++
        $t = if ($hp.HostPoolType) { "$($hp.HostPoolType)" } else { 'Unknown' }
        $types[$t] = 1 + [int]$types[$t]
        if ($hp.MaxSessionLimit) { $limits["$($hp.MaxSessionLimit)"] = 1 + [int]$limits["$($hp.MaxSessionLimit)"] }
      }
      if ($facts.SessionHosts) { foreach ($p in $facts.SessionHosts.PSObject.Properties) { $hosts += [int]$p.Value.Count } }
      if ($facts.VmBySize) {
        foreach ($p in $facts.VmBySize.PSObject.Properties) {
          $fam = Get-VmFamily $p.Name
          if ($fam) { $families[$fam] = [int]$p.Value + [int]$families[$fam] }
        }
      }
    }
    # The latest validation per mode decides what is still failing in this environment.
    $latest = Get-ChildItem -LiteralPath $snap -Filter '*-validation-*.json' -File -ErrorAction SilentlyContinue |
      Group-Object { ($_.BaseName -split '-validation-', 2)[1] } | ForEach-Object { $_.Group | Sort-Object Name | Select-Object -Last 1 }
    foreach ($v in @($latest)) {
      if (-not $v) { continue }
      $seen = @{}
      foreach ($r in @((Get-Content -LiteralPath $v.FullName -Raw | ConvertFrom-Json).Results)) {
        if ($r.Status -notin 'FAIL', 'WARN') { continue }
        $key = "$($r.Category)|$($r.Check)"
        if ($seen[$key]) { continue }
        $seen[$key] = $true
        if (-not $checks[$key]) { $checks[$key] = [pscustomobject]@{ Category = $r.Category; Check = $r.Check; Worst = $r.Status; Environments = 0 } }
        $checks[$key].Environments++
        if ($r.Status -eq 'FAIL') { $checks[$key].Worst = 'FAIL' }
      }
    }
  }

  $candidates = foreach ($kind in 'runbooks', 'lessons') {
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $vault $kind) -Filter *.md -File -ErrorAction SilentlyContinue)) {
      $text = Get-Content -LiteralPath $f.FullName -Raw
      $status = ([regex]::Match($text, '(?m)^status:\s*([a-z-]+)')).Groups[1].Value
      if ($kind -eq 'runbooks' -and $status -ne 'verified') { continue }
      [pscustomobject]@{
        Kind           = $kind.TrimEnd('s')
        Path           = "$kind/$($f.Name)"
        Title          = ([regex]::Match($text, '(?m)^#\s+(.+)$')).Groups[1].Value
        ResolvesChecks = ([regex]::Match($text, '(?m)^resolves-checks:\s*\[(.*?)\]')).Groups[1].Value
        SensitiveLines = @(Get-BrainSensitiveText -Text $text -Path $f.Name).Count
      }
    }
  }

  [pscustomobject]@{
    Environments       = $envDirs.Count
    Estate             = [pscustomobject]@{
      sessionHostsBucket = Get-SessionHostBucket $hosts
      hostPools          = $pools
      hostPoolTypes      = $types
      vmFamilies         = $families
      maxSessionLimits   = $limits
    }
    RecurringChecks    = @($checks.Values | Sort-Object @{ Expression = 'Environments'; Descending = $true }, @{ Expression = { $_.Worst -ne 'FAIL' } }, Check)
    Candidates         = @($candidates)
  }
}

function ConvertFrom-SizingEvidence {
  # Turns measured utilization (contract avd-sizing-evidence/v1, produced by the factory's verify
  # stage and by the landing zone's operations brain) into calibration observations. Sessions per
  # host at the target utilization are extrapolated linearly from the binding resource, so
  # low-load samples are refused (rule calibration: minPeakSessionsPerHost, minBindingUtilization).
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Evidence,
    [Parameter(Mandatory)] $CalibrationRule,
    [Parameter(Mandatory)] [double] $TargetUtilization
  )
  $v = $CalibrationRule.values
  $minPeak = [double](Get-BrainProperty $v 'minPeakSessionsPerHost')
  $minBind = [double](Get-BrainProperty $v 'minBindingUtilization')
  $i = 0
  foreach ($hp in @($Evidence.hostPools)) {
    $at = "hostPools[$i]"; $i++
    $engagement = if (Get-BrainProperty $hp 'engagement') { $hp.engagement } else { Get-BrainProperty $Evidence 'engagement' }
    $tier = Get-BrainProperty $hp 'tier'
    $cpu = [double]$hp.p95CpuPercent / 100
    $mem = [double]$hp.p95MemoryPercent / 100
    $bind = [Math]::Max($cpu, $mem)
    $skip = if (-not $engagement) { 'no engagement: the estate was not designed by the factory, so there is no prediction to calibrate' }
    elseif (-not $tier) { 'no tier: tag the host pool with its persona tier (avdbrain-tier)' }
    elseif ([double]$hp.peakSessionsPerHost -lt $minPeak) { "peak $($hp.peakSessionsPerHost) sessions per host is below $minPeak" }
    elseif ($bind -lt $minBind) { "binding utilization $([Math]::Round($bind * 100))% is below $([Math]::Round($minBind * 100))%: too far to extrapolate" }
    if ($skip) { [pscustomobject]@{ At = $at; Skipped = $skip; Observation = $null }; continue }

    $predicted = if (Get-BrainProperty $hp 'predictedSessionsPerHost') { [double]$hp.predictedSessionsPerHost } else { [double]$hp.maxSessionLimit }
    $wave = Get-BrainProperty $Evidence 'wave'
    [pscustomobject]@{
      At          = $at
      Skipped     = $null
      Observation = [ordered]@{
        engagement               = $engagement
        wave                     = if ($null -ne $wave) { [int]$wave } else { 0 }
        tier                     = $tier
        vmSize                   = $hp.vmSize
        vmFamily                 = Get-VmFamily $hp.vmSize
        predictedSessionsPerHost = $predicted
        measuredSessionsPerHost  = [Math]::Round([double]$hp.peakSessionsPerHost * $TargetUtilization / $bind, 1)
        boundBy                  = if ($cpu -ge $mem) { 'cpu' } else { 'memory' }
        source                   = $Evidence.source
        measuredOn               = $Evidence.period.end
      }
    }
  }
}

function Test-CurrentStateFacts {
  # Contract C11: an avd-current-state-facts/v1 snapshot. Schema first (no field can hold a name),
  # then the guard over the whole text, then references: every check target must be a subscription,
  # host pool or storage account the snapshot describes. Returns the document and the findings.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $File,
    [Parameter(Mandatory)] [string] $SchemaFile
  )
  $display = Split-Path $File -Leaf
  $r = Test-BrainJson -File $File -SchemaFile $SchemaFile -Display $display
  if (-not $r.Document) { return $r }
  $findings = @(Get-BrainSensitiveText -Text (Get-Content -LiteralPath $File -Raw) -Path $display)
  $doc = $r.Document
  $known = @{}
  foreach ($sub in @($doc.subscriptions)) {
    $known[$sub.id] = $true
    foreach ($x in @($sub.hostPools) + @($sub.storageAccounts)) {
      if ($known.ContainsKey($x.id)) { $findings += Get-BrainFinding Error 'facts:pseudonym-collision' $display "Pseudonym $($x.id) names two resources; re-run with a new key." }
      $known[$x.id] = $true
    }
  }
  foreach ($v in @($doc.validations)) {
    foreach ($c in @($v.checks)) {
      $t = Get-BrainProperty $c 'target'
      if ($t -and -not $known.ContainsKey($t)) { $findings += Get-BrainFinding Warning 'facts:unknown-target' $display "Check '$($c.check)' points at $t, which the snapshot doesn't describe." }
    }
  }
  [pscustomobject]@{ Document = $doc; Findings = @($findings) }
}

function Test-SchemaPath {
  # True when a JSON pointer (with * for every array item) names a property the schema defines.
  # Follows local $ref and steps into allOf branches; used to keep the fact register honest.
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)] $Schema,
    [Parameter(Mandatory)] [string] $Pointer
  )
  $node = $Schema
  foreach ($seg in @($Pointer.Trim('/') -split '/')) {
    for ($hop = 0; $hop -lt 10; $hop++) {
      $ref = Get-BrainProperty $node '$ref'
      if (-not $ref) { break }
      $node = $Schema
      foreach ($r in @($ref.TrimStart('#', '/') -split '/')) { $node = Get-BrainProperty $node $r }
    }
    if ($seg -eq '*') { $node = Get-BrainProperty $node 'items' }
    else {
      $next = Get-BrainProperty (Get-BrainProperty $node 'properties') $seg
      if ($null -eq $next) {
        foreach ($branch in @(Get-BrainProperty $node 'allOf')) {
          $next = Get-BrainProperty (Get-BrainProperty $branch 'properties') $seg
          if ($null -ne $next) { break }
        }
      }
      $node = $next
    }
    if ($null -eq $node) { return $false }
  }
  $true
}

function Test-FactRegister {
  # Contract C15: unique IDs, decisions that exist, and every built fact's path resolvable in its
  # contract's schema (SchemaByContract: @{ C11 = <schema object> }). Returns findings.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Register,
    [Parameter(Mandatory)] [hashtable] $SchemaByContract,
    [string] $Path = 'contracts/fact-register.json'
  )
  $decisions = @($Register.decisions | ForEach-Object { $_.id })
  foreach ($dup in @($decisions | Group-Object | Where-Object Count -gt 1)) { Get-BrainFinding Error 'register:duplicate-decision' $Path "Decision '$($dup.Name)' is listed twice." }
  foreach ($dup in @($Register.facts.id | Group-Object | Where-Object Count -gt 1)) { Get-BrainFinding Error 'register:duplicate-fact' $Path "Fact '$($dup.Name)' is listed twice." }
  $prefix = @{ azure = 'c11.'; forensic = 'c12.'; intake = 'intake.'; liquidware = 'liquidware.' }
  foreach ($f in @($Register.facts)) {
    if (-not $f.id.StartsWith($prefix[$f.tier])) { Get-BrainFinding Error 'register:tier-prefix' $Path "Fact '$($f.id)' is tier $($f.tier); its ID must start with '$($prefix[$f.tier])'." }
    foreach ($e in @($f.evidences)) {
      if ($e -notin $decisions) { Get-BrainFinding Error 'register:unknown-decision' $Path "Fact '$($f.id)' evidences '$e', which isn't a decision in the register." }
    }
    if ($f.status -eq 'proposed' -and @($f.evidences).Count) { Get-BrainFinding Error 'register:proposed-evidence' $Path "Fact '$($f.id)' is proposed; it can't evidence a decision until it is specified." }
    if ($f.status -ne 'built') { continue }
    $schema = if ($f.contract) { $SchemaByContract[$f.contract] } else { $null }
    if (-not $f.contract -or -not $f.path) { Get-BrainFinding Error 'register:built-without-contract' $Path "Fact '$($f.id)' is built but names no contract and path." }
    elseif (-not $schema) { Get-BrainFinding Error 'register:no-schema' $Path "Fact '$($f.id)' is built, but there is no schema for $($f.contract)." }
    elseif (-not (Test-SchemaPath -Schema $schema -Pointer $f.path)) { Get-BrainFinding Error 'register:path-not-in-schema' $Path "Fact '$($f.id)': $($f.path) isn't in the $($f.contract) schema." }
  }
}

function Test-TargetState {
  # Contract C14: an avd-target-state/v1 manifest. Schema first, then the guard, then what a schema
  # can't say: every citation is a registered, citable fact that can support that decision, with the
  # subject its grain needs; cited rules exist; pools are consistent. Returns the document and findings.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $File,
    [Parameter(Mandatory)] [string] $SchemaFile,
    [Parameter(Mandatory)] $Register,
    [string] $RulesPath
  )
  $display = Split-Path $File -Leaf
  $r = Test-BrainJson -File $File -SchemaFile $SchemaFile -Display $display
  if (-not $r.Document) { return $r }
  $doc = $r.Document
  $findings = @(Get-BrainSensitiveText -Text (Get-Content -LiteralPath $File -Raw) -Path $display)
  if ($doc.pins.factRegister -ne $Register.version) {
    $findings += Get-BrainFinding Error 'manifest:register-version' $display "Pins fact register v$($doc.pins.factRegister); this register is v$($Register.version)."
  }
  $facts = @{}
  foreach ($f in @($Register.facts)) { $facts[$f.id] = $f }
  $rules = @{}
  if ($RulesPath) {
    foreach ($rf in @(Get-ChildItem -LiteralPath $RulesPath -Filter *.json -File)) { $rd = Get-Content -LiteralPath $rf.FullName -Raw | ConvertFrom-Json; $rules[$rd.id] = [int]$rd.version }
  }
  $needsSubject = @('hostPool', 'group', 'storageAccount', 'host')

  # Every decision in the manifest, with its decision ID from the register.
  $found = @()
  foreach ($d in @($Register.decisions)) {
    $segs = @($d.manifestPath.Trim('/') -split '/')
    $nodes = @([pscustomobject]@{ Node = $doc; Pointer = '' })
    foreach ($s in $segs) {
      $nodes = @(foreach ($n in $nodes) {
          if ($s -eq '*') { $i = 0; foreach ($item in @($n.Node)) { [pscustomobject]@{ Node = $item; Pointer = "$($n.Pointer)/$i" }; $i++ } }
          else { $v = Get-BrainProperty $n.Node $s; if ($null -ne $v) { [pscustomobject]@{ Node = $v; Pointer = "$($n.Pointer)/$s" } } }
        })
    }
    foreach ($n in $nodes) { $found += [pscustomobject]@{ Decision = $d.id; Pointer = $n.Pointer; Value = $n.Node } }
  }
  foreach ($x in $found) {
    foreach ($ref in @($x.Value.evidence)) {
      $id, $subject = $ref -split '@', 2
      $f = $facts[$id]
      if (-not $f) { $findings += Get-BrainFinding Error 'manifest:unknown-fact' $display "$($x.Pointer) cites '$id', which isn't in the fact register."; continue }
      if ($f.status -eq 'proposed') { $findings += Get-BrainFinding Error 'manifest:proposed-fact' $display "$($x.Pointer) cites '$id', which is only proposed." }
      if ($x.Decision -notin @($f.evidences)) { $findings += Get-BrainFinding Error 'manifest:fact-cannot-support' $display "$($x.Pointer) cites '$id', which the register doesn't list as evidence for $($x.Decision)." }
      if ($f.grain -in $needsSubject -and -not $subject) { $findings += Get-BrainFinding Error 'manifest:missing-subject' $display "$($x.Pointer) cites '$id' (grain $($f.grain)) without naming which one (@hp-..., @persona-...)." }
    }
    $rule = Get-BrainProperty $x.Value 'rule'
    if ($rule -and $RulesPath) {
      $rid, $rv = $rule -split '@v', 2
      if (-not $rules.ContainsKey($rid)) { $findings += Get-BrainFinding Error 'manifest:unknown-rule' $display "$($x.Pointer) cites rule '$rid', which isn't in knowledge/rules/." }
      elseif ([int]$rv -gt $rules[$rid]) { $findings += Get-BrainFinding Error 'manifest:future-rule' $display "$($x.Pointer) cites $rule; the newest is v$($rules[$rid])." }
    }
  }

  $ids = @($doc.hostPools | ForEach-Object { $_.id })
  foreach ($dup in @($ids | Group-Object | Where-Object Count -gt 1)) { $findings += Get-BrainFinding Error 'manifest:duplicate-pool' $display "Host pool '$($dup.Name)' is listed twice." }
  foreach ($p in @($doc.hostPools)) {
    if ($p.hosts.value * $p.maxSessions.value -lt $p.peakConcurrent) {
      $findings += Get-BrainFinding Error 'manifest:capacity' $display "$($p.id): $($p.hosts.value) hosts x $($p.maxSessions.value) sessions is below the peak of $($p.peakConcurrent)."
    }
  }
  if ($doc.target.renderer -eq 'lz-cloudnative' -and @($doc.target.gaps).Count) {
    $findings += Get-BrainFinding Error 'manifest:gaps' $display "lz-cloudnative can't express: $(@($doc.target.gaps) -join ', '). Route to another renderer or remove the requirement."
  }
  [pscustomobject]@{ Document = $doc; Findings = @($findings) }
}

Export-ModuleMember -Function Get-BrainSensitiveText, Test-BrainCatalog, Test-BrainRule, Test-BrainCalibration,
  Test-BrainEngagement, Test-BrainKnowledge, Resolve-BrainApp, Get-SizingCalibration, Search-BrainKnowledge,
  Get-BrainSource, Get-VaultHarvest, ConvertFrom-SizingEvidence, Test-CurrentStateFacts,
  Test-SchemaPath, Test-FactRegister, Test-TargetState
