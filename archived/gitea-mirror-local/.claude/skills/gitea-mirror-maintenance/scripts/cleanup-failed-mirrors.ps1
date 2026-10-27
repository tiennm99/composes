<#
.SYNOPSIS
  Acts on the plan produced by detect-failed-mirrors.ps1.
  Dry-run by default: prints the exact commands and changes nothing.

.DESCRIPTION
  case A  delete repo in Gitea, then reset its mirror-DB row to 'imported'
          so the next scheduled run re-migrates it
  case B  delete repo in Gitea only (upstream is gone; re-mirror would fail)
  case C  never touched - reported for retry
  case D  reset the stale mirror-DB row only, no deletion

.EXAMPLE
  ./cleanup-failed-mirrors.ps1              # dry run
  ./cleanup-failed-mirrors.ps1 -Apply       # execute
  ./cleanup-failed-mirrors.ps1 -Apply -Case A
#>
[CmdletBinding()]
param(
  [switch]  $Apply,
  [string]  $Login      = 'localhost',
  [string[]]$Case       = @('A', 'B', 'D'),
  [string]  $ComposeDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path,
  [string]  $MirrorSvc  = 'gitea-mirror',
  [string]  $DbPath     = '//app/data/gitea-mirror.db',
  [string]  $PlanFile   = (Join-Path $env:TEMP 'gitea-mirror-failed-plan.json'),
  [int]     $TimeoutSec = 120
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $PlanFile)) { throw "plan not found: $PlanFile - run detect-failed-mirrors.ps1 first" }
$plan = Get-Content $PlanFile -Raw | ConvertFrom-Json
if (-not $plan) { 'Plan is empty - nothing to do.'; return }

# Cases C and E are advisory only and can never be selected for action:
# C still holds content, E is a clone in progress.
$targets = @($plan | Where-Object { $_.case -in $Case -and $_.case -notin 'C', 'E' })
$skipped = @($plan | Where-Object { $_.case -in 'C', 'E' })

if ($skipped.Count -gt 0) {
  "`n=== NOT TOUCHED (cases C and E) ==="
  $skipped | Sort-Object case, full_name |
    Format-Table case, full_name, reason -AutoSize -Wrap | Out-String -Width 200
}

# A plan goes stale quickly while the scheduler is running: a repo that was a
# broken shell can be re-queued, and a queued one can complete.
$planAge = (Get-Date) - (Get-Item $PlanFile).LastWriteTime
if ($planAge.TotalMinutes -gt 15) {
  Write-Warning ("plan is {0:N0} min old - re-run detect-failed-mirrors.ps1 before applying" -f $planAge.TotalMinutes)
}

if ($targets.Count -eq 0) { "No repos match case(s): $($Case -join ',')"; return }

# tea reads stdin on some paths; run it as a job so it can never hang the script.
# The job must not start inside a git work tree: tea infers its target from the
# local remote, and when that remote matches no configured login it discards
# --login and fails with "remote repository required". Run from a neutral dir.
function Invoke-Tea([string[]]$TeaArgs, [int]$Timeout) {
  $j = Start-Job -ArgumentList $TeaArgs, $env:TEMP {
    param($a, $neutral) Set-Location $neutral; & tea @a 2>&1; "EXIT:$LASTEXITCODE"
  }
  if (Wait-Job $j -Timeout $Timeout) {
    $out  = Receive-Job $j; Remove-Job $j -Force
    $code = ($out | Where-Object { $_ -like 'EXIT:*' }) -replace 'EXIT:', ''
    $msg  = ($out | Where-Object { $_ -notlike 'EXIT:*' }) -join ' '
    return [pscustomobject]@{ ok = ($code -eq '0'); code = $code; msg = $msg }
  }
  Stop-Job $j; Remove-Job $j -Force
  return [pscustomobject]@{ ok = $false; code = 'timeout'; msg = "no response in ${Timeout}s" }
}

function Reset-MirrorRow([string]$FullName) {
  # Single-quote escaping for SQLite string literals.
  $safe = $FullName.Replace("'", "''")
  $sql  = "UPDATE repositories SET status='imported', last_mirrored=NULL, error_message=NULL WHERE full_name='$safe';"
  Push-Location $ComposeDir
  try {
    $out = docker compose exec -T $MirrorSvc sqlite3 $DbPath $sql 2>&1
    return [pscustomobject]@{ ok = ($LASTEXITCODE -eq 0); msg = ($out -join ' ') }
  } finally { Pop-Location }
}

if (-not $Apply) {
  "`n=== DRY RUN - no changes made ===`n"
  foreach ($t in ($targets | Sort-Object case, full_name)) {
    "# $($t.full_name)  (case $($t.case): $($t.reason))"
    if ($t.action -like 'delete*') {
      "tea repos delete --login $Login --owner $($t.owner) --name $($t.name) --force"
    }
    if ($t.action -like '*reset*') {
      "docker compose exec -T $MirrorSvc sqlite3 $DbPath ""UPDATE repositories SET status='imported', last_mirrored=NULL, error_message=NULL WHERE full_name='$($t.full_name)';"""
    }
    ''
  }
  "{0} repo(s) would be actioned. Re-run with -Apply to execute." -f $targets.Count
  return
}

"`n=== APPLYING to $($targets.Count) repo(s) ===`n"
$results = foreach ($t in ($targets | Sort-Object case, full_name)) {
  $delOk = $null; $resetOk = $null; $note = ''

  if ($t.action -like 'delete*') {
    $r = Invoke-Tea @('repos', 'delete', '--login', $Login, '--owner', $t.owner, '--name', $t.name, '--force') $TimeoutSec
    $delOk = $r.ok
    if (-not $r.ok) { $note = "delete failed ($($r.code)) $($r.msg)" }
    Write-Host ("  {0} delete {1}" -f $(if ($r.ok) { 'OK  ' } else { 'FAIL' }), $t.full_name) `
      -ForegroundColor $(if ($r.ok) { 'Green' } else { 'Red' })
  }

  # Only reset after a successful delete, so a live repo is never marked pending.
  if ($t.action -like '*reset*' -and ($delOk -ne $false)) {
    $r = Reset-MirrorRow $t.full_name
    $resetOk = $r.ok
    if (-not $r.ok) { $note = ($note + " reset failed: $($r.msg)").Trim() }
    Write-Host ("  {0} reset  {1}" -f $(if ($r.ok) { 'OK  ' } else { 'FAIL' }), $t.full_name) `
      -ForegroundColor $(if ($r.ok) { 'Green' } else { 'Red' })
  }

  [pscustomobject]@{ full_name = $t.full_name; case = $t.case; deleted = $delOk; reset = $resetOk; note = $note }
}

"`n=== RESULT ==="
$results | Format-Table full_name, case, deleted, reset, note -AutoSize -Wrap | Out-String -Width 200
$failed = @($results | Where-Object { $_.deleted -eq $false -or $_.reset -eq $false })
"{0} succeeded, {1} failed." -f ($results.Count - $failed.Count), $failed.Count
if ($results | Where-Object { $_.reset }) {
  'Reset repos will be re-migrated on the next scheduled run. Verify with detect-failed-mirrors.ps1 afterwards.'
}
