param([int]$TimeoutSeconds = 15)

$ErrorActionPreference = 'Stop'
$defaultDsh = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd'
$dsh = if ($env:DSH_CLI_PATH) { $env:DSH_CLI_PATH } elseif (Get-Command dsh -ErrorAction SilentlyContinue) { (Get-Command dsh).Source } else { $defaultDsh }
if (-not (Test-Path -LiteralPath $dsh)) { throw "DSH launcher not found: $dsh" }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $dsh
$psi.Arguments = '--profile acp'
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $psi
if (-not $process.Start()) { throw 'Failed to start ACP profile' }
$process.StandardInput.Close()
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
  $process.Kill()
  throw "ACP liveness probe timed out after $TimeoutSeconds seconds"
}
Write-Output "ACP process started and exited after stdin EOF. exitCode=$($process.ExitCode)"
if ($process.ExitCode -ne 0) { Write-Warning ($process.StandardError.ReadToEnd()) }
