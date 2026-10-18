param(
  [string]$Prompt = 'Reply with exactly: DSH companion probe OK',
  [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'
$defaultDsh = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd'
$dsh = if ($env:DSH_CLI_PATH) { $env:DSH_CLI_PATH } elseif (Get-Command dsh -ErrorAction SilentlyContinue) { (Get-Command dsh).Source } else { $defaultDsh }
if (-not (Test-Path -LiteralPath $dsh)) { throw "DSH launcher not found: $dsh" }

$stdout = Join-Path $env:TEMP "dsh-companion-headless-$PID.out"
$stderr = Join-Path $env:TEMP "dsh-companion-headless-$PID.err"
try {
  $process = Start-Process -FilePath $dsh -ArgumentList @('headless', $Prompt) -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    $process.Kill()
    throw "DSH headless probe timed out after $TimeoutSeconds seconds"
  }
  $process.WaitForExit()
  $exitCode = $process.ExitCode
  $outText = Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue
  $errText = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
  Write-Output $outText
  if ($exitCode -ne 0) { throw "DSH exited with $exitCode`: $errText" }
} finally {
  Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
}
