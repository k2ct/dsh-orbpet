param()

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$dshDefault = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd'
$nodeDefault = Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe'
$pnpmDefault = Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\pnpm\bin\pnpm.mjs'
$cargoDefault = Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'
$rustcDefault = Join-Path $env:USERPROFILE '.cargo\bin\rustc.exe'

function Get-ToolResult([string]$Name, [scriptblock]$VersionCommand) {
  try {
    $value = & $VersionCommand 2>&1 | Select-Object -First 1
    [pscustomobject]@{ tool = $Name; available = $true; version = [string]$value }
  } catch {
    [pscustomobject]@{ tool = $Name; available = $false; version = $_.Exception.Message }
  }
}

$node = if (Get-Command node -ErrorAction SilentlyContinue) { (Get-Command node).Source } elseif (Test-Path $nodeDefault) { $nodeDefault } else { $null }
$dsh = if ($env:DSH_CLI_PATH) { $env:DSH_CLI_PATH } elseif (Get-Command dsh -ErrorAction SilentlyContinue) { (Get-Command dsh).Source } elseif (Test-Path $dshDefault) { $dshDefault } else { $null }

$results = @()
if ($node) { $results += Get-ToolResult 'node' { & $node --version } } else { $results += [pscustomobject]@{tool='node';available=$false;version='not found'} }
if ($node -and (Test-Path $pnpmDefault)) { $results += Get-ToolResult 'pnpm' { & $node $pnpmDefault --version } } else { $results += [pscustomobject]@{tool='pnpm';available=$false;version='not found'} }
$cargo = if (Get-Command cargo -ErrorAction SilentlyContinue) { (Get-Command cargo).Source } elseif (Test-Path $cargoDefault) { $cargoDefault } else { $null }
$rustc = if (Get-Command rustc -ErrorAction SilentlyContinue) { (Get-Command rustc).Source } elseif (Test-Path $rustcDefault) { $rustcDefault } else { $null }
if ($cargo) { $results += Get-ToolResult 'cargo' { & $cargo --version } } else { $results += [pscustomobject]@{tool='cargo';available=$false;version='not found'} }
if ($rustc) { $results += Get-ToolResult 'rustc' { & $rustc --version } } else { $results += [pscustomobject]@{tool='rustc';available=$false;version='not found'} }
if (Get-Command git -ErrorAction SilentlyContinue) { $results += Get-ToolResult 'git' { git --version } } else { $results += [pscustomobject]@{tool='git';available=$false;version='not found'} }
if ($dsh) { $results += Get-ToolResult 'dsh' { & $dsh --version } } else { $results += [pscustomobject]@{tool='dsh';available=$false;version='not found'} }

$results | Format-Table -AutoSize

$report = [pscustomobject]@{
  checkedAt = (Get-Date).ToString('o')
  projectRoot = $root
  tools = $results
}
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $root 'docs\environment-report.json') -Encoding utf8

if ($results.Where({ -not $_.available -and $_.tool -in @('cargo','rustc') }).Count -gt 0) {
  Write-Warning 'Rust is required before the Tauri binary can be compiled. Install rustup with the stable-msvc toolchain.'
  exit 2
}
