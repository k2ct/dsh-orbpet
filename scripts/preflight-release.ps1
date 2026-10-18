param([switch]$SkipReleaseBuild)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# Native tools (pnpm, cargo, git) may write progress to stderr. Windows
# PowerShell 5.1 would otherwise turn that into a terminating error, so run
# native commands in a Continue scope and validate the exit code ourselves.
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
    Where-Object { $_.FullName -notmatch '\\(node_modules|target|dist|release|\.git|scripts)\\' -and $_.Extension -in '.md','.yml','.yaml','.json' } |
    Select-String -Pattern 'OWNER/DSHCompanion'
  if ($placeholderMatches) {
    throw "Unresolved GitHub placeholders remain: $($placeholderMatches.Path -join ', ')"
  }

  $sensitive = Get-ChildItem -LiteralPath $root -File -Recurse |
    Where-Object { $_.FullName -notmatch '\\(node_modules|target|dist|release|\.git)\\' } |
    Select-String -Pattern '(?i)(sk-[a-z0-9]{16,}|bearer\s+[a-z0-9._-]{16,}|api[_-]?key\s*[:=]\s*["''][^"'']{16,})'
  if ($sensitive) { throw "Potential secret detected in release source: $($sensitive.Path -join ', ')" }

  Invoke-Native { git diff --check } 'git diff --check failed'

  $nodeDir = Split-Path (Get-Command node -ErrorAction Stop).Source
  $env:PATH = "$nodeDir;$env:PATH"
  Invoke-Native { pnpm install --frozen-lockfile } 'pnpm install failed'
  Invoke-Native { pnpm check } 'pnpm check failed'
  Invoke-Native { pnpm test } 'pnpm test failed'
  Invoke-Native { cargo fmt --manifest-path apps\companion\src-tauri\Cargo.toml -- --check } 'cargo fmt check failed'
  Invoke-Native { cargo test --manifest-path apps\companion\src-tauri\Cargo.toml --locked } 'cargo test failed'

  if (-not $SkipReleaseBuild) {
    & (Join-Path $PSScriptRoot 'build-release.ps1') -Clean
    if (-not (Test-Path -LiteralPath (Join-Path $root 'release\SHA256SUMS.txt'))) {
      throw 'Release build did not produce expected artifacts'
    }
  }

  $trackedIgnored = @(git ls-files -ci --exclude-standard)
  if ($trackedIgnored.Count -gt 0) { throw "Ignored files are tracked: $($trackedIgnored -join ', ')" }
  Write-Output 'Release preflight passed.'
} finally {
  Pop-Location
}
