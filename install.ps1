param(
  [switch]$Release,
  [switch]$NoBuild
)

$ErrorActionPreference = "Stop"
$Config = if ($Release) { "Release" } else { "Debug" }
$ProjectRoot = $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "Win32" $Config
$InstallDir = Join-Path $env:LOCALAPPDATA "MinusMigrator"
$BinDir = Join-Path $InstallDir "bin"

Write-Host "=== mfc CLI Installer ===" -ForegroundColor Cyan
Write-Host ""

# 1. Build
if (-not $NoBuild) {
  Write-Host "[1/4] Building $Config..." -ForegroundColor Yellow
  $BuildTool = "${env:ProgramFiles(x86)}\Embarcadero\Studio\23.0\bin\MSBuild.exe"
  if (-not (Test-Path $BuildTool)) {
    $BuildTool = "msbuild"
  }
  $Dproj = Join-Path $ProjectRoot "mfc.dproj"
  & $BuildTool "$Dproj" "/p:Config=$Config" "/p:Platform=Win32" "/t:Build"
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed."
    exit 1
  }
  Write-Host "  OK" -ForegroundColor Green
}

# 2. Verify
Write-Host "[2/4] Verifying build artifacts..." -ForegroundColor Yellow
$ExePath = Join-Path $BuildDir "mfc.exe"
if (-not (Test-Path $ExePath)) {
  Write-Error "mfc.exe not found in $BuildDir"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

# 3. Install
Write-Host "[3/4] Installing to $InstallDir..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
Copy-Item -Path $ExePath -Destination $BinDir -Force

Write-Host "  mfc.exe copied to $BinDir" -ForegroundColor Green
Write-Host "  IMPORTANTE: Copie MinusMigrator_DLL.dll para o mesmo diretorio!" -ForegroundColor Yellow

# 4. PATH
Write-Host "[4/4] Adding to user PATH..." -ForegroundColor Yellow
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
Write-Host "Open a NEW terminal and run:"
Write-Host "  mfc --help" -ForegroundColor White
Write-Host "  mfc init -c sqlite://C:\test.db" -ForegroundColor White
Write-Host ""
Write-Host "Requer MinusMigrator_DLL.dll no mesmo diretorio de mfc.exe." -ForegroundColor Gray
