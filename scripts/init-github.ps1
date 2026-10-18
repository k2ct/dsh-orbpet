param(
  [Parameter(Mandatory = $true)]
  [string]$Owner,
  [string]$Repository = 'DSHCompanion',
  [switch]$SetRemote
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$slug = "$Owner/$Repository"
$old = 'OWNER/DSHCompanion'

if ($Owner -notmatch '^[A-Za-z0-9_.-]+$') { throw "Invalid GitHub owner: $Owner" }
if ($Repository -notmatch '^[A-Za-z0-9_.-]+$') { throw "Invalid repository name: $Repository" }

$targets = @(
  'README.md',
  'CHANGELOG.md',
  '.github\ISSUE_TEMPLATE\config.yml',
  'SECURITY.md'
)

foreach ($relative in $targets) {
  $path = Join-Path $root $relative
  if (-not (Test-Path -LiteralPath $path)) { continue }
  $content = Get-Content -LiteralPath $path -Raw
  if ($content.Contains($old)) {
    $content = $content.Replace($old, $slug)
    Set-Content -LiteralPath $path -Value $content -NoNewline -Encoding utf8
    Write-Output "Updated $relative"
  }
}

if ($SetRemote) {
  $remotes = @(git remote)
  if ($remotes -contains 'origin') {
    git remote set-url origin "https://github.com/$slug.git"
  } else {
    git remote add origin "https://github.com/$slug.git"
  }
  if ($LASTEXITCODE -ne 0) { throw 'Failed to configure the origin remote' }
  Write-Output "Remote origin set to https://github.com/$slug.git"
}

$remaining = Get-ChildItem -LiteralPath $root -File -Recurse |
  Where-Object { $_.FullName -notmatch '\\(node_modules|target|dist|release|\.git|scripts)\\' } |
  Select-String -Pattern 'OWNER/DSHCompanion'
if ($remaining) {
  Write-Warning 'Placeholder remains in:'
  $remaining | ForEach-Object { Write-Warning "$($_.Path):$($_.LineNumber)" }
} else {
  Write-Output "Repository links now point to https://github.com/$slug"
}
