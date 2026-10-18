param([string]$Profile = 'companion')

$ErrorActionPreference = 'Stop'
$defaultDsh = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd'
$dsh = if ($env:DSH_CLI_PATH) { $env:DSH_CLI_PATH } elseif (Get-Command dsh -ErrorAction SilentlyContinue) { (Get-Command dsh).Source } else { $defaultDsh }
if (-not (Test-Path -LiteralPath $dsh)) { throw "DSH launcher not found: $dsh" }
if ($Profile -eq 'desktop') { throw 'Refusing to modify the reserved desktop profile through the CLI.' }

& $dsh plugin --profile $Profile remove dsh-desktop-companion-plugin
if ($LASTEXITCODE -ne 0) { throw 'DSH plugin removal failed' }
Write-Output "Removed DSH Companion plugin from profile '$Profile'."
