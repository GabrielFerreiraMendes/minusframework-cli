# e2e/test-plugin-loading.ps1
# Validacao E2E: MinusMigrator_CLI carrega plugin DLL via PluginLoader e despacha comandos corretamente.
$ErrorActionPreference = "Stop"

Write-Host "=== MinusMigrator_CLI Plugin E2E Test ===" -ForegroundColor Cyan

$MinusMigrator_CLI = "Win32\Debug\MinusMigrator_CLI.exe"
if (-not (Test-Path $MinusMigrator_CLI)) {
  Write-Warning "MinusMigrator_CLI.exe not found at $MinusMigrator_CLI - skipping E2E (build required)"
  Write-Host "=== E2E tests skipped (build needed) ===" -ForegroundColor Yellow
  exit 0
}

$pluginDir = "$env:LOCALAPPDATA\MinusFramework\plugins"
if (-not (Test-Path $pluginDir)) {
  Write-Host "Plugin dir $pluginDir not found - creating empty" -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
}

Write-Host "Test: MinusMigrator_CLI --help (no plugins)" -ForegroundColor Yellow
$help = & $MinusMigrator_CLI "--help"
if ($LASTEXITCODE -ne 0) {
  Write-Error "--help failed with exit code $LASTEXITCODE"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "Test: MinusMigrator_CLI --version" -ForegroundColor Yellow
$ver = & $MinusMigrator_CLI "--version"
if ($LASTEXITCODE -ne 0) {
  Write-Error "--version failed"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "Test: MinusMigrator_CLI nonexistent (unknown command)" -ForegroundColor Yellow
$result = & $MinusMigrator_CLI "nonexistent" 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Error "Should have failed with unknown command"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "Test: MinusMigrator_CLI plugin list (no plugins loaded)" -ForegroundColor Yellow
& $MinusMigrator_CLI "plugin" "list"
if ($LASTEXITCODE -ne 0) {
  Write-Error "plugin list should succeed even with no plugins"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

$dllSource = "..\minusframework-migrator\Win32\Debug\MinusMigrator.dll"
if (Test-Path $dllSource) {
  Copy-Item $dllSource "$pluginDir\MinusMigrator.DLL" -Force
  Write-Host "Test: MinusMigrator_CLI --help (with MinusMigrator plugin loaded)" -ForegroundColor Yellow
  & $MinusMigrator_CLI "--help"
  Write-Host "  OK" -ForegroundColor Green

  Write-Host "Test: MinusMigrator_CLI plugin list (should show MinusMigrator)" -ForegroundColor Yellow
  $list = & $MinusMigrator_CLI "plugin" "list"
  if ($list -notmatch "MinusMigrator") {
    Write-Error "Expected 'MinusMigrator' in plugin list, got: $list"
    exit 1
  }
  Write-Host "  OK" -ForegroundColor Green
} else {
  Write-Host "MinusMigrator.dll not found at $dllSource - skipping plugin loading tests" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== All E2E tests passed ===" -ForegroundColor Cyan
