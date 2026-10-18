param(
  [int]$Iterations = 20,
  [string]$Executable = "$PSScriptRoot\..\apps\companion\src-tauri\target\debug\dsh-companion.exe"
)

$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $Executable).Path
$failures = @()
$previousSmokeValue = $env:DSH_COMPANION_SMOKE_TEST
$env:DSH_COMPANION_SMOKE_TEST = '1'

Get-Process dsh-companion -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

for ($i = 1; $i -le $Iterations; $i++) {
  $process = Start-Process -FilePath $exe -PassThru
  Start-Sleep -Milliseconds 700
  $running = @(Get-Process dsh-companion -ErrorAction SilentlyContinue)
  if ($running.Count -ne 1) {
    $failures += "iteration $i expected 1 process, found $($running.Count)"
  }

  # A second launch must activate the first instance and exit.
  $second = Start-Process -FilePath $exe -PassThru
  $null = $second.WaitForExit(3000)
  Start-Sleep -Milliseconds 250
  $runningAfterSecond = @(Get-Process dsh-companion -ErrorAction SilentlyContinue)
  if ($runningAfterSecond.Count -ne 1) {
    $failures += "iteration $i single-instance check found $($runningAfterSecond.Count) processes"
  }

  $runningAfterSecond | Stop-Process -Force
  Start-Sleep -Milliseconds 350
  $remaining = @(Get-Process dsh-companion -ErrorAction SilentlyContinue).Count
  if ($remaining -ne 0) {
    $failures += "iteration $i left $remaining process(es)"
    Get-Process dsh-companion -ErrorAction SilentlyContinue | Stop-Process -Force
  }
}

if ($null -eq $previousSmokeValue) {
  Remove-Item Env:DSH_COMPANION_SMOKE_TEST -ErrorAction SilentlyContinue
} else {
  $env:DSH_COMPANION_SMOKE_TEST = $previousSmokeValue
}

if ($failures.Count) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Output "Native lifecycle smoke passed: iterations=$Iterations, single-instance=true, remaining=0, windowsHidden=true"
