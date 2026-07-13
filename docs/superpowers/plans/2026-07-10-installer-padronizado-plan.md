# Instalador Padronizado Per-Repo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Padronizar os scripts `install.ps1` dos repos CLI e migrator para paths consistentes e zero dependencia cross-repo.

**Architecture:** Cada repo tem seu proprio `install.ps1` que instala APENAS seus artefatos no diretorio `%LOCALAPPDATA%\MinusFramework\` — CLI em `bin\`, DLLs em `plugins\`. Apenas o CLI mexe no PATH.

**Tech Stack:** PowerShell 5.1+

## Global Constraints

- CLI instala em `%LOCALAPPDATA%\MinusFramework\bin\`
- Migrator DLL instala em `%LOCALAPPDATA%\MinusFramework\plugins\`
- Nenhum `install.ps1` builda artefatos de outro repo
- Apenas CLI adiciona PATH
- `mfc.cmd` wrapper: `@echo off\n"%~dp0MinusMigrator_CLI.exe" %*`
- Suporta flags `-Release` e `-NoBuild`

---

### Task 1: Revisar `cli/install.ps1`

**Files:**
- Modify: `C:\Dev\minusframework-cli\install.ps1`

**Interfaces:**
- Consumes: `Win32\$Config\MinusMigrator_CLI.exe`
- Produces: `%LOCALAPPDATA%\MinusFramework\bin\MinusMigrator_CLI.exe`, `%LOCALAPPDATA%\MinusFramework\bin\mfc.cmd`, PATH entry

- [ ] **Step 1: Read current file**

```bash
type C:\Dev\minusframework-cli\install.ps1
```

- [ ] **Step 2: Verify paths are correct**

Verificar se ja usa `%LOCALAPPDATA%\MinusFramework\bin\` (deve estar correto — foi criado agora).

- [ ] **Step 3: Run the installer to test**

```powershell
cd C:\Dev\minusframework-cli
.\install.ps1
```

Expected: CLI copiado para `$env:LOCALAPPDATA\MinusFramework\bin\MinusMigrator_CLI.exe`, `mfc.cmd` criado, PATH atualizado.

- [ ] **Step 4: Commit**

```bash
cd C:\Dev\minusframework-cli
git add install.ps1
git commit -m "chore: revisa install.ps1 com paths padronizados"
```

---

### Task 2: Reescrever `migrator/install.ps1`

**Files:**
- Modify: `C:\Dev\minusframework-migrator\install.ps1`

**Interfaces:**
- Consumes: `Win32\$Config\MinusMigrator.dll`
- Produces: `%LOCALAPPDATA%\MinusFramework\plugins\MinusMigrator.dll`
- Does NOT: build CLI, modify PATH, create `mfc.cmd`

- [ ] **Step 1: Read current file**

```bash
type C:\Dev\minusframework-migrator\install.ps1
```

- [ ] **Step 2: Write new `install.ps1`**

```powershell
param(
  [switch]$Release,
  [switch]$NoBuild
)

$ErrorActionPreference = "Stop"
$Config = if ($Release) { "Release" } else { "Debug" }

$BuildDir = Join-Path $PSScriptRoot "Win32" $Config
$PluginDir = Join-Path $env:LOCALAPPDATA "MinusFramework" "plugins"
$DllName = "MinusMigrator.dll"

Write-Host "=== MinusFramework Migrator Plugin Installer ===" -ForegroundColor Cyan
Write-Host ""

# 1. Build (optional)
if (-not $NoBuild) {
  Write-Host "[1/3] Building $Config..." -ForegroundColor Yellow
  $Dproj = Join-Path $PSScriptRoot "MinusMigrator_DLL.dproj"
  if (-not (Test-Path $Dproj)) {
    Write-Error "Project not found: $Dproj"
    exit 1
  }
  $BuildTool = "${env:ProgramFiles(x86)}\Embarcadero\Studio\23.0\bin\MSBuild.exe"
  if (-not (Test-Path $BuildTool)) { $BuildTool = "msbuild" }
  & $BuildTool "$Dproj" "/p:Config=$Config" "/p:Platform=Win32" "/t:Build"
  if ($LASTEXITCODE -ne 0) { Write-Error "Build failed."; exit 1 }
  Write-Host "  OK" -ForegroundColor Green
}

# 2. Verify build output
Write-Host "[2/3] Verifying build artifact..." -ForegroundColor Yellow
$DllPath = Join-Path $BuildDir $DllName
if (-not (Test-Path $DllPath)) {
  Write-Error "DLL not found: $DllPath (build $Config first)"
  exit 1
}
Write-Host "  Found: $DllPath" -ForegroundColor Green

# 3. Copy to plugin dir
Write-Host "[3/3] Installing to $PluginDir..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
Copy-Item -Path $DllPath -Destination $PluginDir -Force
Write-Host "  Installed: $PluginDir\$DllName" -ForegroundColor Green

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Plugin installed. Run 'mfc plugin list' to verify." -ForegroundColor Cyan
```

- [ ] **Step 3: Commit**

```bash
cd C:\Dev\minusframework-migrator
git add install.ps1
git commit -m "chore: reescreve install.ps1 — so instala DLL, sem dependencia CLI"
```

---

### Task 3: Verificacao final

- [ ] **Step 1: Run CLI installer**

```powershell
cd C:\Dev\minusframework-cli
.\install.ps1 -NoBuild
```

- [ ] **Step 2: Run migrator installer**

```powershell
cd C:\Dev\minusframework-migrator
.\install.ps1 -NoBuild
```

- [ ] **Step 3: Test CLI**

Open new PowerShell. Run:
```powershell
mfc --help
mfc plugin list
```

Expected: help exibido, plugin list mostra `MinusMigrator vX.X.X` (ou vazio se DLL nao carregar).
