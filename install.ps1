param(
  [switch]$Release
)

$ErrorActionPreference = "Stop"
$Config = if ($Release) { "Release" } else { "Debug" }
$BuildDir = Join-Path (Join-Path $PSScriptRoot "Win32") $Config
$InstallDir = Join-Path $env:LOCALAPPDATA "MinusFramework"
$BinDir = Join-Path $InstallDir "bin"
$MfcPath = Join-Path $BinDir "mfc.cmd"
$ExeName = "MinusMigrator_CLI.exe"

Write-Host "=== MinusFramework CLI Installer ===" -ForegroundColor Cyan
Write-Host ""

# 1. Verify build output
Write-Host "[1/3] Verifying build artifact..." -ForegroundColor Yellow
$ExePath = Join-Path $BuildDir $ExeName
if (-not (Test-Path $ExePath)) {
  Write-Error "CLI not found: $ExePath (build $Config first)"
  exit 1
}
Write-Host "  Found: $ExePath" -ForegroundColor Green

# 2. Copy to install dir
Write-Host "[2/3] Installing to $InstallDir..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
Copy-Item -Path $ExePath -Destination $BinDir -Force
@"
@echo off
"%~dp0$ExeName" %*
"@ | Set-Content -Path $MfcPath -Encoding ASCII
Write-Host "  Installed to $BinDir" -ForegroundColor Green

# 3. Add to user PATH
Write-Host "[3/3] Adding to user PATH..." -ForegroundColor Yellow
$OldPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$NewPath = if ($OldPath) { "$BinDir;$OldPath" } else { $BinDir }
if ($OldPath -and $OldPath.Contains($BinDir)) {
  Write-Host "  Already in PATH (skipping)" -ForegroundColor Gray
} else {
  [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
  Write-Host "  Added to user PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Open a NEW terminal and run:" -ForegroundColor Cyan
Write-Host "  mfc --help" -ForegroundColor White
