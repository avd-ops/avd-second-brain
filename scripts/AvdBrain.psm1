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
  # Finds text that must not be in the brain (spec §5): email addresses and UPNs other than the
  # example.com, contoso.com and GitHub noreply placeholders, IPv4 addresses outside the
  # documentation ranges, non-placeholder GUIDs, UNC paths, default Windows machine names, and
  # phrases whose SHA-256 is on the denylist. Matches are masked in the message.
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
      if ($m.Value -notmatch '@(example\.(com|org|net)|contoso\.com|users\.noreply\.github\.com)$') { $hits += , @('email-or-upn', $m.Value) }
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
    # Estate pseudonyms (C11, C12, C14, C18) link a record to a tenant: knowledge holds buckets, never these.
    foreach ($m in [regex]::Matches($text, '\b(est|env|hp|st|sub)-[0-9a-f]{8}\b')) {
      Get-BrainFinding Error 'sensitive:estate-pseudonym' (& $rel $f.FullName) "Holds an estate pseudonym ($($m.Value.Substring(0, 3))***). Harvest buckets, never pseudonyms (contracts C14, C18)."
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

function Get-TargetStateDecision {
  # Every decision in a C14 manifest, with its decision ID from the register (C15) and its JSON pointer.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Manifest,
    [Parameter(Mandatory)] $Register
  )
  foreach ($d in @($Register.decisions)) {
    $segs = @($d.manifestPath.Trim('/') -split '/')
    $nodes = @([pscustomobject]@{ Node = $Manifest; Pointer = '' })
    foreach ($s in $segs) {
      $nodes = @(foreach ($n in $nodes) {
          if ($s -eq '*') { $i = 0; foreach ($item in @($n.Node)) { [pscustomobject]@{ Node = $item; Pointer = "$($n.Pointer)/$i" }; $i++ } }
          else { $v = Get-BrainProperty $n.Node $s; if ($null -ne $v) { [pscustomobject]@{ Node = $v; Pointer = "$($n.Pointer)/$s" } } }
        })
    }
    foreach ($n in $nodes) { [pscustomobject]@{ Decision = $d.id; Pointer = $n.Pointer; Value = $n.Node } }
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

  $found = @(Get-TargetStateDecision -Manifest $doc -Register $Register)
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

# --- Lifecycle record (contract C18): why an environment is built and performs the way it does --
# The brain keeps the why (use cases, decisions with their alternatives and drivers, the events that
# carried them out); avd-swarm records the how (plans and their outcomes, C10). Pure functions over
# a record already read from the vault.

$script:LifecycleTopic = @('identity', 'network', 'region', 'image', 'apps', 'profiles', 'scaling', 'power', 'sizing',
  'security', 'access', 'monitoring', 'backup', 'recovery', 'cost', 'liquidware', 'governance', 'other')
$script:LifecycleChangeKind = @('build', 'configure', 'expand', 'contract', 'fix', 'recover', 'retire', 'drift')

function Get-LifecycleSubjectSet {
  # A subject and every design subject (tp-, persona-) a born or build event mapped onto it.
  param($Record, [string] $Subject)
  $set = @{ $Subject = $true }
  foreach ($e in @($Record.events)) {
    foreach ($m in @(Get-BrainProperty $e 'maps')) { if ($m -and $m.to -eq $Subject) { $set[$m.from] = $true } }
  }
  $set
}

function Test-LifecycleRecord {
  # Contract C18: an avd-lifecycle-record/v1 document. Schema first, then the guard, then what a
  # schema can't say: references resolve, cited facts are registered and citable with the subject
  # their grain needs, cited rules exist, one birth, supersede chains are consistent. Warnings mark
  # the gaps the brain asks a person to fill: a change no decision explains, a decision with no
  # alternatives. Returns the document and the findings.
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
    $findings += Get-BrainFinding Error 'lifecycle:register-version' $display "Pins fact register v$($doc.pins.factRegister); this register is v$($Register.version)."
  }
  $facts = @{}
  foreach ($f in @($Register.facts)) { $facts[$f.id] = $f }
  $registerDecisions = @($Register.decisions | ForEach-Object { $_.id })
  $rules = @{}
  if ($RulesPath) {
    foreach ($rf in @(Get-ChildItem -LiteralPath $RulesPath -Filter *.json -File)) { $rd = Get-Content -LiteralPath $rf.FullName -Raw | ConvertFrom-Json; $rules[$rd.id] = [int]$rd.version }
  }
  $needsSubject = @('hostPool', 'group', 'storageAccount', 'host')

  $useCases = @{}; $decisions = @{}; $events = @{}
  foreach ($kind in @(@{ Items = @($doc.useCases); Map = $useCases; Name = 'Use case' }, @{ Items = @($doc.decisions); Map = $decisions; Name = 'Decision' }, @{ Items = @($doc.events); Map = $events; Name = 'Event' })) {
    foreach ($x in $kind.Items) {
      if ($kind.Map.ContainsKey($x.id)) { $findings += Get-BrainFinding Error 'lifecycle:duplicate-id' $display "$($kind.Name) '$($x.id)' is listed twice." }
      $kind.Map[$x.id] = $x
    }
  }

  $checkRef = {
    param([string] $Where, [string] $Ref)
    if ($Ref -like 'rule:*') {
      if (-not $RulesPath) { return }
      $rid, $rv = $Ref.Substring(5) -split '@v', 2
      if (-not $rules.ContainsKey($rid)) { Get-BrainFinding Error 'lifecycle:unknown-rule' $display "$Where cites rule '$rid', which isn't in knowledge/rules/." }
      elseif ([int]$rv -gt $rules[$rid]) { Get-BrainFinding Error 'lifecycle:future-rule' $display "$Where cites $Ref; the newest is v$($rules[$rid])." }
      return
    }
    if ($Ref -like 'evt-*') {
      if (-not $events.ContainsKey($Ref)) { Get-BrainFinding Error 'lifecycle:unknown-event' $display "$Where cites $Ref, which the record doesn't have." }
      return
    }
    if ($Ref -notmatch '^(c11|c12|intake|liquidware)\.') { return }
    $id, $subject = $Ref -split '@', 2
    $f = $facts[$id]
    if (-not $f) { Get-BrainFinding Error 'lifecycle:unknown-fact' $display "$Where cites '$id', which isn't in the fact register."; return }
    if ($f.status -eq 'proposed') { Get-BrainFinding Error 'lifecycle:proposed-fact' $display "$Where cites '$id', which is only proposed." }
    if ($f.grain -in $needsSubject -and -not $subject) { Get-BrainFinding Error 'lifecycle:missing-subject' $display "$Where cites '$id' (grain $($f.grain)) without naming which one (@hp-..., @tp-...)." }
  }

  foreach ($d in @($doc.decisions)) {
    $where = $d.id
    if ($d.topic -notin $script:LifecycleTopic -and $d.topic -notin $registerDecisions) {
      $findings += Get-BrainFinding Error 'lifecycle:unknown-topic' $display "$where has topic '$($d.topic)', which is neither a lifecycle topic nor a fact register decision."
    }
    foreach ($u in @(Get-BrainProperty $d 'useCases')) { if ($u -and -not $useCases.ContainsKey($u)) { $findings += Get-BrainFinding Error 'lifecycle:unknown-use-case' $display "$where serves $u, which the record doesn't have." } }
    foreach ($ref in @($d.evidence) + @(Get-BrainProperty $d 'watch')) { if ($ref) { $findings += @(& $checkRef $where $ref) } }
    $old = Get-BrainProperty $d 'supersedes'
    if ($old) {
      if (-not $decisions.ContainsKey($old)) { $findings += Get-BrainFinding Error 'lifecycle:unknown-decision' $display "$where supersedes $old, which the record doesn't have." }
      elseif ($decisions[$old].status -ne 'superseded') { $findings += Get-BrainFinding Error 'lifecycle:supersede-status' $display "$where supersedes $old, but $old is still '$($decisions[$old].status)'." }
      elseif ($decisions[$old].date -gt $d.date) { $findings += Get-BrainFinding Error 'lifecycle:supersede-order' $display "$where ($($d.date)) supersedes $old, which is dated later ($($decisions[$old].date))." }
    }
    if ($d.status -eq 'accepted' -and -not @(Get-BrainProperty $d 'alternatives').Where({ $_ }).Count) {
      $findings += Get-BrainFinding Warning 'lifecycle:no-alternatives' $display "$where records no alternative. What else was considered, and why not, is half of why."
    }
  }
  foreach ($old in @($doc.decisions | Where-Object status -eq 'superseded')) {
    if (-not @($doc.decisions | Where-Object { (Get-BrainProperty $_ 'supersedes') -eq $old.id }).Count) {
      $findings += Get-BrainFinding Error 'lifecycle:superseded-by-nothing' $display "$($old.id) is superseded, but no decision supersedes it."
    }
  }

  $born = @($doc.events | Where-Object kind -eq 'born')
  if ($born.Count -ne 1) { $findings += Get-BrainFinding Error 'lifecycle:born' $display "An environment is born once; this record has $($born.Count) born events." }
  elseif (@($doc.events | Where-Object { $_.utc -lt $born[0].utc }).Count) { $findings += Get-BrainFinding Error 'lifecycle:born' $display "Events come before $($born[0].id), the birth." }
  foreach ($e in @($doc.events)) {
    $where = $e.id
    $carried = @(Get-BrainProperty $e 'decisions' | Where-Object { $_ })
    foreach ($id in $carried) {
      if (-not $decisions.ContainsKey($id)) { $findings += Get-BrainFinding Error 'lifecycle:unknown-decision' $display "$where carries out $id, which the record doesn't have." }
      elseif ($decisions[$id].status -eq 'rejected') { $findings += Get-BrainFinding Warning 'lifecycle:rejected-decision-applied' $display "$where carries out $id, which was rejected." }
    }
    foreach ($u in @(Get-BrainProperty $e 'useCases')) { if ($u -and -not $useCases.ContainsKey($u)) { $findings += Get-BrainFinding Error 'lifecycle:unknown-use-case' $display "$where serves $u, which the record doesn't have." } }
    foreach ($ref in @(Get-BrainProperty $e 'evidence') + @(Get-BrainProperty $e 'change' | ForEach-Object { $_.fact })) { if ($ref) { $findings += @(& $checkRef $where $ref) } }
    if ($e.kind -in $script:LifecycleChangeKind -and -not $carried.Count) {
      $findings += Get-BrainFinding Warning 'lifecycle:unexplained-change' $display "$where is a $($e.kind) that no decision explains. Record the decision, or say it was not decided."
    }
  }
  [pscustomobject]@{ Document = $doc; Findings = @($findings) }
}

function Get-LifecycleExplanation {
  # Why is <subject> the way it is: the use cases it serves, the decisions in force about it (with
  # what else was considered and why not), the events that changed it in time order with the
  # decisions they carried out, and the changes nothing explains. Design subjects a born event
  # mapped onto it (tp-01 -> hp-...) count as the same subject. Every item carries its citation.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Record,
    [Parameter(Mandatory)] [string] $Subject,
    [string] $Topic
  )
  $set = Get-LifecycleSubjectSet -Record $Record -Subject $Subject
  $cite = { param($Id) "lifecycle:$($Record.environment)#$Id" }
  $touches = {
    param($Item)
    foreach ($s in @(Get-BrainProperty $Item 'subjects')) { if ($s -and $set.ContainsKey($s)) { return $true } }
    foreach ($c in @(Get-BrainProperty $Item 'change')) { if ($c -and $set.ContainsKey(($c.fact -split '@', 2)[1])) { return $true } }
    $false
  }
  $byId = @{}
  foreach ($d in @($Record.decisions)) { $byId[$d.id] = $d }
  $decisions = @($Record.decisions | Where-Object { (& $touches $_) -or -not @(Get-BrainProperty $_ 'subjects').Where({ $_ }).Count } |
      Where-Object { -not $Topic -or $_.topic -eq $Topic })
  $events = @($Record.events | Where-Object { & $touches $_ } | Sort-Object utc)
  $useCaseIds = @{}
  foreach ($u in @($Record.useCases)) { if (@($u.hostPools | Where-Object { $set.ContainsKey($_) }).Count) { $useCaseIds[$u.id] = $true } }
  foreach ($x in $decisions + $events) { foreach ($u in @(Get-BrainProperty $x 'useCases')) { if ($u) { $useCaseIds[$u] = $true } } }

  [pscustomobject]@{
    Subject     = $Subject
    Aliases     = @($set.Keys | Where-Object { $_ -ne $Subject } | Sort-Object)
    UseCases    = @($Record.useCases | Where-Object { $useCaseIds.ContainsKey($_.id) } | ForEach-Object {
        [pscustomobject]@{ Id = $_.id; Kind = $_.kind; Tier = $_.tier; Users = $_.users; Status = $_.status; Citation = & $cite $_.id } })
    InForce     = @($decisions | Where-Object status -eq 'accepted' | ForEach-Object {
        [pscustomobject]@{ Id = $_.id; Topic = $_.topic; Phase = $_.phase; Chosen = $_.chosen; Alternatives = @(Get-BrainProperty $_ 'alternatives' | Where-Object { $_ })
          Drivers = @($_.drivers); Evidence = @($_.evidence); Supersedes = Get-BrainProperty $_ 'supersedes'; Citation = & $cite $_.id } })
    History     = @($events | ForEach-Object {
        $e = $_
        [pscustomobject]@{ Id = $e.id; Utc = if ($e.utc -is [datetime]) { $e.utc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } else { $e.utc }; Kind = $e.kind; Actor = $e.actor; Outcome = $e.outcome
          Why = @(Get-BrainProperty $e 'decisions' | Where-Object { $_ -and $byId.ContainsKey($_) } | ForEach-Object { [pscustomobject]@{ Id = $_; Topic = $byId[$_].topic; Chosen = $byId[$_].chosen; Status = $byId[$_].status; Citation = & $cite $_ } })
          Run = Get-BrainProperty $e 'run'; Plan = Get-BrainProperty $e 'plan'; Citation = & $cite $e.id } })
    Unexplained = @($events | Where-Object { $_.kind -in $script:LifecycleChangeKind -and -not @(Get-BrainProperty $_ 'decisions').Where({ $_ }).Count } | ForEach-Object { & $cite $_.id })
  }
}

function Get-LifecycleReview {
  # Decisions to revisit: accepted decisions that watch a fact which has changed (Changed: fact
  # references such as c12.group.concurrency.peak@hp-5e6f7a8b, from comparing two C11 snapshots or
  # C12 windows), and decisions whose review date has come. A watch without a subject matches the
  # fact on any subject. Returns one item per decision and reason, with its citation.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Record,
    [string[]] $Changed = @(),
    [string] $AsOf
  )
  foreach ($d in @($Record.decisions | Where-Object status -eq 'accepted')) {
    foreach ($w in @(Get-BrainProperty $d 'watch' | Where-Object { $_ })) {
      $wid, $wsub = $w -split '@', 2
      foreach ($c in $Changed) {
        $cid, $csub = $c -split '@', 2
        if ($cid -eq $wid -and (-not $wsub -or $wsub -eq $csub)) {
          [pscustomobject]@{ Decision = $d.id; Topic = $d.topic; Reason = 'watched-fact-changed'; Fact = $c; Citation = "lifecycle:$($Record.environment)#$($d.id)" }
        }
      }
    }
    $reviewBy = Get-BrainProperty $d 'reviewBy'
    if ($AsOf -and $reviewBy -and $reviewBy -le $AsOf) {
      [pscustomobject]@{ Decision = $d.id; Topic = $d.topic; Reason = 'review-date'; Fact = $null; Citation = "lifecycle:$($Record.environment)#$($d.id)" }
    }
  }
}

function ConvertFrom-TargetStateDecision {
  # The design decisions of an approved C14 manifest as C18 decisions, so an environment's record
  # starts at its birth with the why the factory worked out. A decision the manifest gives no
  # alternatives keeps a Test-LifecycleRecord warning until a person adds them. Call it only for a manifest with a
  # matching approval (C14); the approval is what makes these decisions 'accepted'. A manifest's
  # alternatives (what the design ruled out, and why) come across as they are.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Manifest,
    [Parameter(Mandatory)] [ValidatePattern('^[0-9a-f]{64}$')] [string] $ManifestSha256,
    [Parameter(Mandatory)] $Register,
    [int] $FirstNumber = 1
  )
  $n = $FirstNumber
  $sha = $ManifestSha256.Substring(0, 12)
  # ConvertFrom-Json turns an ISO time into a DateTime; take the date either way.
  $g = $Manifest.generatedUtc
  $date = if ($g -is [datetime]) { $g.ToUniversalTime().ToString('yyyy-MM-dd') } else { ([string]$g).Substring(0, 10) }
  foreach ($x in @(Get-TargetStateDecision -Manifest $Manifest -Register $Register)) {
    $v = $x.Value
    $subjects = @()
    if ($x.Pointer -match '^/hostPools/(\d+)/') { $subjects = @($Manifest.hostPools[[int]$Matches[1]].id) }
    $rule = Get-BrainProperty $v 'rule'
    $override = Get-BrainProperty $v 'override'
    $drivers = @('evidence')
    if ($rule) { $drivers += 'rule' }
    if ($override) { $drivers += @{ 'customer-requirement' = 'customer-requirement'; policy = 'policy'; cost = 'cost'; risk = 'risk'; other = 'other' }[$override.reason] }
    $evidence = @("manifest:$sha#$($x.Decision)")
    if ($rule) { $evidence += "rule:$rule" }
    $evidence += @($v.evidence)
    $d = [ordered]@{
      id = 'dec-{0:d4}' -f $n; date = $date; phase = 'design'; topic = $x.Decision
      chosen = $v.value; drivers = @($drivers | Select-Object -Unique); evidence = @($evidence | Select-Object -First 20)
      confidence = $v.confidence; status = 'accepted'; source = 'target-state'
      decidedBy = if ($rule -and -not $override) { 'factory-rule' } else { 'approver' }
    }
    if ($subjects.Count) { $d.subjects = $subjects }
    $alternatives = @(Get-BrainProperty $v 'alternatives' | Where-Object { $_ })
    if ($alternatives.Count) { $d.alternatives = $alternatives }
    $note = Get-BrainProperty $v 'note'
    if ($note) { $d.note = $note }
    [pscustomobject]$d
    $n++
  }
}

# --- Assessment method (docs/assess-spec.md, contracts C19 to C21) --------------------------------
# avd-assess publishes the method (C20: index.json and method.json); avd-current-state runs it and
# writes a report (C21). These take the parsed documents and return findings, so they run offline.

function Test-AssessMethod {
  # Contract C20: avd-assess's index.json and method.json. Schemas first, then the guard over the
  # text that is ours (claims, observations, titles), then what a schema can't say: every claim and
  # gap cited exists, every fact is registered (built for a check, at least specified for readiness),
  # every decision is in the register, and readiness agrees with the register's decidableFrom.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $IndexFile,
    [Parameter(Mandatory)] [string] $MethodFile,
    [Parameter(Mandatory)] [string] $SchemaPath,
    [Parameter(Mandatory)] $Register
  )
  $ix = Test-BrainJson -File $IndexFile -SchemaFile (Join-Path $SchemaPath 'assess-index.schema.json') -Display 'index.json'
  $me = Test-BrainJson -File $MethodFile -SchemaFile (Join-Path $SchemaPath 'assess-method.schema.json') -Display 'method.json'
  $findings = @($ix.Findings) + @($me.Findings)
  if (-not $ix.Document -or -not $me.Document) { return [pscustomobject]@{ Index = $ix.Document; Method = $me.Document; Findings = $findings } }
  $index = $ix.Document; $method = $me.Document

  # Source IDs (an APRL GUID is a public ID) are pattern-checked by the schema; the guard reads our words.
  $words = @(foreach ($r in @($index.references)) { $r.title; Get-BrainProperty $r 'notes'; foreach ($c in @($r.claims)) { $c.says } }) +
  @(foreach ($o in @($index.observations)) { $o.observed }) + @(foreach ($c in @($method.checks)) { $c.title })
  $findings += @(Get-BrainSensitiveText -Text (@($words | Where-Object { $_ }) -join "`n") -Path 'avd-assess')

  $cites = @{}
  foreach ($dup in @($index.references.id | Group-Object | Where-Object Count -gt 1)) { $findings += Get-BrainFinding Error 'index:duplicate-reference' 'index.json' "Reference '$($dup.Name)' is listed twice." }
  foreach ($r in @($index.references)) {
    foreach ($dup in @($r.claims.id | Group-Object | Where-Object Count -gt 1)) { $findings += Get-BrainFinding Error 'index:duplicate-claim' 'index.json' "ref:$($r.id) lists claim '$($dup.Name)' twice." }
    foreach ($c in @($r.claims)) { $cites["ref:$($r.id)#$($c.id)"] = $true }
  }
  foreach ($g in @($index.gaps)) { $cites["gap:$($g.id)"] = $true }
  foreach ($o in @($index.observations)) {
    if (-not $cites.ContainsKey($o.claim)) { $findings += Get-BrainFinding Error 'index:unknown-claim' 'index.json' "Observation '$($o.id)' tests $($o.claim), which no reference has." }
  }

  $facts = @{}; foreach ($f in @($Register.facts)) { $facts[$f.id] = $f }
  $decisions = @{}; foreach ($d in @($Register.decisions)) { $decisions[$d.id] = $d }
  if ($method.factRegister -ne $Register.version) {
    $findings += Get-BrainFinding Error 'method:register-version' 'method.json' "Uses fact register v$($method.factRegister); this register is v$($Register.version)."
  }
  $checkCite = { param($Where, $Ref) if (-not $cites.ContainsKey($Ref)) { Get-BrainFinding Error 'method:unknown-claim' 'method.json' "$Where cites $Ref, which the index doesn't have." } }
  $checkFact = {
    param($Where, $Id, [string[]] $Allowed)
    $f = $facts[$Id]
    if (-not $f) { Get-BrainFinding Error 'method:unknown-fact' 'method.json' "$Where uses '$Id', which isn't in the fact register." }
    elseif ($f.status -notin $Allowed) { Get-BrainFinding Error 'method:fact-not-citable' 'method.json' "$Where uses '$Id', which is $($f.status); it needs to be $($Allowed -join ' or ')." }
  }

  foreach ($row in @($method.collection)) {
    $findings += @(& $checkFact "collection $($row.fact)" $row.fact @('built', 'specified'))
    foreach ($c in @($row.claims)) { $findings += @(& $checkCite "collection $($row.fact)" $c) }
    $f = $facts[$row.fact]
    if ($f -and (($row.from -eq 'intake') -ne ($f.tier -eq 'intake'))) { $findings += Get-BrainFinding Error 'method:collection-source' 'method.json' "$($row.fact) is tier $($f.tier); it can't come from $($row.from)." }
  }
  foreach ($dup in @($method.checks.id | Group-Object | Where-Object Count -gt 1)) { $findings += Get-BrainFinding Error 'method:duplicate-check' 'method.json' "Check '$($dup.Name)' is listed twice." }
  foreach ($c in @($method.checks)) {
    foreach ($ref in @($c.claims)) { $findings += @(& $checkCite $c.id $ref) }
    foreach ($id in @($c.facts)) { $findings += @(& $checkFact $c.id $id @('built')) }
    foreach ($d in @($c.informs)) { if (-not $decisions.ContainsKey($d)) { $findings += Get-BrainFinding Error 'method:unknown-decision' 'method.json' "$($c.id) informs '$d', which isn't a decision in the register." } }
  }
  foreach ($dup in @($method.readiness.decision | Group-Object | Where-Object Count -gt 1)) { $findings += Get-BrainFinding Error 'method:duplicate-readiness' 'method.json' "Decision '$($dup.Name)' has two readiness rows." }
  foreach ($d in @($Register.decisions)) {
    if ($d.id -notin @($method.readiness.decision)) { $findings += Get-BrainFinding Error 'method:readiness-missing' 'method.json' "Decision '$($d.id)' has no readiness row." }
  }
  $needTier = @{ 'decidable' = 'azure'; 'decidable-with-intake' = 'intake'; 'needs-measurement' = 'forensic' }
  foreach ($row in @($method.readiness)) {
    $d = $decisions[$row.decision]
    if (-not $d) { $findings += Get-BrainFinding Error 'method:unknown-decision' 'method.json' "Readiness row '$($row.decision)' isn't a decision in the register."; continue }
    foreach ($c in @($row.claims)) { $findings += @(& $checkCite "readiness $($row.decision)" $c) }
    foreach ($id in @($row.facts)) {
      $findings += @(& $checkFact "readiness $($row.decision)" $id @('built', 'specified'))
      if ($facts[$id] -and $row.decision -notin @($facts[$id].evidences)) { $findings += Get-BrainFinding Error 'method:fact-cannot-support' 'method.json' "Readiness $($row.decision) uses '$id', which the register doesn't list as evidence for it." }
    }
    $tier = $needTier[$row.readiness]
    if ($tier -notin @($d.decidableFrom)) { $findings += Get-BrainFinding Error 'method:readiness-register' 'method.json' "$($row.decision) is $($row.readiness), but the register says it is decidable only from $(@($d.decidableFrom) -join ', ')." }
    elseif (-not @($row.facts | Where-Object { $facts[$_] -and $facts[$_].tier -eq $tier }).Count) { $findings += Get-BrainFinding Error 'method:readiness-facts' 'method.json' "$($row.decision) is $($row.readiness) but names no $tier fact." }
  }
  [pscustomobject]@{ Index = $index; Method = $method; Findings = @($findings) }
}

function Get-AssessScore {
  # The method's scoring (severity-weighted/v1) over a report's results: per pillar, the passing
  # severity weight over the assessed weight (warn counts warnFactor), and coverage, the share of
  # checks that aren't unknown or not-applicable. A pillar with nothing assessed scores null. Only builds data.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Method,
    [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Result
  )
  $outcome = @{}; foreach ($r in $Result) { $outcome[$r.check] = $r.outcome }
  $s = $Method.scoring
  foreach ($g in @($Method.checks | Group-Object pillar | Sort-Object Name)) {
    $assessed = 0; $notApplicable = 0; $weight = 0.0; $passed = 0.0
    foreach ($c in $g.Group) {
      $o = $outcome[$c.id]
      if ($o -eq 'not-applicable') { $notApplicable++; continue }
      if (-not $o -or $o -eq 'unknown') { continue }
      $w = [double](Get-BrainProperty $s.weights $c.severity)
      $assessed++; $weight += $w
      if ($o -eq 'pass') { $passed += $w } elseif ($o -eq 'warn') { $passed += $w * $s.warnFactor }
    }
    $denom = $g.Count - $notApplicable
    [pscustomobject]@{
      pillar = $g.Name; checks = $g.Count; assessed = $assessed
      score = if ($weight) { [Math]::Round($passed / $weight, 3) } else { $null }
      coverage = if ($denom -gt 0) { [Math]::Round($assessed / $denom, 3) } else { 0 }
    }
  }
}

function Test-AssessmentReport {
  # Contract C21: an avd-assessment/v1 report against the method it pins. Schema first, then the
  # guard, then: the pins match, every check has exactly one row with only that check's facts, each
  # row's outcome is its subjects' worst, the pillars recompute, and every decision's status fits
  # its readiness and whether intake was answered.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $File,
    [Parameter(Mandatory)] [string] $SchemaFile,
    [Parameter(Mandatory)] $Method,
    [string] $MethodSha256,
    [Parameter(Mandatory)] $Register
  )
  $display = Split-Path $File -Leaf
  $r = Test-BrainJson -File $File -SchemaFile $SchemaFile -Display $display
  if (-not $r.Document) { return $r }
  $doc = $r.Document
  $findings = @(Get-BrainSensitiveText -Text (Get-Content -LiteralPath $File -Raw) -Path $display)
  if ($doc.method.version -ne $Method.version) { $findings += Get-BrainFinding Error 'report:method-version' $display "Ran method v$($doc.method.version); this method is v$($Method.version)." }
  if ($MethodSha256 -and $doc.method.sha256 -ne $MethodSha256) { $findings += Get-BrainFinding Error 'report:method-hash' $display "Pins method.json $($doc.method.sha256.Substring(0, 12)); the copy given is $($MethodSha256.Substring(0, 12))." }
  if ($doc.method.factRegister -ne $Register.version) { $findings += Get-BrainFinding Error 'report:register-version' $display "Uses fact register v$($doc.method.factRegister); this register is v$($Register.version)." }

  $checks = @{}; foreach ($c in @($Method.checks)) { $checks[$c.id] = $c }
  $rank = @{ gap = 3; warn = 2; unknown = 1; pass = 0; 'not-applicable' = -1 }
  foreach ($dup in @($doc.results.check | Group-Object | Where-Object Count -gt 1)) { $findings += Get-BrainFinding Error 'report:duplicate-check' $display "Check '$($dup.Name)' has two rows." }
  foreach ($id in $checks.Keys) { if ($id -notin @($doc.results.check)) { $findings += Get-BrainFinding Error 'report:missing-check' $display "Check '$id' has no row." } }
  foreach ($row in @($doc.results)) {
    $c = $checks[$row.check]
    if (-not $c) { $findings += Get-BrainFinding Error 'report:unknown-check' $display "Row '$($row.check)' isn't a check in method v$($Method.version)."; continue }
    foreach ($f in @($row.facts)) { if ($f -notin @($c.facts)) { $findings += Get-BrainFinding Error 'report:fact-not-in-check' $display "$($row.check) lists '$f', which the check doesn't use." } }
    $subjects = @($row.subjects)
    $worst = if ($row.outcome -eq 'not-applicable' -and -not $subjects.Count) { 'not-applicable' } else { 'unknown' }
    if ($subjects.Count) { $worst = ($subjects.outcome | Sort-Object { $rank[$_] } -Descending | Select-Object -First 1) }
    if ($row.outcome -ne $worst) { $findings += Get-BrainFinding Error 'report:rollup' $display "$($row.check) says $($row.outcome); its subjects roll up to $worst." }
  }

  $want = @(Get-AssessScore -Method $Method -Result @($doc.results))
  $have = @{}; foreach ($p in @($doc.pillars)) { $have[$p.pillar] = $p }
  foreach ($w in $want) {
    $h = $have[$w.pillar]
    $same = $h -and $h.checks -eq $w.checks -and $h.assessed -eq $w.assessed -and [Math]::Abs([double]$h.coverage - $w.coverage) -lt 0.001 -and
    (($null -eq $h.score -and $null -eq $w.score) -or ($null -ne $h.score -and $null -ne $w.score -and [Math]::Abs([double]$h.score - $w.score) -lt 0.001))
    if (-not $same) { $findings += Get-BrainFinding Error 'report:score' $display "Pillar $($w.pillar) should be score $($w.score), coverage $($w.coverage) over $($w.checks) checks." }
  }
  foreach ($p in $have.Keys) { if ($p -notin @($want.pillar)) { $findings += Get-BrainFinding Error 'report:score' $display "Pillar $p has no checks in the method." } }

  $readiness = @{}; foreach ($x in @($Method.readiness)) { $readiness[$x.decision] = $x.readiness }
  $intake = $null -ne (Get-BrainProperty $doc.inputs 'intake')
  $allowed = @{
    'decidable'             = @('supported', 'missing-facts')
    'decidable-with-intake' = if ($intake) { @('supported', 'missing-facts') } else { @('needs-intake') }
    'needs-measurement'     = @('needs-measurement')
  }
  foreach ($d in @($Register.decisions)) {
    $rows = @($doc.decisions | Where-Object decision -eq $d.id)
    if ($rows.Count -ne 1) { $findings += Get-BrainFinding Error 'report:decision' $display "Decision '$($d.id)' has $($rows.Count) rows; it needs one."; continue }
    $row = $rows[0]
    if ($row.readiness -ne $readiness[$d.id]) { $findings += Get-BrainFinding Error 'report:decision' $display "$($d.id) says $($row.readiness); the method says $($readiness[$d.id])." }
    elseif ($row.status -notin $allowed[$row.readiness]) { $findings += Get-BrainFinding Error 'report:decision-status' $display "$($d.id) is $($row.readiness) and says $($row.status); it can only be $($allowed[$row.readiness] -join ' or ')." }
  }
  [pscustomobject]@{ Document = $doc; Findings = @($findings) }
}

# --- Docs consistency (docs/docs-spec.md, contract C13) ----------------------------------------
# Get-Doc* functions read a repo or build data and text from it; Test-Doc* functions take that data
# and return findings in the avd-doc-findings/v1 shape. Scripts are parsed, never run.

$script:DocCommonParameter = @('Verbose', 'Debug', 'ErrorAction', 'ErrorVariable', 'WarningAction', 'WarningVariable',
  'InformationAction', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'ProgressAction', 'WhatIf', 'Confirm')
$script:DocGeneratedHeader = '<!-- Generated by scripts/Update-BrainDocs.ps1 from the code. Do not edit; edit the code and regenerate. -->'

function Get-DocFinding {
  # One finding, as contract C13 (avd-doc-findings/v1) carries it. The key is stable across runs
  # (it leaves out the line number), so a finding can be tracked and accepted.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [ValidatePattern('^D([1-9]|1[01])$')] [string] $Check,
    [Parameter(Mandatory)] [ValidateSet('error', 'warning')] [string] $Severity,
    [Parameter(Mandatory)] [string] $Repo,
    [Parameter(Mandatory)] [string] $Path,
    [int] $Line = 0,
    [Parameter(Mandatory)] [string] $Says,
    [Parameter(Mandatory)] [string] $Truth,
    [ValidateSet('repo', 'brain')] [string] $Fix = 'repo',
    [switch] $Generated
  )
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $key = [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("$Check|$Repo|$Path|$Says|$Truth"))).Substring(0, 12).ToLowerInvariant()
  [pscustomobject][ordered]@{
    check = $Check; severity = $Severity; origin = 'check'; key = $key; repo = $Repo; path = $Path; line = $Line
    says = $Says; truth = $Truth; fix = $Fix; generated = [bool]$Generated
  }
}

function Get-DocMarkdownLine {
  # Splits Markdown into numbered lines and marks those inside fenced code blocks and blockquotes.
  [CmdletBinding()]
  param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
  $fence = $null
  $lines = $Text -split "`r?`n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    $m = [regex]::Match($l, '^\s{0,3}(`{3,}|~{3,})')
    if ($m.Success -and (-not $fence -or $m.Groups[1].Value.StartsWith($fence))) {
      $fence = if ($fence) { $null } else { $m.Groups[1].Value }
      [pscustomobject]@{ Number = $i + 1; Text = $l; Code = $true; Quote = $false }
      continue
    }
    [pscustomobject]@{ Number = $i + 1; Text = $l; Code = [bool]$fence; Quote = (-not $fence -and $l -match '^\s*>') }
  }
}

function Get-DocProse {
  # A prose line with inline code spans and link targets blanked out, so checks on wording skip them.
  param([string] $Text)
  $t = [regex]::Replace($Text, '`[^`]*`', { param($m) ' ' * $m.Value.Length })
  [regex]::Replace($t, '\]\([^)]*\)', { param($m) ']' + (' ' * ($m.Value.Length - 1)) })
}

function Get-DocAnchor {
  # GitHub's anchor for a heading: lowercase, punctuation dropped, spaces to hyphens.
  param([string] $Heading)
  $h = $Heading.Trim().ToLowerInvariant() -replace '[*_`]', ''
  $h = [regex]::Replace($h, '\[([^\]]*)\]\([^)]*\)', '$1')
  ([regex]::Replace($h, '[^\p{L}\p{N} _-]', '')) -replace ' ', '-'
}

function Get-DocScriptInfo {
  # A PowerShell script's comment-based help and param() block, read with the parser.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $Root
  )
  $tokens = $null; $parseErrors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $parseErrors)
  $text = Get-Content -LiteralPath $Path -Raw
  $help = $ast.GetHelpContent()
  $comments = @($tokens | Where-Object Kind -eq 'Comment')
  $params = @()
  if ($ast.ParamBlock) {
    foreach ($p in $ast.ParamBlock.Parameters) {
      $name = $p.Name.VariablePath.UserPath
      $type = @($p.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.TypeConstraintAst] })[0]
      $mandatory = $false; $set = $null
      foreach ($a in @($p.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.AttributeAst] -and $_.TypeName.Name -eq 'Parameter' })) {
        foreach ($n in $a.NamedArguments) {
          if ($n.ArgumentName -eq 'Mandatory' -and ($n.ExpressionOmitted -or $n.Argument.Extent.Text -eq '$true')) { $mandatory = $true }
          if ($n.ArgumentName -eq 'ParameterSetName') { $set = $n.Argument.Extent.Text.Trim("'", '"') }
        }
      }
      $helpText = $null
      if ($help -and $help.Parameters.ContainsKey($name.ToUpperInvariant())) { $helpText = $help.Parameters[$name.ToUpperInvariant()].Trim() }
      if (-not $helpText) {
        # A comment on the lines right above the parameter, inside param(), is its help too.
        $above = @()
        $lineNo = $p.Extent.StartLineNumber - 1
        while ($true) {
          $c = @($comments | Where-Object { $_.Extent.EndLineNumber -eq $lineNo -and $_.Extent.StartOffset -gt $ast.ParamBlock.Extent.StartOffset })[0]
          if (-not $c) { break }
          $above = @(($c.Text -replace '^#\s?', '').Trim()) + $above
          $lineNo = $c.Extent.StartLineNumber - 1
        }
        if ($above.Count) { $helpText = $above -join ' ' }
      }
      $params += [pscustomobject]@{
        Name = $name; Type = if ($type) { $type.TypeName.Name } else { 'object' }
        Default = if ($p.DefaultValue) { $p.DefaultValue.Extent.Text } else { $null }
        Mandatory = $mandatory; Set = $set; Help = $helpText
      }
    }
  }
  $synopsis = if ($help -and $help.Synopsis) { $help.Synopsis.Trim() } else { $null }
  if (-not $synopsis) {
    # Help that the parser doesn't attach (a line comment above it, say) still counts.
    $block = @($comments | Where-Object { $_.Text -match '(?m)^\s*\.SYNOPSIS' })[0]
    if ($block) { $synopsis = ([regex]::Match($block.Text, '(?ms)^\s*\.SYNOPSIS\s*\r?\n(.*?)(?=^\s*\.[A-Z]+|#>)')).Groups[1].Value.Trim() }
  }
  # The synopsis runs to a blank line or the project notice; the reference uses its first sentence.
  $first = if ($synopsis) { (@(($synopsis -split '\r?\n\s*\r?\n')[0] -split '\r?\n' | ForEach-Object { $_.Trim().TrimStart('#').Trim() }) -join ' ' -split '(?=Personal project)')[0].Trim() } else { $null }
  $sentence = if ($first) { ([regex]::Match($first, '^.*?\.(?=\s|$)|^.*$')).Value.Trim() } else { $null }
  [pscustomobject]@{
    Path = ([IO.Path]::GetRelativePath($Root, $Path) -replace '\\', '/'); Name = Split-Path $Path -Leaf
    Synopsis = $sentence; Description = if ($help -and $help.Description) { ($help.Description -replace '\s+', ' ').Trim() } else { $null }
    # The help parser runs on into the comments after it (#requires), so examples stop at a blank line.
    Examples = @(if ($help) { $help.Examples | ForEach-Object { ($_.Trim() -split '\r?\n\s*\r?\n')[0].Trim() } })
    HelpParameters = @(if ($help) { $help.Parameters.Keys })
    Parameters = $params
    HasNotice = $text -match 'Personal project'
    ParseErrors = @($parseErrors).Count
  }
}

function Get-DocBicepInfo {
  # A Bicep file's description, parameters (type, default, @description) and outputs, read line by line.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $Root
  )
  $lines = Get-Content -LiteralPath $Path
  $params = @(); $outputs = @(); $pending = $null; $depth = 0; $fileDescription = $null
  foreach ($l in $lines) {
    $t = $l.Trim()
    if ($depth -gt 0) { $depth += ([regex]::Matches($t, '[\[\(\{]').Count - [regex]::Matches($t, '[\]\)\}]').Count); continue }
    $d = [regex]::Match($t, "^@(?:sys\.)?description\('((?:[^']|'')*)'\)")
    if ($d.Success) { $pending = $d.Groups[1].Value -replace "''", "'"; continue }
    $md = [regex]::Match($t, "^metadata\s+description\s*=\s*'((?:[^']|'')*)'")
    if ($md.Success) { $fileDescription = $md.Groups[1].Value -replace "''", "'"; continue }
    if ($t.StartsWith('@')) {
      $depth = [regex]::Matches($t, '[\[\(\{]').Count - [regex]::Matches($t, '[\]\)\}]').Count
      continue
    }
    $p = [regex]::Match($t, '^param\s+(\w+)\s+([\w.]+(?:\[\])?)(?:\s*=\s*(.+))?$')
    if ($p.Success) {
      $default = if ($p.Groups[3].Success) { $p.Groups[3].Value.Trim() } else { $null }
      if ($default -and $default -match '[\{\[\(]$') { $default = '(see the file)' }
      $params += [pscustomobject]@{ Name = $p.Groups[1].Value; Type = $p.Groups[2].Value; Default = $default; Description = $pending }
      $pending = $null; continue
    }
    $o = [regex]::Match($t, '^output\s+(\w+)\s+([\w.]+(?:\[\])?)')
    if ($o.Success) { $outputs += [pscustomobject]@{ Name = $o.Groups[1].Value; Type = $o.Groups[2].Value; Description = $pending }; $pending = $null; continue }
    if ($t) { $pending = $null }
  }
  [pscustomobject]@{
    Path = ([IO.Path]::GetRelativePath($Root, $Path) -replace '\\', '/'); Name = Split-Path $Path -Leaf
    Description = $fileDescription; Parameters = $params; Outputs = $outputs
  }
}

function Get-DocRepo {
  # Reads one repo for the docs checks: its tracked files, Markdown, scripts and Bicep files.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $Name,
    [string] $Commit
  )
  $root = (Resolve-Path -LiteralPath $Path).Path
  $files = @()
  if (Test-Path -LiteralPath (Join-Path $root '.git')) {
    $files = @(git -C $root ls-files --cached --others --exclude-standard 2>$null | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) })
    if (-not $Commit) { $Commit = "$(git -C $root rev-parse --verify --quiet HEAD 2>$null)".Trim() }
  }
  if (-not $files.Count) {
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/](\.git|\.sources|node_modules)[\\/]' } |
        ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\', '/' })
  }
  $files = @($files | Where-Object { $_ -notlike '.sources/*' } | Sort-Object)
  $dirs = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($f in $files) {
    $parent = $f
    while ($parent.Contains('/')) { $parent = $parent.Substring(0, $parent.LastIndexOf('/')); [void]$dirs.Add($parent) }
  }
  $markdown = @(foreach ($f in $files | Where-Object { $_ -like '*.md' }) {
      $full = Join-Path $root $f
      if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
      $text = Get-Content -LiteralPath $full -Raw
      [pscustomobject]@{ Path = $f; Text = "$text"; Lines = @(Get-DocMarkdownLine -Text "$text") }
    })
  $scripts = @(foreach ($f in $files | Where-Object { $_ -like '*.ps1' -and $_ -notlike '*.Tests.ps1' -and $_ -notmatch '(^|/)tests?/' }) {
      $full = Join-Path $root $f
      if (Test-Path -LiteralPath $full -PathType Leaf) { Get-DocScriptInfo -Path $full -Root $root }
    })
  $bicep = @(foreach ($f in $files | Where-Object { $_ -like '*.bicep' }) {
      $full = Join-Path $root $f
      if (Test-Path -LiteralPath $full -PathType Leaf) { Get-DocBicepInfo -Path $full -Root $root }
    })
  $publicIds = @()
  $ids = Join-Path $root 'scripts/public-ids.txt'
  if (Test-Path -LiteralPath $ids) { $publicIds = @([regex]::Matches((Get-Content -LiteralPath $ids -Raw), '(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') | ForEach-Object { $_.Value.ToLowerInvariant() }) }
  [pscustomobject]@{
    Name = $Name; Root = $root; Commit = $Commit; Files = $files
    Exists = [System.Collections.Generic.HashSet[string]]::new([string[]]@($files + @($dirs)), [StringComparer]::Ordinal)
    Markdown = $markdown; Scripts = $scripts; Bicep = $bicep; PublicIds = $publicIds
  }
}

function Get-DocContract {
  # The contracts table in docs/contracts.md: ID, name, producer, consumer, the format names and
  # schema files its Format cell names, and its status.
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $Text)
  foreach ($line in $Text -split "`r?`n") {
    if ($line -notmatch '^\|\s*C\d+\s*\|') { continue }
    $cells = @(($line.Trim().Trim('|') -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -lt 6) { continue }
    [pscustomobject]@{
      Id = $cells[0]; Name = $cells[1]; Producer = $cells[2]; Consumer = $cells[3]; Status = $cells[5]
      Formats = @([regex]::Matches($cells[4], '`([a-z][a-z0-9-]*/v\d+)`') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      Schemas = @([regex]::Matches($cells[4], '`(?:contracts/schemas/)?([\w.-]+\.schema\.json)`') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      Built = $cells[5] -match '(?i)\bbuilt\b'
    }
  }
}

function Get-DocDecision {
  # Decision records in a repo (any decisions/NNNN-*.md): number, status (MADR front matter or a
  # **Status:** line) and the GitHub links on its Pair and "Also recorded in" lines.
  [CmdletBinding()]
  param([Parameter(Mandatory)] $Repo)
  foreach ($md in $Repo.Markdown | Where-Object { $_.Path -match '(^|/)decisions/\d{4}-[^/]+\.md$' }) {
    $status = $null
    $fm = [regex]::Match($md.Text, '\A---\r?\n(.*?)\r?\n---', 'Singleline')
    if ($fm.Success) { $status = ([regex]::Match($fm.Groups[1].Value, '(?m)^status:\s*"?([A-Za-z-]+)')).Groups[1].Value }
    if (-not $status) { $status = ([regex]::Match($md.Text, '\*\*Status:\*\*\s*([A-Za-z-]+)')).Groups[1].Value }
    $pairs = @()
    foreach ($l in $md.Lines) {
      if ($l.Text -notmatch '(?i)\*\*Pair:\*\*|also recorded in') { continue }
      $kind = if ($l.Text -match '(?i)\*\*Pair:\*\*') { 'pair' } else { 'also' }
      foreach ($m in [regex]::Matches($l.Text, '\]\(https://github\.com/(?:nickprignano|avd-ops)/([\w.-]+)/blob/[^/)]+/([^)#\s]+)')) {
        $pairs += [pscustomobject]@{ Kind = $kind; Repo = $m.Groups[1].Value; Path = $m.Groups[2].Value; Line = $l.Number }
      }
    }
    [pscustomobject]@{ Repo = $Repo.Name; Path = $md.Path; Status = if ($status) { $status.ToLowerInvariant() } else { $null }; Links = $pairs }
  }
}

function Get-DocFact {
  # The brain's facts of record (docs-spec §5), read from a checkout of avd-second-brain.
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $BrainPath)
  $root = (Resolve-Path -LiteralPath $BrainPath).Path
  $schemas = @{}
  foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'contracts/schemas') -Filter *.json -File)) {
    $schemas[$f.Name] = Get-DocTextHash -Text (Get-Content -LiteralPath $f.FullName -Raw)
  }
  $rules = @{}
  foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'knowledge/rules') -Filter *.json -File)) {
    $r = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
    $rules[$f.Name] = [pscustomobject]@{ Version = [int]$r.version; History = @($r.history | ForEach-Object { [int]$_.version }) }
  }
  $terms = Get-Content -LiteralPath (Join-Path $root 'sources/terms.json') -Raw | ConvertFrom-Json
  $catalogIds = @((Get-Content -LiteralPath (Join-Path $root 'knowledge/catalog/apps.json') -Raw | ConvertFrom-Json).entries.id)
  [pscustomobject]@{
    Contracts = @(Get-DocContract -Text (Get-Content -LiteralPath (Join-Path $root 'docs/contracts.md') -Raw))
    Sources = @(Get-BrainSource -Path (Join-Path $root 'sources/sources.json'))
    Terms = @($terms.terms); TermSkip = @(Get-BrainProperty $terms 'skip')
    Schemas = $schemas
    ConnectorTests = Get-Content -LiteralPath (Join-Path $root 'tests/Connectors.Tests.ps1') -Raw
    Rules = $rules; CatalogIds = $catalogIds
    KnowledgeFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'knowledge') -Recurse -File | ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\', '/' })
  }
}

function Get-DocTextHash {
  # SHA-256 of text with line endings normalized, so a checkout's autocrlf doesn't change it.
  param([AllowEmptyString()] [string] $Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($Text -replace "`r`n", "`n").TrimStart([char]0xFEFF)))).ToLowerInvariant()
}

function Test-DocLink {
  # D1: relative Markdown links resolve in the repo (errors), and backticked paths whose first
  # folder exists in the repo resolve too (warnings: a path can name another repo's file).
  # docs/knowledge/ is left to the family check (scripts/kb/validate.py).
  [CmdletBinding()]
  param([Parameter(Mandatory)] $Repo)
  $tops = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Repo.Files | Where-Object { $_.Contains('/') } | ForEach-Object { $_.Split('/')[0] }))
  foreach ($md in $Repo.Markdown) {
    if ($md.Path -like 'docs/knowledge/*') { continue }
    $dir = if ($md.Path.Contains('/')) { $md.Path.Substring(0, $md.Path.LastIndexOf('/')) } else { '' }
    foreach ($l in $md.Lines) {
      if ($l.Code) { continue }
      $noCode = [regex]::Replace($l.Text, '`[^`]*`', '')
      foreach ($m in [regex]::Matches($noCode, '\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)')) {
        $target = $m.Groups[1].Value
        if ($target -match '^(?i)([a-z][a-z0-9+.-]*:|#|//)') { continue }
        $target = [Uri]::UnescapeDataString(($target -split '[#?]')[0])
        if (-not $target) { continue }
        $resolved = Resolve-DocPath -Base $dir -Target $target
        if ($null -eq $resolved) {
          Get-DocFinding -Check D1 -Severity error -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says "links to $target" -Truth 'the link leaves the repository; link to GitHub instead'
        }
        elseif (-not $Repo.Exists.Contains($resolved)) {
          Get-DocFinding -Check D1 -Severity error -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says "links to $target" -Truth "$resolved does not exist"
        }
      }
      # The handbook stub (wiki/) names other repos' pages.
      if ($md.Path -like 'wiki/*') { continue }
      foreach ($m in [regex]::Matches($l.Text, '`([A-Za-z0-9_.-]+/[A-Za-z0-9_./-]*)`')) {
        $p = $m.Groups[1].Value.TrimEnd('/')
        if ($p -match '\.\.|//|^\.') { continue }
        if (-not $tops.Contains($p.Split('/')[0])) { continue }
        if (-not $Repo.Exists.Contains($p)) {
          Get-DocFinding -Check D1 -Severity warning -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says "names $p" -Truth "$p does not exist in $($Repo.Name)"
        }
      }
    }
  }
}

function Resolve-DocPath {
  # A relative link resolved against its file's folder; $null when it climbs out of the repo.
  param([string] $Base, [string] $Target)
  $parts = [System.Collections.Generic.List[string]]::new()
  if (-not $Target.StartsWith('/') -and $Base) { foreach ($s in $Base.Split('/')) { $parts.Add($s) } }
  foreach ($s in $Target.TrimStart('/').Split('/')) {
    if ($s -eq '' -or $s -eq '.') { continue }
    if ($s -eq '..') { if (-not $parts.Count) { return $null }; $parts.RemoveAt($parts.Count - 1); continue }
    $parts.Add($s)
  }
  $parts -join '/'
}

function Test-DocEntryPoint {
  # D2: every script that carries the project notice is an entry point: it has a .SYNOPSIS and the
  # README names it.
  [CmdletBinding()]
  param([Parameter(Mandatory)] $Repo)
  $readme = @($Repo.Markdown | Where-Object Path -eq 'README.md')[0]
  foreach ($s in $Repo.Scripts | Where-Object HasNotice) {
    if (-not $s.Synopsis) {
      Get-DocFinding -Check D2 -Severity error -Repo $Repo.Name -Path $s.Path -Says 'no .SYNOPSIS in its comment-based help' -Truth 'every entry point says what it does in .SYNOPSIS'
    }
    if ($readme -and $readme.Text -notmatch [regex]::Escape($s.Path) -and $readme.Text -notmatch "(?<![\w-])$([regex]::Escape($s.Name))") {
      Get-DocFinding -Check D2 -Severity error -Repo $Repo.Name -Path 'README.md' -Says "doesn't name $($s.Path)" -Truth "$($s.Path) is an entry point (it carries the project notice)" -Generated
    }
  }
}

function Test-DocParameter {
  # D3: parameters written after a script's name in docs and help examples exist in its param()
  # block; .PARAMETER help names real parameters; every parameter has help (a warning).
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    # Scripts that docs may name: this repo's, and in the sweep every connected repo's.
    [object[]] $Script = @()
  )
  $known = @{}
  foreach ($s in @($Repo.Scripts) + @($Script)) { if (-not $known.ContainsKey($s.Name)) { $known[$s.Name] = $s } }

  $check = {
    param([string] $Segment, [string] $Path, [int] $Line)
    $calls = [regex]::Matches($Segment, '([\w.-]+\.ps1)\b')
    for ($c = 0; $c -lt $calls.Count; $c++) {
      $s = $known[$calls[$c].Groups[1].Value]
      if (-not $s) { continue }
      # A script passed as another command's argument (Invoke-ScriptAnalyzer -Path ./x.ps1 -Settings ...)
      # isn't being run, so the parameters after it aren't its own. Only path parameters count:
      # pwsh -File, -Command or -NoProfile before a script still runs it.
      $arg = [regex]::Match($Segment.Substring(0, $calls[$c].Index), '(?<![\w-])-([A-Za-z]\w*)[\s:]+[''"]?[\w./\\$-]*$')
      if ($arg.Success -and $arg.Groups[1].Value -in 'Path', 'LiteralPath', 'FilePath', 'ScriptPath') { continue }
      $end = if ($c + 1 -lt $calls.Count) { $calls[$c + 1].Index } else { $Segment.Length }
      $rest = $Segment.Substring($calls[$c].Index + $calls[$c].Length, $end - $calls[$c].Index - $calls[$c].Length)
      $rest = ($rest -split '[|;]|\s#')[0]
      foreach ($m in [regex]::Matches($rest, '(?<![\w-])-([A-Za-z][A-Za-z0-9]*)\b')) {
        $n = $m.Groups[1].Value
        if ($n -in $script:DocCommonParameter) { continue }
        $match = @($s.Parameters | Where-Object { $_.Name -like "$n*" })
        if (-not @($s.Parameters | Where-Object Name -eq $n).Count -and $match.Count -ne 1) {
          Get-DocFinding -Check D3 -Severity error -Repo $Repo.Name -Path $Path -Line $Line -Says "$($s.Name) -$n" -Truth "$($s.Path) has no parameter $n (it has: $(@($s.Parameters.Name) -join ', '))"
        }
      }
    }
  }

  foreach ($md in $Repo.Markdown) {
    foreach ($l in $md.Lines) {
      $segments = if ($l.Code) { @($l.Text) } else { @([regex]::Matches($l.Text, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value }) }
      foreach ($seg in $segments) { & $check $seg $md.Path $l.Number }
    }
  }
  foreach ($s in $Repo.Scripts) {
    foreach ($e in $s.Examples) { foreach ($el in $e -split "`r?`n") { & $check $el $s.Path 0 } }
    foreach ($h in $s.HelpParameters) {
      if (-not @($s.Parameters | Where-Object { $_.Name -eq $h }).Count) {
        Get-DocFinding -Check D3 -Severity error -Repo $Repo.Name -Path $s.Path -Says ".PARAMETER $h" -Truth "param() has no $h"
      }
    }
    if ($s.HasNotice) {
      foreach ($p in $s.Parameters | Where-Object { -not $_.Help }) {
        Get-DocFinding -Check D3 -Severity warning -Repo $Repo.Name -Path $s.Path -Says "-$($p.Name) has no help" -Truth 'every parameter of an entry point has .PARAMETER help or a comment above it'
      }
    }
  }
}

function Test-DocContract {
  # D4: contract IDs and format names agree with the contracts table; built contracts have their
  # schema and a connector test; vendored schema copies match the authority; sources.json names
  # only contracts that exist.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    [Parameter(Mandatory)] $Fact
  )
  $byId = @{}; foreach ($c in $Fact.Contracts) { $byId[$c.Id] = $c }
  $byFormat = @{}; foreach ($c in $Fact.Contracts) { foreach ($f in $c.Formats) { if (-not $byFormat.ContainsKey($f)) { $byFormat[$f] = $c.Id } } }

  foreach ($md in $Repo.Markdown) {
    foreach ($l in $md.Lines) {
      foreach ($m in [regex]::Matches($l.Text, '(?i)\b(?:brain\s+)?contracts?\s+\**(C\d{1,2})\b')) {
        $id = $m.Groups[1].Value.ToUpperInvariant()
        if (-not $byId.ContainsKey($id)) {
          Get-DocFinding -Check D4 -Severity error -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says "contract $id" -Truth "docs/contracts.md has no $id"
        }
      }
      $ids = @([regex]::Matches($l.Text, '\bC(\d{1,2})\b'))
      if (-not $ids.Count) { continue }
      foreach ($fm in [regex]::Matches($l.Text, '[a-z][a-z0-9-]*/v\d+')) {
        $want = $byFormat[$fm.Value]
        if (-not $want) { continue }
        $near = $ids | Sort-Object { [Math]::Abs($_.Index - $fm.Index) } | Select-Object -First 1
        if ([Math]::Abs($near.Index - $fm.Index) -gt 40) { continue }
        if ($near.Value -ne $want -and -not @($ids | Where-Object Value -eq $want).Count) {
          Get-DocFinding -Check D4 -Severity error -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says "$($near.Value) next to $($fm.Value)" -Truth "$($fm.Value) is contract $want"
        }
      }
    }
  }

  if ($Repo.Name -eq 'avd-second-brain') {
    foreach ($c in $Fact.Contracts | Where-Object Built) {
      foreach ($s in $c.Schemas) {
        if (-not $Fact.Schemas.ContainsKey($s)) {
          Get-DocFinding -Check D4 -Severity error -Repo $Repo.Name -Path 'docs/contracts.md' -Says "$($c.Id) is $($c.Status) with $s" -Truth "contracts/schemas/$s does not exist" -Fix brain
        }
        elseif ($Fact.ConnectorTests -notmatch [regex]::Escape($s) -and $Fact.ConnectorTests -notmatch "\b$($c.Id)\b" -and
          -not @($c.Formats | Where-Object { $Fact.ConnectorTests -match [regex]::Escape($_) }).Count) {
          Get-DocFinding -Check D4 -Severity error -Repo $Repo.Name -Path 'tests/Connectors.Tests.ps1' -Says "no test names $($c.Id) or $s" -Truth "$($c.Id) is $($c.Status), so a connector test covers it" -Fix brain
        }
      }
    }
    foreach ($src in $Fact.Sources) {
      foreach ($t in @($src.feeds) + @($src.reads)) {
        foreach ($m in [regex]::Matches($t, '\bC(\d{1,2})\b')) {
          if (-not $byId.ContainsKey($m.Value)) {
            Get-DocFinding -Check D4 -Severity error -Repo $Repo.Name -Path 'sources/sources.json' -Says "$($src.name) feeds or reads $($m.Value)" -Truth "docs/contracts.md has no $($m.Value)" -Fix brain
          }
        }
      }
    }
  }
  else {
    foreach ($f in $Repo.Files | Where-Object { $_ -match '(^|/)contracts/' -and $Fact.Schemas.ContainsKey((Split-Path $_ -Leaf)) }) {
      $hash = Get-DocTextHash -Text (Get-Content -LiteralPath (Join-Path $Repo.Root $f) -Raw)
      if ($hash -ne $Fact.Schemas[(Split-Path $f -Leaf)]) {
        Get-DocFinding -Check D4 -Severity error -Repo $Repo.Name -Path $f -Says "SHA-256 $($hash.Substring(0, 12))" -Truth "avd-second-brain contracts/schemas/$(Split-Path $f -Leaf) is $($Fact.Schemas[(Split-Path $f -Leaf)].Substring(0, 12)); copy the authority" -Generated
      }
    }
  }
}

function Test-DocDecisionPair {
  # D5: every Pair and "Also recorded in" link resolves; a paired decision links back and has the
  # same status. Links into a repo that isn't in -Repo are skipped (the nightly sweep has them all).
  [CmdletBinding()]
  param([Parameter(Mandatory)] [object[]] $Repo)
  $repos = @{}; foreach ($r in $Repo) { $repos[$r.Name] = $r }
  $decisions = @{}
  foreach ($r in $Repo) { foreach ($d in @(Get-DocDecision -Repo $r)) { $decisions["$($d.Repo):$($d.Path)"] = $d } }
  $seen = @{}
  foreach ($d in $decisions.Values | Sort-Object Repo, Path) {
    foreach ($link in $d.Links) {
      $target = $repos[$link.Repo]
      if (-not $target) { continue }
      if (-not $target.Exists.Contains($link.Path)) {
        Get-DocFinding -Check D5 -Severity error -Repo $d.Repo -Path $d.Path -Line $link.Line -Says "links $($link.Repo):$($link.Path)" -Truth "$($link.Path) does not exist in $($link.Repo)"
        continue
      }
      if ($link.Kind -ne 'pair') { continue }
      $other = $decisions["$($link.Repo):$($link.Path)"]
      if (-not $other) { continue }
      $pairKey = (@("$($d.Repo):$($d.Path)", "$($other.Repo):$($other.Path)") | Sort-Object) -join '|'
      if ($seen.ContainsKey($pairKey)) { continue }
      $back = @($other.Links | Where-Object { $_.Kind -eq 'pair' -and $_.Repo -eq $d.Repo })
      if (-not @($back | Where-Object Path -eq $d.Path).Count) {
        if (@($back | Where-Object { $repos[$d.Repo].Exists.Contains($_.Path) }).Count -or -not $back.Count) {
          Get-DocFinding -Check D5 -Severity error -Repo $other.Repo -Path $other.Path -Says "no Pair link to $($d.Repo):$($d.Path)" -Truth "$($d.Repo):$($d.Path) pairs with it"
        }
        continue
      }
      $seen[$pairKey] = $true
      if ($d.Status -and $other.Status -and $d.Status -ne $other.Status) {
        Get-DocFinding -Check D5 -Severity error -Repo $d.Repo -Path $d.Path -Says "status $($d.Status)" -Truth "its pair $($other.Repo):$($other.Path) is $($other.Status)"
      }
    }
  }
}

function Test-DocChangelog {
  # D6: a PR that changes an entry point, a contract, a schema or a workflow records it in
  # CHANGELOG.md or in a "Changelog:" line in its body ("Changelog: none" opts out).
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    [string[]] $ChangedFile = @(),
    [string] $PullRequestBody
  )
  if (-not $Repo.Exists.Contains('CHANGELOG.md')) {
    Get-DocFinding -Check D6 -Severity warning -Repo $Repo.Name -Path 'CHANGELOG.md' -Says 'no CHANGELOG.md' -Truth 'every connected repo keeps a changelog (Keep a Changelog 1.1)'
  }
  if (-not $ChangedFile.Count) { return }
  $entry = @($Repo.Scripts | Where-Object HasNotice | ForEach-Object Path)
  $hits = @($ChangedFile | Where-Object { $_ -in $entry -or $_ -match '^(contracts/|\.github/workflows/)|\.schema\.json$|^docs/contracts\.md$' })
  if (-not $hits.Count) { return }
  if ('CHANGELOG.md' -in $ChangedFile -or "$PullRequestBody" -match '(?mi)^\s*Changelog:\s*\S') { return }
  Get-DocFinding -Check D6 -Severity warning -Repo $Repo.Name -Path 'CHANGELOG.md' -Says "the PR changes $($hits[0]) and records nothing" -Truth 'add a line under ## Unreleased, or a "Changelog: <Added|Changed|Fixed|Removed>: <what>" line to the PR body'
}

function Test-DocConnectionTable {
  # D7: a table with a stage column that lists connected repos lists all of them
  # (sources/sources.json, less the repo the table is in).
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    [Parameter(Mandatory)] [object[]] $Source
  )
  $names = @($Source.name) + 'avd-second-brain'
  $expected = @($Source.name | Where-Object { $_ -ne $Repo.Name })
  foreach ($md in $Repo.Markdown) {
    $i = 0
    $lines = $md.Lines
    while ($i -lt $lines.Count) {
      if ($lines[$i].Code -or $lines[$i].Text -notmatch '^\s*\|') { $i++; continue }
      $start = $i
      while ($i -lt $lines.Count -and -not $lines[$i].Code -and $lines[$i].Text -match '^\s*\|') { $i++ }
      $table = $lines[$start..($i - 1)]
      if ($table.Count -lt 3 -or $table[0].Text -notmatch '(?i)\|\s*[^|]*stage[^|]*\|') { continue }
      $listed = @(foreach ($row in $table[2..($table.Count - 1)]) {
          $first = ($row.Text.Trim().Trim('|') -split '(?<!\\)\|')[0]
          foreach ($n in $names) { if ($first -match "(?<![\w-])$([regex]::Escape($n))(?![\w-])") { $n } }
        })
      if (@($listed | Where-Object { $_ -in $Source.name }).Count -lt 2) { continue }
      $before = ($md.Lines[0..$start].Text -join "`n")
      $generated = $before.LastIndexOf('<!-- generated:connections begin -->') -gt $before.LastIndexOf('<!-- generated:connections end -->')
      foreach ($missing in $expected | Where-Object { $_ -notin $listed }) {
        Get-DocFinding -Check D7 -Severity error -Repo $Repo.Name -Path $md.Path -Line $table[0].Number -Says "the table lists $(@($listed | Select-Object -Unique).Count) repos without $missing" -Truth "sources/sources.json connects $missing" -Generated:$generated
      }
    }
  }
}

function Test-DocTerm {
  # D8: wording the terms list says to avoid, in prose only (not code, quotations or link targets).
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    [Parameter(Mandatory)] [object[]] $Term,
    # Folders whose text is left alone (terms.json skip), such as text kept in another repo's wording.
    [string[]] $Skip = @()
  )
  $compiled = @(foreach ($t in $Term) {
      foreach ($v in @($t.avoid)) {
        $pattern = if (Get-BrainProperty $t 'regex') { $v } else { "(?<![\w-])$([regex]::Escape($v))(?![\w-])" }
        $opts = if (Get-BrainProperty $t 'caseSensitive') { 'None' } else { 'IgnoreCase' }
        [pscustomobject]@{ Use = $t.use; Avoid = $v; Regex = [regex]::new($pattern, $opts) }
      }
    })
  foreach ($md in $Repo.Markdown) {
    if (@($Skip | Where-Object { $_ -and $md.Path -like "$($_.TrimEnd('/'))/*" }).Count) { continue }
    foreach ($l in $md.Lines) {
      if ($l.Code -or $l.Quote) { continue }
      $prose = Get-DocProse $l.Text
      $said = @{}
      foreach ($c in $compiled) {
        $m = $c.Regex.Match($prose)
        if ($m.Success -and -not $said.ContainsKey($m.Value)) {
          $said[$m.Value] = $true
          Get-DocFinding -Check D8 -Severity warning -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says $m.Value -Truth "use $($c.Use) (sources/terms.json)"
        }
      }
    }
  }
}

function Test-DocKnowledgeCitation {
  # D9: citations of the knowledge base (knowledge/...#id, knowledge/rules/<id>.json@v<n>) exist.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    [Parameter(Mandatory)] $Fact
  )
  foreach ($md in $Repo.Markdown) {
    foreach ($l in $md.Lines) {
      foreach ($m in [regex]::Matches($l.Text, '(?<![\w./-])knowledge/([a-z0-9/_-]+\.json)(?:#([A-Za-z0-9._/-]*[A-Za-z0-9_])|@v(\d+))')) {
        $file = "knowledge/$($m.Groups[1].Value)"
        $says = $m.Value
        if ($file -notin $Fact.KnowledgeFiles) {
          Get-DocFinding -Check D9 -Severity error -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says $says -Truth "avd-second-brain has no $file"
          continue
        }
        if ($m.Groups[2].Success -and $file -eq 'knowledge/catalog/apps.json' -and $m.Groups[2].Value -notin $Fact.CatalogIds) {
          Get-DocFinding -Check D9 -Severity error -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says $says -Truth "the app catalog has no entry $($m.Groups[2].Value)"
        }
        if ($m.Groups[3].Success -and $file -like 'knowledge/rules/*') {
          $rule = $Fact.Rules[(Split-Path $file -Leaf)]
          $v = [int]$m.Groups[3].Value
          if ($v -gt $rule.Version -or ($v -ne $rule.Version -and $v -notin $rule.History)) {
            Get-DocFinding -Check D9 -Severity error -Repo $Repo.Name -Path $md.Path -Line $l.Number -Says $says -Truth "$file is at v$($rule.Version) and has no v$v in its history"
          }
        }
      }
    }
  }
}

function Test-DocGenerated {
  # D10: what the generator would write (Get-DocOutput) is what the repo has.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    [Parameter(Mandatory)] [hashtable] $Expected,
    # Folders the generator owns outright: a file in them it wouldn't write is stale.
    [string[]] $Owned = @('docs/reference')
  )
  foreach ($path in $Expected.Keys | Sort-Object) {
    $full = Join-Path $Repo.Root $path
    if (-not (Test-Path -LiteralPath $full)) {
      Get-DocFinding -Check D10 -Severity error -Repo $Repo.Name -Path $path -Says 'missing' -Truth 'scripts/Update-BrainDocs.ps1 generates it' -Generated
    }
    elseif ((Get-Content -LiteralPath $full -Raw) -replace "`r`n", "`n" -ne ($Expected[$path] -replace "`r`n", "`n")) {
      Get-DocFinding -Check D10 -Severity error -Repo $Repo.Name -Path $path -Says 'out of date' -Truth 'regenerate it with scripts/Update-BrainDocs.ps1' -Generated
    }
  }
  foreach ($f in $Repo.Files | Where-Object { $p = $_; @($Owned | Where-Object { $p -like "$_/*" }).Count }) {
    if (-not $Expected.ContainsKey($f)) {
      Get-DocFinding -Check D10 -Severity error -Repo $Repo.Name -Path $f -Says 'generated page with no source' -Truth 'its script or template is gone; regenerate to remove it' -Generated
    }
  }
}

function Test-DocPrivate {
  # D11: nothing the generator writes looks like tenant or customer data (the brain's guard, less
  # the public Microsoft IDs a repo lists in scripts/public-ids.txt). Never downgraded.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    [Parameter(Mandatory)] [hashtable] $Output
  )
  foreach ($path in $Output.Keys | Sort-Object) {
    # JSON escapes a backslash as two, which reads as a UNC path; scan what the JSON says.
    $text = if ($path -like '*.json') { $Output[$path] -replace '\\\\', '\' } else { $Output[$path] }
    foreach ($f in @(Get-BrainSensitiveText -Text $text -Path $path)) {
      if ($f.Check -eq 'sensitive:guid') {
        $line = ($text -split "`r?`n")[[int]($f.Path -replace '^.*:', '') - 1]
        $guids = @([regex]::Matches($line, '(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') | ForEach-Object { $_.Value.ToLowerInvariant() })
        if (-not @($guids | Where-Object { $_ -notin $Repo.PublicIds -and $_ -notmatch '^[01-]+$' }).Count) { continue }
      }
      Get-DocFinding -Check D11 -Severity error -Repo $Repo.Name -Path $path -Line ([int]($f.Path -replace '^.*:', '')) -Says $f.Check -Truth 'generated docs are public: fix the source text, never the guard'
    }
  }
}

function Get-DocUpdatedText {
  # Text with a generated block replaced; text without the block's markers comes back unchanged.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
    [Parameter(Mandatory)] [string] $Name,
    [Parameter(Mandatory)] [AllowEmptyString()] [string] $Body
  )
  $pattern = "(?s)(<!-- generated:$([regex]::Escape($Name)) begin -->\r?\n).*?(<!-- generated:$([regex]::Escape($Name)) end -->)"
  $header = '<!-- Generated by scripts/Update-BrainDocs.ps1. Do not edit between the markers; edit the source and regenerate. -->'
  [regex]::Replace($Text, $pattern, '${1}' + $header + "`n" + $Body.TrimEnd().Replace('$', '$$') + "`n" + '${2}')
}

function Get-DocMasked {
  # Generated docs don't copy addresses or IDs, even a template's defaults: they point at the source
  # instead, so D11 stays strict. Documentation ranges and placeholder GUIDs stay as written.
  param([AllowEmptyString()] [AllowNull()] [string] $Text)
  if (-not $Text) { return $Text }
  $t = [regex]::Replace($Text, '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?(?![\d.])', {
      param($m) if ($m.Value -match '^(0\.0\.0\.0|127\.|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)') { $m.Value } else { '(address in the source)' } })
  [regex]::Replace($t, '(?i)(?<![0-9a-f])[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?![0-9a-f])', {
      param($m) if ($m.Value -match '^[01-]+$') { $m.Value } else { '(ID in the source)' } })
}

function Get-DocCell {
  param([AllowEmptyString()] [AllowNull()] [string] $Text)
  if (-not $Text) { return '' }
  (Get-DocMasked (($Text -replace '\s+', ' ').Trim())) -replace '\|', '\|'
}

function Get-DocReferencePage {
  # The reference page for one script or Bicep file (docs/reference/...).
  [CmdletBinding()]
  param([Parameter(Mandatory)] $Info)
  $out = [System.Collections.Generic.List[string]]::new()
  $out.Add("# $($Info.Path)"); $out.Add(''); $out.Add($script:DocGeneratedHeader); $out.Add('')
  if ($Info.PSObject.Properties['Synopsis']) {
    if ($Info.Synopsis) { $out.Add((Get-DocMasked $Info.Synopsis)); $out.Add('') }
    if ($Info.Description) { $out.Add((Get-DocMasked $Info.Description)); $out.Add('') }
    $out.Add('## Parameters'); $out.Add('')
    if ($Info.Parameters.Count) {
      $out.Add('| Parameter | Type | Required | Default | What it does |'); $out.Add('|---|---|---|---|---|')
      foreach ($p in $Info.Parameters) {
        $default = if ($p.Default) { '`' + (Get-DocCell $p.Default) + '`' } else { '' }
        $required = if (-not $p.Mandatory) { 'no' } elseif ($p.Set) { "yes, in the $($p.Set) set" } else { 'yes' }
        $out.Add("| ``-$($p.Name)`` | $($p.Type) | $required | $default | $(Get-DocCell $p.Help) |")
      }
    }
    else { $out.Add('None.') }
    if ($Info.Examples.Count) {
      $out.Add(''); $out.Add('## Examples'); $out.Add('')
      foreach ($e in $Info.Examples) { $out.Add('```powershell'); $out.Add((Get-DocMasked $e)); $out.Add('```') }
    }
  }
  else {
    if ($Info.Description) { $out.Add((Get-DocMasked $Info.Description)); $out.Add('') }
    $out.Add('## Parameters'); $out.Add('')
    if ($Info.Parameters.Count) {
      $out.Add('| Parameter | Type | Default | What it does |'); $out.Add('|---|---|---|---|')
      foreach ($p in $Info.Parameters) {
        $default = if ($p.Default) { '`' + (Get-DocCell $p.Default) + '`' } else { '' }
        $out.Add("| ``$($p.Name)`` | $($p.Type) | $default | $(Get-DocCell $p.Description) |")
      }
    }
    else { $out.Add('None.') }
    if ($Info.Outputs.Count) {
      $out.Add(''); $out.Add('## Outputs'); $out.Add('')
      $out.Add('| Output | Type | What it is |'); $out.Add('|---|---|---|')
      foreach ($o in $Info.Outputs) { $out.Add("| ``$($o.Name)`` | $($o.Type) | $(Get-DocCell $o.Description) |") }
    }
  }
  ($out -join "`n") + "`n"
}

function Get-DocReferencePath {
  # Where a script's or Bicep file's reference page goes: docs/reference/<path with / as ->.md.
  param([Parameter(Mandatory)] [string] $Path)
  'docs/reference/' + ($Path -replace '\.(ps1|bicep)$', '' -replace '/', '-') + '.md'
}

function Get-DocEntryPointTable {
  # The README's entry point table: each script that carries the notice, with its synopsis.
  [CmdletBinding()]
  param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Script)
  $rows = @('| Script | What it does |', '|---|---|')
  foreach ($s in $Script | Where-Object HasNotice | Sort-Object Path) {
    $rows += "| [``$($s.Path)``]($(Get-DocReferencePath $s.Path)) | $(Get-DocCell $s.Synopsis) |"
  }
  $rows -join "`n"
}

function Get-DocConnectionTable {
  # The "How it connects" table, from sources/sources.json (each source's readme row, else its stage, feeds and reads).
  [CmdletBinding()]
  param([Parameter(Mandatory)] [object[]] $Source)
  $rows = @('| Repo | Lifecycle stage | Gives the brain | Takes from the brain |', '|---|---|---|---|')
  foreach ($s in $Source) {
    $short = Get-BrainProperty $s 'readme'
    $stage = if ($short) { $short.stage } else { $s.stage }
    $gives = if ($short) { $short.gives } else { @($s.feeds) -join '; ' }
    $takes = if ($short) { $short.takes } elseif (@($s.reads).Count) { @($s.reads) -join '; ' } else { '—' }
    $rows += "| [$($s.name)]($($s.url)) | $(Get-DocCell $stage) | $(Get-DocCell $gives) | $(Get-DocCell $takes) |"
  }
  $rows -join "`n"
}

function Get-DocOutput {
  # Every file and generated block the generator owns in one repo, as path -> full expected text:
  # a reference page per entry point and Bicep file, and the README's entry-points and connections
  # blocks where the README has their markers.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] $Repo,
    [object[]] $Source = @()
  )
  $out = @{}
  foreach ($s in $Repo.Scripts | Where-Object HasNotice) { $out[(Get-DocReferencePath $s.Path)] = Get-DocReferencePage -Info $s }
  foreach ($b in $Repo.Bicep) { $out[(Get-DocReferencePath $b.Path)] = Get-DocReferencePage -Info $b }
  $readme = @($Repo.Markdown | Where-Object Path -eq 'README.md')[0]
  if ($readme) {
    $text = $readme.Text
    $text = Get-DocUpdatedText -Text $text -Name 'entry-points' -Body (Get-DocEntryPointTable -Script @($Repo.Scripts))
    if ($Source.Count) { $text = Get-DocUpdatedText -Text $text -Name 'connections' -Body (Get-DocConnectionTable -Source $Source) }
    if ($text -ne $readme.Text) { $out['README.md'] = $text }
  }
  $out
}

function Get-DocChangelog {
  # CHANGELOG.md with the "Changelog:" lines of merged PRs added under ## Unreleased, each once
  # (a PR already cited as (#n) is skipped). "Changelog: none" adds nothing.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
    [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $PullRequest
  )
  $sections = [ordered]@{ Added = @(); Changed = @(); Deprecated = @(); Removed = @(); Fixed = @(); Security = @() }
  foreach ($pr in $PullRequest | Sort-Object number) {
    if ($Text -match "\(#$($pr.number)\)") { continue }
    foreach ($m in [regex]::Matches("$($pr.body)", '(?mi)^\s*Changelog:\s*(.+?)\s*$')) {
      $line = $m.Groups[1].Value
      if ($line -match '^(?i)none\.?$') { continue }
      $kind = 'Changed'
      $k = [regex]::Match($line, '^(?i)(Added|Changed|Deprecated|Removed|Fixed|Security):\s*(.+)$')
      if ($k.Success) { $kind = (Get-Culture).TextInfo.ToTitleCase($k.Groups[1].Value.ToLowerInvariant()); $line = $k.Groups[2].Value }
      $sections[$kind] += "- $($line.TrimEnd('.')). (#$($pr.number))"
    }
  }
  if (-not @($sections.Values | Where-Object { $_.Count }).Count) { return $Text }
  $lines = [System.Collections.Generic.List[string]]::new([string[]]($Text -split "`r?`n"))
  $u = $lines.IndexOf('## Unreleased')
  if ($u -lt 0) { throw 'CHANGELOG.md has no "## Unreleased" heading.' }
  $end = $u + 1
  while ($end -lt $lines.Count -and $lines[$end] -notmatch '^## ') { $end++ }
  foreach ($kind in $sections.Keys) {
    if (-not $sections[$kind].Count) { continue }
    $h = -1
    for ($i = $u + 1; $i -lt $end; $i++) { if ($lines[$i] -eq "### $kind") { $h = $i; break } }
    if ($h -lt 0) {
      $lines.InsertRange($end, [string[]](@("### $kind", '') + $sections[$kind] + ''))
      $end += $sections[$kind].Count + 3
    }
    else {
      $at = $h + 1
      while ($at -lt $end -and $lines[$at] -notmatch '^### ') { $at++ }
      while ($at -gt $h + 1 -and -not $lines[$at - 1]) { $at-- }
      $lines.InsertRange($at, [string[]]$sections[$kind]); $end += $sections[$kind].Count
    }
  }
  $lines -join "`n"
}

function Get-DocSourceRepo {
  # The connected repos Sync-BrainSources.ps1 checked out under -SourcesRoot, read with Get-DocRepo.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $SourcesRoot,
    [Parameter(Mandatory)] [object[]] $Source
  )
  foreach ($s in $Source) {
    $dir = Join-Path $SourcesRoot $s.name
    if (-not (Test-Path -LiteralPath (Join-Path $dir '.git'))) { continue }
    # A source whose fetch failed has a .git folder and no commit: it wasn't read.
    $r = Get-DocRepo -Path $dir -Name $s.name
    if ($r.Commit) { $r }
  }
}

function Get-DocFindingDocument {
  # The avd-doc-findings/v1 document (contract C13) for a set of findings and the repos they came from.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Finding,
    [Parameter(Mandatory)] [object[]] $Repo,
    [datetime] $Generated = (Get-Date)
  )
  $sources = [ordered]@{}
  foreach ($r in $Repo | Sort-Object Name) { if ($r.Commit) { $sources[$r.Name] = $r.Commit } }
  [ordered]@{
    schema = 'avd-doc-findings/v1'
    generated = $Generated.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    sources = $sources
    findings = @($Finding)
  }
}

function Test-DocConsistency {
  # Runs D1 to D11 on one repo, or every repo in the sweep, and numbers the findings per check.
  # -Repo[0] is the repo under check; the rest are context for D3 and D5.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [object[]] $Repo,
    [Parameter(Mandatory)] $Fact,
    [string[]] $ChangedFile = @(),
    [string] $PullRequestBody,
    # Check every repo in -Repo, not just the first.
    [switch] $All
  )
  $targets = if ($All) { $Repo } else { @($Repo[0]) }
  $allScripts = @($Repo | ForEach-Object { $_.Scripts })
  $findings = @(foreach ($r in $targets) {
      $source = if ($r.Name -eq 'avd-second-brain') { $Fact.Sources } else { @() }
      $expected = Get-DocOutput -Repo $r -Source $source
      $owned = @('docs/reference')
      Test-DocLink -Repo $r
      Test-DocEntryPoint -Repo $r
      Test-DocParameter -Repo $r -Script $allScripts
      Test-DocContract -Repo $r -Fact $Fact
      Test-DocChangelog -Repo $r -ChangedFile $(if ($r -eq $Repo[0]) { $ChangedFile } else { @() }) -PullRequestBody $PullRequestBody
      Test-DocConnectionTable -Repo $r -Source $Fact.Sources
      Test-DocTerm -Repo $r -Term $Fact.Terms -Skip $(if ($r.Name -eq 'avd-second-brain') { $Fact.TermSkip } else { @() })
      Test-DocKnowledgeCitation -Repo $r -Fact $Fact
      Test-DocGenerated -Repo $r -Expected $expected -Owned $owned
      Test-DocPrivate -Repo $r -Output $expected
    })
  $findings += @(Test-DocDecisionPair -Repo $Repo | Where-Object { $_.repo -in $targets.Name })
  # A repo records findings it accepts, by key and with a reason, in docs/accepted-findings.json.
  # D11 is never accepted.
  $accepted = @{}
  foreach ($r in $targets) {
    $file = Join-Path $r.Root 'docs/accepted-findings.json'
    if (Test-Path -LiteralPath $file) {
      foreach ($a in @((Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).accepted)) { $accepted["$($r.Name)|$($a.key)"] = $true }
    }
  }
  $findings = @($findings | Where-Object { $_.check -eq 'D11' -or -not $accepted.ContainsKey("$($_.repo)|$($_.key)") })
  $n = @{}
  foreach ($f in $findings | Sort-Object { [int]$_.check.Substring(1) }, repo, path, line) {
    $n[$f.check] = 1 + [int]$n[$f.check]
    $numbered = [ordered]@{ id = '{0}-{1:0000}' -f $f.check, $n[$f.check] }
    foreach ($p in $f.PSObject.Properties) { $numbered[$p.Name] = $p.Value }
    [pscustomobject]$numbered
  }
}

Export-ModuleMember -Function Get-BrainSensitiveText, Test-BrainCatalog, Test-BrainRule, Test-BrainCalibration,
  Test-BrainEngagement, Test-BrainKnowledge, Resolve-BrainApp, Get-SizingCalibration, Search-BrainKnowledge,
  Get-BrainSource, Get-VaultHarvest, ConvertFrom-SizingEvidence, Test-CurrentStateFacts,
  Test-SchemaPath, Test-FactRegister, Get-TargetStateDecision, Test-TargetState, Test-AssessMethod, Get-AssessScore, Test-AssessmentReport,
  Test-LifecycleRecord, Get-LifecycleExplanation, Get-LifecycleReview, ConvertFrom-TargetStateDecision,
  Get-DocFinding, Get-DocMarkdownLine, Get-DocScriptInfo, Get-DocBicepInfo, Get-DocRepo, Get-DocContract, Get-DocDecision,
  Get-DocFact, Get-DocTextHash, Test-DocLink, Test-DocEntryPoint, Test-DocParameter, Test-DocContract, Test-DocDecisionPair,
  Test-DocChangelog, Test-DocConnectionTable, Test-DocTerm, Test-DocKnowledgeCitation, Test-DocGenerated, Test-DocPrivate,
  Get-DocUpdatedText, Get-DocReferencePage, Get-DocReferencePath, Get-DocEntryPointTable, Get-DocConnectionTable, Get-DocOutput,
  Get-DocChangelog, Get-DocSourceRepo, Get-DocFindingDocument, Test-DocConsistency
