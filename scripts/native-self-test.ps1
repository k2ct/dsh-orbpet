param(
  [string]$Executable = "$PSScriptRoot\..\apps\companion\src-tauri\target\debug\dsh-companion.exe",
  [int]$TimeoutSeconds = 15
)

$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $Executable).Path
$resultPath = Join-Path $env:TEMP "dsh-companion-native-self-test-$PID.json"
Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue

$previousValue = $env:DSH_COMPANION_NATIVE_SELF_TEST
$env:DSH_COMPANION_NATIVE_SELF_TEST = $resultPath
try {
  $process = Start-Process -FilePath $exe -PassThru
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    $process.Kill()
    throw "Native self-test timed out after $TimeoutSeconds seconds"
  }
  if ($process.ExitCode -ne 0) { throw "Native self-test exited with $($process.ExitCode)" }
  if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Native self-test result file was not created' }
  $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
  if (-not $result.trayInitialized -or -not $result.clickThroughEnabled -or -not $result.clickThroughRestored) {
    throw "Native self-test reported failure: $($result | ConvertTo-Json -Compress)"
  }
  $result | ConvertTo-Json -Compress
} finally {
  Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
  if ($null -eq $previousValue) { Remove-Item Env:DSH_COMPANION_NATIVE_SELF_TEST -ErrorAction SilentlyContinue }
  else { $env:DSH_COMPANION_NATIVE_SELF_TEST = $previousValue }
  Get-Process dsh-companion -ErrorAction SilentlyContinue | Stop-Process -Force
}
