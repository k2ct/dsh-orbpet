param(
  [Parameter(Mandatory = $true)]
  [string]$PackagePath,
  [string]$Profile = 'companion'
)

$ErrorActionPreference = 'Continue'
$resolvedPackage = (Resolve-Path -LiteralPath $PackagePath).Path
if (-not (Test-Path -LiteralPath (Join-Path $resolvedPackage 'package.json'))) {
  throw "Plugin package.json not found under $resolvedPackage"
}
if (-not (Test-Path -LiteralPath (Join-Path $resolvedPackage 'bin\dsh-companion.exe'))) {
  throw "Plugin executable not found under $resolvedPackage\bin"
}

$defaultDsh = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd'
$dsh = if ($env:DSH_CLI_PATH) { $env:DSH_CLI_PATH } elseif (Get-Command dsh -ErrorAction SilentlyContinue) { (Get-Command dsh).Source } else { $defaultDsh }
if (-not (Test-Path -LiteralPath $dsh)) { throw "DSH launcher not found: $dsh" }
if ($Profile -eq 'desktop') { throw 'The reserved desktop profile is managed by the DSH Desktop application. Use a non-reserved profile for CLI installation.' }

$profileDir = Join-Path $env:USERPROFILE ".dsh\profiles\$Profile"
if (-not (Test-Path -LiteralPath $profileDir)) {
  & $dsh --profile $Profile --from-default-profile headless --dump-config | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Failed to initialize DSH profile $Profile" }
}

$spec = 'file:' + ($resolvedPackage -replace '\\','/')
& $dsh plugin --profile $Profile add $spec
if ($LASTEXITCODE -ne 0) { throw 'DSH plugin installation failed' }
& $dsh plugin --profile $Profile why dsh-desktop-companion-plugin
if ($LASTEXITCODE -ne 0) { throw 'Installed plugin could not be verified' }
Write-Output "Installed DSH Companion plugin into profile '$Profile'."
