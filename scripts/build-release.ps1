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
  & $pnpm install --frozen-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'pnpm install failed' }
  & $pnpm check
  if ($LASTEXITCODE -ne 0) { throw 'pnpm check failed' }
  & $pnpm test
  if ($LASTEXITCODE -ne 0) { throw 'pnpm test failed' }
  & $pnpm --filter '@dsh-companion/app' tauri build --no-bundle
  if ($LASTEXITCODE -ne 0) { throw 'Tauri release executable build failed' }
  if (-not $SkipInstaller) {
    & $pnpm --filter '@dsh-companion/app' tauri build
    if ($LASTEXITCODE -ne 0) { throw 'Tauri installer build failed' }
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

$pluginZip = Join-Path $release 'dsh-desktop-companion-plugin-windows-x64.zip'
Compress-Archive -Path $pluginStage -DestinationPath $pluginZip -Force

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
