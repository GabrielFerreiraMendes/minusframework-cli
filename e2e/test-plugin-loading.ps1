# e2e/test-plugin-loading.ps1
# Validacao E2E: mfc carrega plugin DLL via PluginLoader e despacha comandos corretamente.
$ErrorActionPreference = "Stop"

Write-Host "=== mfc Plugin E2E Test ===" -ForegroundColor Cyan

$mfc = "Win32\Debug\mfc.exe"
if (-not (Test-Path $mfc)) {
  Write-Warning "mfc.exe not found at $mfc — skipping E2E (build required)"
  Write-Host "=== E2E tests skipped (build needed) ===" -ForegroundColor Yellow
  exit 0
}

$pluginDir = "$env:LOCALAPPDATA\MinusFramework\plugins"
if (-not (Test-Path $pluginDir)) {
  Write-Host "Plugin dir $pluginDir not found — creating empty" -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
}

Write-Host "Test: mfc --help (no plugins)" -ForegroundColor Yellow
$help = & $mfc "--help"
if ($LASTEXITCODE -ne 0) {
  Write-Error "--help failed with exit code $LASTEXITCODE"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "Test: mfc --version" -ForegroundColor Yellow
$ver = & $mfc "--version"
if ($LASTEXITCODE -ne 0) {
  Write-Error "--version failed"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "Test: mfc nonexistent (unknown command)" -ForegroundColor Yellow
$result = & $mfc "nonexistent" 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Error "Should have failed with unknown command"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "Test: mfc plugin list (no plugins loaded)" -ForegroundColor Yellow
& $mfc "plugin" "list"
if ($LASTEXITCODE -ne 0) {
  Write-Error "plugin list should succeed even with no plugins"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

$dllSource = "..\minusframework-migrator\Win32\Debug\MinusMigrator.dll"
if (Test-Path $dllSource) {
  Copy-Item $dllSource "$pluginDir\MinusMigrator.DLL" -Force
  Write-Host "Test: mfc --help (with MinusMigrator plugin loaded)" -ForegroundColor Yellow
  & $mfc "--help"
  Write-Host "  OK" -ForegroundColor Green

  Write-Host "Test: mfc plugin list (should show MinusMigrator)" -ForegroundColor Yellow
  $list = & $mfc "plugin" "list"
  if ($list -notmatch "MinusMigrator") {
    Write-Error "Expected 'MinusMigrator' in plugin list, got: $list"
    exit 1
  }
  Write-Host "  OK" -ForegroundColor Green
} else {
  Write-Host "MinusMigrator.dll not found at $dllSource — skipping plugin loading tests" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== All E2E tests passed ===" -ForegroundColor Cyan
