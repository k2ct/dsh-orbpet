param([switch]$SkipReleaseBuild)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $required = @(
    'README.md','LICENSE','.gitignore','CONTRIBUTING.md','SECURITY.md',
    'CODE_OF_CONDUCT.md','CHANGELOG.md','THIRD_PARTY_NOTICES.md',
    '.github\workflows\ci.yml','.github\workflows\release.yml',
    'scripts\build-release.ps1','scripts\install-plugin.ps1','scripts\uninstall-plugin.ps1'
  )
  foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $path))) { throw "Required release file missing: $path" }
  }

  $placeholderMatches = Get-ChildItem -LiteralPath $root -File -Recurse |
    Where-Object { $_.FullName -notmatch '\\(node_modules|target|dist|release|\.git)\\' -and $_.Extension -in '.md','.yml','.yaml','.json' } |
    Select-String -Pattern 'OWNER/DSHCompanion'
  if ($placeholderMatches) {
    Write-Warning 'Replace OWNER/DSHCompanion after creating the GitHub repository:'
    $placeholderMatches | ForEach-Object { Write-Warning "$($_.Path):$($_.LineNumber)" }
  }

  $sensitive = Get-ChildItem -LiteralPath $root -File -Recurse |
    Where-Object { $_.FullName -notmatch '\\(node_modules|target|dist|release|\.git)\\' } |
    Select-String -Pattern '(?i)(sk-[a-z0-9]{16,}|bearer\s+[a-z0-9._-]{16,}|api[_-]?key\s*[:=]\s*["''][^"'']{16,})'
  if ($sensitive) { throw "Potential secret detected in release source: $($sensitive.Path -join ', ')" }

  & git diff --check
  if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }

  $nodeDir = Split-Path (Get-Command node -ErrorAction Stop).Source
  $env:PATH = "$nodeDir;$env:PATH"
  & pnpm install --frozen-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'pnpm install failed' }
  & pnpm check
  if ($LASTEXITCODE -ne 0) { throw 'pnpm check failed' }
  & pnpm test
  if ($LASTEXITCODE -ne 0) { throw 'pnpm test failed' }
  & cargo fmt --manifest-path apps\companion\src-tauri\Cargo.toml -- --check
  if ($LASTEXITCODE -ne 0) { throw 'cargo fmt check failed' }
  & cargo test --manifest-path apps\companion\src-tauri\Cargo.toml --locked
  if ($LASTEXITCODE -ne 0) { throw 'cargo test failed' }

  if (-not $SkipReleaseBuild) {
    & $PSScriptRoot\build-release.ps1 -Clean
    if ($LASTEXITCODE -ne 0) { throw 'release build failed' }
  }

  $trackedIgnored = git ls-files -ci --exclude-standard
  if ($trackedIgnored) { throw "Ignored files are tracked: $($trackedIgnored -join ', ')" }
  Write-Output 'Release preflight passed.'
} finally {
  Pop-Location
}
