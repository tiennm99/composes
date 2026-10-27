<#
.SYNOPSIS
  Read-only audit of the local Gitea mirror stack. Classifies every failing
  mirror into cases A-D and writes a JSON plan for cleanup-failed-mirrors.ps1.

.DESCRIPTION
  Gathers four independent failure signals:
    1. Gitea API   - mirrors with empty:true and no completed initial pull
    2. Upstream    - HEAD probe of original_url, to tell "retry" from "gone"
    3. mirror DB   - repositories rows with status='failed'
    4. gitea log   - mirror_pull.go [E] SyncMirrors errors (periodic sync)

  Makes no changes. Safe to run any time.
#>
[CmdletBinding()]
param(
  [string]$Login       = 'localhost',
  [string]$ApiBase     = 'http://localhost:3000/api/v1',
  [string]$ComposeDir  = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path,
  [string]$MirrorSvc   = 'gitea-mirror',
  [string]$GiteaSvc    = 'gitea',
  [string]$DbPath      = '//app/data/gitea-mirror.db',
  [string]$OutFile     = (Join-Path $env:TEMP 'gitea-mirror-failed-plan.json'),
  [int]   $MaxPages    = 60
)

$ErrorActionPreference = 'Stop'

# --- token for the requested tea login -------------------------------------
function Get-TeaToken([string]$LoginName) {
  $cfgPath = Join-Path $env:LOCALAPPDATA 'tea\config.yml'
  if (-not (Test-Path $cfgPath)) { throw "tea config not found at $cfgPath" }
  $inLogin = $false
  foreach ($line in Get-Content $cfgPath) {
    if ($line -match "^\s*-?\s*name:\s*$([regex]::Escape($LoginName))\s*$") { $inLogin = $true; continue }
    if ($inLogin -and $line -match '^\s*-\s*name:') { break }
    if ($inLogin -and $line -match '^\s*token:\s*(\S+)') { return $Matches[1] }
  }
  throw "no token found for tea login '$LoginName' - run: tea logins add"
}

$token   = Get-TeaToken $Login
$headers = @{ Authorization = "token $token" }

# --- signal 1: every repo the token can see --------------------------------
Write-Host 'Scanning Gitea repositories...' -ForegroundColor Cyan
$all = @()
for ($page = 1; $page -le $MaxPages; $page++) {
  $r = Invoke-RestMethod -Headers $headers -Uri "$ApiBase/repos/search?limit=50&page=$page"
  if (-not $r.data -or $r.data.Count -eq 0) { break }
  $all += $r.data
}
$mirrors = $all | Where-Object { $_.mirror }
$empty   = $all | Where-Object { $_.empty }
Write-Host ("  {0} repos, {1} mirrors, {2} empty" -f $all.Count, $mirrors.Count, $empty.Count)

# --- signal 4: periodic-sync errors from the gitea container log -----------
Write-Host 'Reading gitea container log...' -ForegroundColor Cyan
$syncErrorRepos = @{}
Push-Location $ComposeDir
try {
  $log = docker compose logs $GiteaSvc --no-log-prefix 2>&1
  foreach ($m in [regex]::Matches(($log -join "`n"), 'repo: <Repository \d+:([^>]+)>')) {
    $syncErrorRepos[$m.Groups[1].Value] = $true
  }
} finally { Pop-Location }
Write-Host ("  {0} repos with sync errors in log" -f $syncErrorRepos.Count)

# --- signal 3: mirror-app DB state for every tracked repo ------------------
# The per-repo status is what distinguishes a broken shell from a clone that is
# still in progress, so fetch all of them, not only the failed ones.
Write-Host 'Querying gitea-mirror database...' -ForegroundColor Cyan
$dbStatus = @{}
$dbFailed = @{}
Push-Location $ComposeDir
try {
  $rows = docker compose exec -T $MirrorSvc sqlite3 -separator '|' $DbPath `
    "SELECT full_name, status, substr(replace(coalesce(error_message,''),'|',' '),1,160) FROM repositories;" 2>&1
  foreach ($row in $rows) {
    if ($row -match '^([^|]+)\|([^|]*)\|(.*)$') {
      $fn = $Matches[1].Trim(); $st = $Matches[2].Trim()
      $dbStatus[$fn] = $st
      if ($st -eq 'failed') { $dbFailed[$fn] = $Matches[3].Trim() }
    }
  }
} finally { Pop-Location }
Write-Host ("  {0} tracked rows, {1} with status='failed'" -f $dbStatus.Count, $dbFailed.Count)

# --- signal 2 + classification ---------------------------------------------
Write-Host 'Probing upstreams and classifying...' -ForegroundColor Cyan
$plan = @()

foreach ($repo in $empty) {
  # An unset mirror_updated means the initial migration never finished.
  $neverPulled = (-not $repo.mirror_updated) -or ([datetime]$repo.mirror_updated).Year -le 1
  $st = $dbStatus[$repo.full_name]

  # A clone still in progress looks exactly like a broken shell: empty, size 0,
  # mirror_updated unset. Only the mirror app's own status tells them apart, so
  # never action a repo it is still working on or has not attempted yet.
  if ($st -in 'mirroring', 'imported') {
    $owner, $name = $repo.full_name -split '/', 2
    $plan += [pscustomobject]@{
      full_name = $repo.full_name; owner = $owner; name = $name
      case = 'E'; action = 'report-only'
      size_MB = [math]::Round($repo.size / 1024, 1)
      reason = "empty but mirror DB status='$st' - in flight or queued, leave alone"
      db_status = $st
    }
    continue
  }

  $upAlive = $true
  $upNote  = 'no original_url - assumed alive'
  if ($repo.original_url) {
    try {
      $resp   = Invoke-WebRequest -Uri $repo.original_url -Method Head -TimeoutSec 20 -MaximumRedirection 5
      $upNote = "HTTP $($resp.StatusCode)"
    } catch {
      $code = $null
      if ($_.Exception.Response) { $code = $_.Exception.Response.StatusCode.value__ }
      # Only a definite 404/410 proves the upstream is gone; treat network
      # trouble as "alive" so a flaky connection never deletes permanently.
      if ($code -in 404, 410) { $upAlive = $false; $upNote = "HTTP $code gone" }
      else { $upNote = "probe failed ($(if($code){"HTTP $code"}else{'unreachable'})) - assumed alive" }
    }
  }

  $owner, $name = $repo.full_name -split '/', 2
  $plan += [pscustomobject]@{
    full_name = $repo.full_name
    owner     = $owner
    name      = $name
    case      = if ($upAlive) { 'A' } else { 'B' }
    action    = if ($upAlive) { 'delete+reset' } else { 'delete' }
    size_MB   = [math]::Round($repo.size / 1024, 1)
    reason    = "empty:true$(if($neverPulled){', initial pull never completed'}); mirror DB status='$(if($st){$st}else{'(untracked)'})'; upstream $upNote"
    db_status = $st
  }
}

# Case C: has content but the periodic sync is erroring. Never delete these.
$emptyNames = @($empty | ForEach-Object { $_.full_name })
foreach ($fn in $syncErrorRepos.Keys) {
  if ($emptyNames -contains $fn) { continue }
  $owner, $name = $fn -split '/', 2
  $plan += [pscustomobject]@{
    full_name = $fn; owner = $owner; name = $name
    case = 'C'; action = 'report-only'; size_MB = $null
    reason = 'sync error in gitea log but repo has content - retry, do not delete'
    db_status = $null
  }
}

# Case D: mirror DB says failed, but the repo itself looks healthy.
foreach ($fn in $dbFailed.Keys) {
  if ($emptyNames -contains $fn) { continue }
  $owner, $name = $fn -split '/', 2
  $plan += [pscustomobject]@{
    full_name = $fn; owner = $owner; name = $name
    case = 'D'; action = 'reset-only'; size_MB = $null
    reason = "repo healthy in Gitea but mirror DB status='failed'"
    db_status = $dbFailed[$fn]
  }
}

# Annotate any empty repo that the DB also flagged.
foreach ($p in $plan) {
  if ($dbFailed.ContainsKey($p.full_name) -and -not $p.db_status) { $p.db_status = $dbFailed[$p.full_name] }
}

# --- report ----------------------------------------------------------------
"`n=== FAILED MIRROR REPORT ===`n"
if ($plan.Count -eq 0) {
  'No failing mirrors detected. Nothing to clean up.'
} else {
  $plan | Sort-Object case, full_name |
    Format-Table case, action, full_name, size_MB, reason -AutoSize -Wrap | Out-String -Width 200

  $plan | Group-Object case | Sort-Object Name | ForEach-Object {
    $desc = switch ($_.Name) {
      'A' { 'broken shell, upstream alive  -> delete + reset for re-mirror' }
      'B' { 'broken shell, upstream gone   -> delete only' }
      'C' { 'has content, sync erroring    -> RETRY, never delete' }
      'D' { 'healthy repo, stale DB status -> reset only' }
      'E' { 'clone in flight or queued     -> LEAVE ALONE' }
    }
    "  case {0}: {1,3} repo(s)  {2}" -f $_.Name, $_.Count, $desc
  }
  $reclaim = ($plan | Where-Object { $_.case -in 'A','B' } | Measure-Object size_MB -Sum).Sum
  "`n  reclaimable: {0} MB" -f [math]::Round($reclaim, 1)
}

$plan | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $OutFile
"`nPlan written to: $OutFile"
'Nothing was changed. To act on it, run cleanup-failed-mirrors.ps1 (add -Apply to execute).'
