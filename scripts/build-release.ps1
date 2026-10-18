param(
  [switch]$Clean,
  [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$release = Join-Path $root 'release'
$tauriRoot = Join-Path $root 'apps\companion\src-tauri'
$pluginSource = Join-Path $root 'plugins\dsh-companion'
$pluginStage = Join-Path $release 'dsh-desktop-companion-plugin'
$exe = Join-Path $tauriRoot 'target\release\dsh-companion.exe'

function Invoke-Native {
  param([scriptblock]$Command, [string]$FailureMessage)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Command
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
  if ($exitCode -ne 0) { throw "$FailureMessage (exit code $exitCode)" }
}

if ($Clean -and (Test-Path -LiteralPath $release)) {
  $resolved = (Resolve-Path -LiteralPath $release).Path
  if ($resolved -ne (Join-Path $root 'release')) { throw "Refusing to delete unexpected path: $resolved" }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $release,$pluginStage,(Join-Path $pluginStage 'bin'),(Join-Path $pluginStage 'lib') | Out-Null

$node = (Get-Command node -ErrorAction SilentlyContinue).Source
$pnpm = (Get-Command pnpm -ErrorAction SilentlyContinue).Source
if (-not $node -or -not $pnpm) { throw 'Node.js and pnpm must be available on PATH.' }

Push-Location $root
try {
  Invoke-Native { & $pnpm install --frozen-lockfile } 'pnpm install failed'
  Invoke-Native { & $pnpm check } 'pnpm check failed'
  Invoke-Native { & $pnpm test } 'pnpm test failed'
  Invoke-Native { & $pnpm --filter '@dsh-companion/app' tauri build --no-bundle } 'Tauri release executable build failed'
  if (-not $SkipInstaller) {
    Invoke-Native { & $pnpm --filter '@dsh-companion/app' tauri build } 'Tauri installer build failed'
  }
} finally {
  Pop-Location
}

if (-not (Test-Path -LiteralPath $exe)) { throw "Release executable not found: $exe" }
Copy-Item -LiteralPath $exe -Destination (Join-Path $release 'dsh-companion.exe') -Force
Copy-Item -LiteralPath $exe -Destination (Join-Path $pluginStage 'bin\dsh-companion.exe') -Force
Copy-Item -LiteralPath (Join-Path $pluginSource 'lib\index.js') -Destination (Join-Path $pluginStage 'lib\index.js') -Force
Copy-Item -LiteralPath (Join-Path $pluginSource 'package.json') -Destination $pluginStage -Force
Copy-Item -LiteralPath (Join-Path $pluginSource 'cordis.patch.yml') -Destination $pluginStage -Force
Copy-Item -LiteralPath (Join-Path $pluginSource 'README.md') -Destination $pluginStage -Force
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination $pluginStage -Force
Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md') -Destination $pluginStage -Force

$requiredStaged = @(
  'bin\dsh-companion.exe','lib\index.js','package.json','cordis.patch.yml',
  'README.md','LICENSE','THIRD_PARTY_NOTICES.md'
)
foreach ($relative in $requiredStaged) {
  if (-not (Test-Path -LiteralPath (Join-Path $pluginStage $relative))) { throw "Plugin package is missing $relative" }
}

$pluginZip = Join-Path $release 'dsh-desktop-companion-plugin-windows-x64.zip'
Compress-Archive -Path $pluginStage -DestinationPath $pluginZip -Force
if (-not (Test-Path -LiteralPath $pluginZip)) { throw 'Plugin archive was not created' }

$bundleDir = Join-Path $tauriRoot 'target\release\bundle'
if (Test-Path -LiteralPath $bundleDir) {
  Get-ChildItem -LiteralPath $bundleDir -File -Recurse | Where-Object Extension -In '.exe','.msi' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $release $_.Name) -Force
  }
}

$hashFiles = Get-ChildItem -LiteralPath $release -File | Where-Object Name -ne 'SHA256SUMS.txt'
$hashLines = foreach ($file in $hashFiles) {
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  "$hash  $($file.Name)"
}
$hashLines | Set-Content -LiteralPath (Join-Path $release 'SHA256SUMS.txt') -Encoding ascii

Write-Output "Release artifacts created in $release"
Get-ChildItem -LiteralPath $release -File | Select-Object Name,Length
