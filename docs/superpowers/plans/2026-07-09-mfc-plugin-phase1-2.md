# mfc Plugin Architecture — Fase 1 + 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar o contrato IMFPlugin + PluginLoader no `mfc` e converter o MinusMigrator_DLL.dll no primeiro plugin.

**Architecture:** COM-like interfaces (`IMFPlugin`, `IMFPluginCommand`) exportadas por cada DLL plugin via factory `mfCreatePlugin`. `mfc` descobre DLLs em `%LOCALAPPDATA%\MinusFramework\plugins\`, carrega e registra comandos. O dispatch muda de switch/case `mm*()` para lookup via `PluginLoader.FindCommand`.

**Tech Stack:** Delphi 11.3, COM interfaces (no registry needed — local GUID resolution via `QueryInterface`), DUnitX, Win32 DLLs.

## Global Constraints

- Usar `stdcall` para todas as exports de DLL
- GUIDs das interfaces fixos (definidos no contrato)
- `MM_OK = 0`, `MM_ERR = -1`
- Carregar DLLs via `LoadLibrary` + `GetProcAddress`
- Plugin dir: `%LOCALAPPDATA%\MinusFramework\plugins\`
- Factory export: `function mfCreatePlugin(out APlugin: IMFPlugin): Integer; stdcall;`
- Testes em DUnitX
- Commits frequentes

---

### Task 1: Criar `MF.CLI.PluginContract.pas`

**Files:**
- Create: `Source/MF.CLI.PluginContract.pas`
- Test: `Source/Test.CLI.PluginContract.pas`

**Interfaces:**
- Produces: `IMFPluginCommand`, `IMFPlugin`, `MM_OK`, `MM_ERR`

- [ ] **Step 1: Write the failing test**

`Source/Test.CLI.PluginContract.pas`:
```delphi
unit Test.CLI.PluginContract;

interface

uses
  DUnitX.TestFramework,
  MF.CLI.PluginContract;

type
  [TestFixture]
  TTestPluginContract = class
  public
    [Test]
    procedure TestConstants;
    [Test]
    procedure TestGUIDs_AreValid;
  end;

implementation

{ TTestPluginContract }

procedure TTestPluginContract.TestConstants;
begin
  Assert.AreEqual(0, MM_OK);
  Assert.AreEqual(-1, MM_ERR);
end;

procedure TTestPluginContract.TestGUIDs_AreValid;
var
  LGuid: TGUID;
begin
  Assert.IsTrue(TryStringToGUID('{C84E5B71-1A2B-4F3D-9E8C-5D6A7B8C9D0E}', LGuid));
  Assert.IsTrue(TryStringToGUID('{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}', LGuid));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginContract);
end.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dcc32 --no-config -B -Q Test.mfc.dpr` or equivalent build
Expected: Compilation error — unit `MF.CLI.PluginContract` not found

- [ ] **Step 3: Write minimal implementation**

`Source/MF.CLI.PluginContract.pas`:
```delphi
unit MF.CLI.PluginContract;

interface

type
  IMFPluginCommand = interface
    ['{C84E5B71-1A2B-4F3D-9E8C-5D6A7B8C9D0E}']
    function GetName: string;
    function GetDescription: string;
    function GetUsage: string;
    function Execute(const AArgs: TArray<string>): Integer;
    property Name: string read GetName;
    property Description: string read GetDescription;
    property Usage: string read GetUsage;
  end;

  IMFPlugin = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetName: string;
    function GetVersion: string;
    function GetDescription: string;
    function GetCommands: TArray<IMFPluginCommand>;
    function GetCommand(const AName: string): IMFPluginCommand;
    property Name: string read GetName;
    property Version: string read GetVersion;
    property Description: string read GetDescription;
  end;

const
  MM_OK = 0;
  MM_ERR = -1;

implementation

end.
```

- [ ] **Step 4: Run test to verify it passes**

Build `Test.mfc.dpr` and run
Expected: Unit compiles, 2 tests pass

- [ ] **Step 5: Commit**

```bash
git add Source/MF.CLI.PluginContract.pas Source/Test.CLI.PluginContract.pas Test.mfc.dpr
git commit -m "feat(cli): add IMFPlugin + IMFPluginCommand interfaces (plugin contract)"
```

---

### Task 2: Atualizar `Test.mfc.dpr` para incluir novos tests

**Files:**
- Modify: `Test.mfc.dpr`

- [ ] **Step 1: Update test project**

```delphi
program Test.mfc;

{$APPTYPE CONSOLE}

uses
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  MF.Migrator.AutoUpdate in 'Source\MF.Migrator.AutoUpdate.pas',
  MF.CLI.PluginContract in 'Source\MF.CLI.PluginContract.pas',
  Test.AutoUpdate in 'Source\Test.AutoUpdate.pas',
  Test.CLI.PluginContract in 'Source\Test.CLI.PluginContract.pas';

begin
  TDUnitX.RegisterTestFixture(Test.AutoUpdate.TTestAutoUpdate);
  TDUnitX.RegisterTestFixture(Test.CLI.PluginContract.TTestPluginContract);
  TDUnitX.Run;
end.
```

- [ ] **Step 2: Build and run tests**

Build: `msbuild Test.mfc.dproj /p:Config=Debug /p:Platform=Win32`
Run: `Win32\Debug\Test.mfc.exe`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add Test.mfc.dpr
git commit -m "test(cli): register PluginContract tests in test runner"
```

---

### Task 3: Criar `MF.CLI.PluginLoader.pas`

**Files:**
- Create: `Source/MF.CLI.PluginLoader.pas`
- Test: `Source/Test.CLI.PluginLoader.pas`

**Interfaces:**
- Consumes: `IMFPlugin`, `IMFPluginCommand` (Task 1)
- Produces: `TPluginLoader` class

- [ ] **Step 1: Write the failing test**

`Source/Test.CLI.PluginLoader.pas`:
```delphi
unit Test.CLI.PluginLoader;

interface

uses
  DUnitX.TestFramework,
  MF.CLI.PluginContract,
  MF.CLI.PluginLoader;

type
  [TestFixture]
  TTestPluginLoader = class
  private
    FLoader: TPluginLoader;
    FOriginalPluginDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestGetPluginDir_ReturnsExpected;
    [Test]
    procedure TestLoadAll_NoDirectory_NoCrash;
    [Test]
    procedure TestFindCommand_Empty_ReturnsNil;
  end;

implementation

uses
  System.SysUtils, System.IOUtils;

procedure TTestPluginLoader.Setup;
begin
  FOriginalPluginDir :=
    TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'MinusFramework\plugins');
  // Backup and clear
  FLoader := TPluginLoader.Create;
end;

procedure TTestPluginLoader.TearDown;
begin
  FLoader.Free;
end;

procedure TTestPluginLoader.TestGetPluginDir_ReturnsExpected;
var
  LPath: string;
begin
  LPath := TPluginLoader.GetPluginDir;
  Assert.IsTrue(LPath.Contains('MinusFramework'), 'Should contain MinusFramework');
  Assert.IsTrue(LPath.Contains('plugins'), 'Should contain plugins');
  Assert.IsTrue(LPath.Contains(GetEnvironmentVariable('LOCALAPPDATA')), 'Should be under LOCALAPPDATA');
end;

procedure TTestPluginLoader.TestLoadAll_NoDirectory_NoCrash;
begin
  Assert.WillNotRaise(
    procedure begin FLoader.LoadAll; end);
end;

procedure TTestPluginLoader.TestFindCommand_Empty_ReturnsNil;
var
  LCmd: IMFPluginCommand;
begin
  LCmd := FLoader.FindCommand('migrate');
  Assert.IsNull(LCmd, 'No plugins loaded, should return nil');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginLoader);
end.
```

- [ ] **Step 2: Run test to verify it fails**

Build and run `Test.mfc.exe`
Expected: Compilation error — unit `MF.CLI.PluginLoader` not found

- [ ] **Step 3: Write minimal implementation**

`Source/MF.CLI.PluginLoader.pas`:
```delphi
unit MF.CLI.PluginLoader;

interface

uses
  System.Classes, System.Generics.Collections,
  MF.CLI.PluginContract;

type
  TPluginLoader = class
  private
    FPlugins: TObjectList<IMFPlugin>;
  public
    constructor Create;
    destructor Destroy; override;
    class function GetPluginDir: string;
    procedure LoadAll;
    function FindCommand(const AName: string): IMFPluginCommand;
    function FindPlugin(const AName: string): IMFPlugin;
    function GetPlugins: TArray<IMFPlugin>;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Winapi.Windows;

type
  TmfCreatePlugin = function(out APlugin: IMFPlugin): Integer; stdcall;

constructor TPluginLoader.Create;
begin
  inherited;
  FPlugins := TObjectList<IMFPlugin>.Create(False);
end;

destructor TPluginLoader.Destroy;
begin
  FPlugins.Free;
  inherited;
end;

class function TPluginLoader.GetPluginDir: string;
begin
  Result := TPath.Combine(
    TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'MinusFramework'), 'plugins');
end;

procedure TPluginLoader.LoadAll;
var
  LDir: string;
  LFiles: TArray<string>;
  LFile: string;
  LHandle: HMODULE;
  LCreateFn: TmfCreatePlugin;
  LPlugin: IMFPlugin;
begin
  LDir := GetPluginDir;
  if not TDirectory.Exists(LDir) then
    Exit;

  LFiles := TDirectory.GetFiles(LDir, '*.dll');
  for LFile in LFiles do
  begin
    LHandle := LoadLibrary(PChar(LFile));
    if LHandle = 0 then
      Continue;

    @LCreateFn := GetProcAddress(LHandle, 'mfCreatePlugin');
    if not Assigned(LCreateFn) then
    begin
      FreeLibrary(LHandle);
      Continue;
    end;

    LPlugin := nil;
    if LCreateFn(LPlugin) = MM_OK then
      FPlugins.Add(LPlugin)
    else
      FreeLibrary(LHandle);
  end;
end;

function TPluginLoader.FindCommand(const AName: string): IMFPluginCommand;
var
  LPlugin: IMFPlugin;
  LCmd: IMFPluginCommand;
begin
  for LPlugin in FPlugins do
  begin
    LCmd := LPlugin.GetCommand(AName);
    if LCmd <> nil then
      Exit(LCmd);
  end;
  Result := nil;
end;

function TPluginLoader.FindPlugin(const AName: string): IMFPlugin;
var
  LPlugin: IMFPlugin;
begin
  for LPlugin in FPlugins do
    if SameText(LPlugin.Name, AName) then
      Exit(LPlugin);
  Result := nil;
end;

function TPluginLoader.GetPlugins: TArray<IMFPlugin>;
begin
  Result := FPlugins.ToArray;
end;

end.
```

- [ ] **Step 4: Run test to verify it passes**

Build and run `Test.mfc.exe`
Expected: All 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add Source/MF.CLI.PluginLoader.pas Source/Test.CLI.PluginLoader.pas
git commit -m "feat(cli): add TPluginLoader — DLL enumeration, LoadLibrary, FindCommand"
```

---

### Task 4: Adaptar dispatch do CLI para usar PluginLoader

**Files:**
- Modify: `Source/MF.CLI.pas`
- Modify: `mfc.dpr`

**Interfaces:**
- Consumes: `TPluginLoader` (Task 3)
- Produces: `mfc.exe` com dispatch por plugin

- [ ] **Step 1: Refactor `Source/MF.CLI.pas`**

Substituir o dispatch atual (switch/case `mm*()`) por `PluginLoader.FindCommand`:

```delphi
unit MF.Migrator.CLI;

{* Ponto de entrada CLI do MinusMigrator.
   Dispara comandos via PluginLoader — cada comando vem de uma DLL plugin. *}

interface

uses
  MF.CLI.PluginLoader;

procedure Run;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  MF.CLI.PluginContract;

var
  FPluginLoader: TPluginLoader;

{ ... Escrever, PrintHelp, RunCommand mantidos iguais ... }

procedure Run;

  procedure HandleUnknownCommand(const ACmd: string);
  begin
    Escrever('Comando desconhecido: ' + ACmd, COR_VERMELHO);
    WriteLn;
    PrintHelp;
  end;

var
  LArgList: TArray<string>;
  I: Integer;
  LCommand: string;
  LCmd: IMFPluginCommand;
begin
  SetLength(LArgList, ParamCount);
  for I := 0 to ParamCount - 1 do
    LArgList[I] := ParamStr(I + 1);

  if (Length(LArgList) > 0) and ((LArgList[0] = '--version') or (LArgList[0] = '-v')) then
  begin
    WriteLn('mfc versao 1.0.0');
    Exit;
  end;

  if (Length(LArgList) = 0) or (LArgList[0] = '--help') or (LArgList[0] = '-h') then
  begin
    PrintHelp;
    Exit;
  end;

  { Comandos built-in }
  if LArgList[0] = 'plugin' then
  begin
    if (Length(LArgList) >= 2) and (LArgList[1] = 'list') then
    begin
      for LCmd in FPluginLoader.GetPlugins do
        WriteLn(LCmd.Name + ' v' + LCmd.Version);
      Exit;
    end;
    HandleUnknownCommand('plugin');
    Exit;
  end;

  { Dispatch via plugin loader }
  LCmd := FPluginLoader.FindCommand(LArgList[0]);
  if LCmd = nil then
  begin
    HandleUnknownCommand(LArgList[0]);
    Exit;
  end;
  LCmd.Execute(LArgList);
end;

initialization
  FPluginLoader := TPluginLoader.Create;
  FPluginLoader.LoadAll;

finalization
  FPluginLoader.Free;
end.
```

- [ ] **Step 2: Atualizar `mfc.dpr`**

Simplificar — não precisa mais de `AutoUpdate` antes de `Run` (será built-in):

```delphi
program mfc;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MF.Migrator.CLI in 'Source\MF.Migrator.CLI.pas',
  MF.CLI.PluginContract in 'Source\MF.CLI.PluginContract.pas',
  MF.CLI.PluginLoader in 'Source\MF.CLI.PluginLoader.pas',
  MF.Migrator.AutoUpdate in 'Source\MF.Migrator.AutoUpdate.pas';

begin
  Run;
end.
```

- [ ] **Step 3: Build to verify compiles**

Build: `msbuild mfc.dproj /p:Config=Debug /p:Platform=Win32`
Expected: Compilation succeeds

- [ ] **Step 4: Commit**

```bash
git add Source/MF.Migrator.CLI.pas mfc.dpr
git commit -m "refactor(cli): dispatch via PluginLoader.FindCommand instead of switch/case mm*()"
```

---

### Task 5: Converter MinusMigrator_DLL.dll em plugin MinusMigrator.DLL

**Files (repo `minusframework-migrator`):**
- Modify: `Source/MF.Migrator.API.pas` (adicionar `mfCreatePlugin`)
- Create: `Source/MF.Migrator.PluginAdapter.pas` (wrapper IMFPlugin → mm*)
- Modify: `MinusMigrator_DLL.dpr` (exportar `mfCreatePlugin`)

**Interfaces:**
- Consumes: `IMFPlugin`, `IMFPluginCommand` (Task 1)
- Produces: DLL com export `mfCreatePlugin`

- [ ] **Step 1: Criar `Source/MF.Migrator.PluginAdapter.pas`**

```delphi
unit MF.Migrator.PluginAdapter;

{* Adaptador que expoe comandos do MinusMigrator como IMFPlugin. *}

interface

uses
  MF.CLI.PluginContract;

function CreateMigratorPlugin(out APlugin: IMFPlugin): Integer; stdcall;

implementation

uses
  System.SysUtils, System.Generics.Collections,
  MF.Migrator.Commands;

type
  TMigratorCommand = class(TInterfacedObject, IMFPluginCommand)
  private
    FName: string;
    FDescription: string;
    FUsage: string;
    FExecuteProc: TFunc<TArray<string>, Integer>;
    function GetName: string;
    function GetDescription: string;
    function GetUsage: string;
    function Execute(const AArgs: TArray<string>): Integer;
  public
    constructor Create(const AName, ADesc, AUsage: string;
      AExecuteProc: TFunc<TArray<string>, Integer>);
  end;

  TMigratorPlugin = class(TInterfacedObject, IMFPlugin)
  private
    FCommands: TObjectList<IMFPluginCommand>;
    function GetName: string;
    function GetVersion: string;
    function GetDescription: string;
    function GetCommands: TArray<IMFPluginCommand>;
    function GetCommand(const AName: string): IMFPluginCommand;
  public
    constructor Create;
    destructor Destroy; override;
  end;

{ TMigratorCommand }

constructor TMigratorCommand.Create(const AName, ADesc, AUsage: string;
  AExecuteProc: TFunc<TArray<string>, Integer>);
begin
  inherited Create;
  FName := AName;
  FDescription := ADesc;
  FUsage := AUsage;
  FExecuteProc := AExecuteProc;
end;

function TMigratorCommand.GetName: string; begin Result := FName; end;
function TMigratorCommand.GetDescription: string; begin Result := FDescription; end;
function TMigratorCommand.GetUsage: string; begin Result := FUsage; end;

function TMigratorCommand.Execute(const AArgs: TArray<string>): Integer;
begin
  Result := FExecuteProc(AArgs);
end;

{ TMigratorPlugin }

constructor TMigratorPlugin.Create;
begin
  inherited Create;
  FCommands := TObjectList<IMFPluginCommand>.Create(False);

  FCommands.Add(TMigratorCommand.Create(
    'init', 'Inicializa banco de migracoes', 'init -c <conn>',
    function(AArgs: TArray<string>): Integer
    var
      LConn, LFlag: string;
      I: Integer;
    begin
      LConn := '';
      for I := 1 to Length(AArgs) - 1 do
      begin
        LFlag := AArgs[I];
        if LFlag = '-c' then begin Inc(I); if I < Length(AArgs) then LConn := AArgs[I]; end;
      end;
      if LConn = '' then Exit(MM_ERR);
      TComandosMigrador.ExecutarInit(LConn);
      Result := MM_OK;
    end));

  FCommands.Add(TMigratorCommand.Create(
    'migrate', 'Executa migrations pendentes', 'migrate -c <conn> -p <path> [--dry-run]',
    function(AArgs: TArray<string>): Integer
    var
      LConn, LPath, LFlag: string;
      LDryRun: Boolean;
      I: Integer;
    begin
      LConn := ''; LPath := ''; LDryRun := False;
      for I := 1 to Length(AArgs) - 1 do
      begin
        LFlag := AArgs[I];
        if LFlag = '-c' then begin Inc(I); if I < Length(AArgs) then LConn := AArgs[I]; end
        else if LFlag = '-p' then begin Inc(I); if I < Length(AArgs) then LPath := AArgs[I]; end
        else if LFlag = '--dry-run' then LDryRun := True;
      end;
      if LConn = '' then Exit(MM_ERR);
      if LPath = '' then LPath := GetCurrentDir;
      TComandosMigrador.ExecutarMigracao(LConn, LPath, LDryRun);
      Result := MM_OK;
    end));

  FCommands.Add(TMigratorCommand.Create(
    'status', 'Status das migrations', 'status -c <conn> -p <path> [--format json|yaml]',
    function(AArgs: TArray<string>): Integer
    var
      LConn, LPath, LFormato, LFlag: string;
      I: Integer;
    begin
      LConn := ''; LPath := ''; LFormato := '';
      for I := 1 to Length(AArgs) - 1 do
      begin
        LFlag := AArgs[I];
        if LFlag = '-c' then begin Inc(I); if I < Length(AArgs) then LConn := AArgs[I]; end
        else if LFlag = '-p' then begin Inc(I); if I < Length(AArgs) then LPath := AArgs[I]; end
        else if LFlag = '--format' then begin Inc(I); if I < Length(AArgs) then LFormato := AArgs[I]; end;
      end;
      if LConn = '' then Exit(MM_ERR);
      if LPath = '' then LPath := GetCurrentDir;
      TComandosMigrador.ExecutarStatus(LConn, LPath, LFormato);
      Result := MM_OK;
    end));

  FCommands.Add(TMigratorCommand.Create(
    'rollback', 'Reverte migrations', 'rollback -c <conn> -p <path> [-n <steps>]',
    function(AArgs: TArray<string>): Integer
    var
      LConn, LPath, LFlag: string;
      LSteps: Integer;
      I: Integer;
    begin
      LConn := ''; LPath := ''; LSteps := 1;
      for I := 1 to Length(AArgs) - 1 do
      begin
        LFlag := AArgs[I];
        if LFlag = '-c' then begin Inc(I); if I < Length(AArgs) then LConn := AArgs[I]; end
        else if LFlag = '-p' then begin Inc(I); if I < Length(AArgs) then LPath := AArgs[I]; end
        else if LFlag = '-n' then begin Inc(I); if I < Length(AArgs) then LSteps := StrToIntDef(AArgs[I], 1); end;
      end;
      if LConn = '' then Exit(MM_ERR);
      if LPath = '' then LPath := GetCurrentDir;
      TComandosMigrador.ExecutarReverter(LConn, LPath, LSteps, '', '');
      Result := MM_OK;
    end));

  FCommands.Add(TMigratorCommand.Create(
    'tag', 'Cria uma tag', 'tag <nome> -c <conn>',
    function(AArgs: TArray<string>): Integer
    var
      LTagName, LConn, LFlag: string;
      I: Integer;
    begin
      if Length(AArgs) < 2 then Exit(MM_ERR);
      LTagName := AArgs[1];
      LConn := '';
      for I := 2 to Length(AArgs) - 1 do
      begin
        LFlag := AArgs[I];
        if LFlag = '-c' then begin Inc(I); if I < Length(AArgs) then LConn := AArgs[I]; end;
      end;
      if LConn = '' then Exit(MM_ERR);
      TComandosMigrador.ExecutarTag(LTagName, LConn);
      Result := MM_OK;
    end));
end;

destructor TMigratorPlugin.Destroy;
begin
  FCommands.Free;
  inherited;
end;

function TMigratorPlugin.GetName: string; begin Result := 'MinusMigrator'; end;
function TMigratorPlugin.GetVersion: string; begin Result := '1.0.0'; end;
function TMigratorPlugin.GetDescription: string; begin Result := 'Database migration tool'; end;

function TMigratorPlugin.GetCommands: TArray<IMFPluginCommand>;
begin
  Result := FCommands.ToArray;
end;

function TMigratorPlugin.GetCommand(const AName: string): IMFPluginCommand;
var
  LCmd: IMFPluginCommand;
begin
  for LCmd in FCommands do
    if SameText(LCmd.Name, AName) then
      Exit(LCmd);
  Result := nil;
end;

{ Factory export }
function CreateMigratorPlugin(out APlugin: IMFPlugin): Integer; stdcall;
begin
  APlugin := TMigratorPlugin.Create;
  Result := MM_OK;
end;

end.
```

- [ ] **Step 2: Exportar `mfCreatePlugin` no `MinusMigrator_DLL.dpr`**

```delphi
library MinusMigrator;

uses
  { ... units existentes ... }
  MF.Migrator.PluginAdapter in 'Source\MF.Migrator.PluginAdapter.pas';

exports
  mf_migrator_versao,
  Migrator_Execute,
  Migrator_GetLastError,
  Migrator_Status,
  { ... mm* existentes ... }
  mfCreatePlugin;   // <-- nova export

begin
end.
```

- [ ] **Step 3: Adicionar `MF.CLI.PluginContract.pas` ao `minusframework-migrator`**

Copiar `Source/MF.CLI.PluginContract.pas` do `minusframework-cli` para `Source/MF.CLI.PluginContract.pas` no `minusframework-migrator`.

- [ ] **Step 4: Build para verificar compilação**

Build: `msbuild MinusMigrator_DLL.dproj /p:Config=Debug /p:Platform=Win32`
Expected: Compilation succeeds

- [ ] **Step 5: Testar o plugin manualmente**

Copiar `MinusMigrator.dll` (o output do build) para `%LOCALAPPDATA%\MinusFramework\plugins\MinusMigrator.DLL`
Executar `mfc.exe` → `mfc init` deve encontrar o plugin e executar.

- [ ] **Step 6: Commit (no `minusframework-migrator`)**

```bash
git add Source/MF.Migrator.PluginAdapter.pas Source/MF.CLI.PluginContract.pas MinusMigrator_DLL.dpr
git commit -m "feat(dll): export mfCreatePlugin — MinusMigrator agora e um plugin IMFPlugin"
```

---

### Task 6: E2E — Validar plugin loading + dispatch

**Files (repo `minusframework-cli`):**
- Create: `e2e/test-plugin-loading.ps1`

- [ ] **Step 1: Criar script E2E**

```powershell
# e2e/test-plugin-loading.ps1
$ErrorActionPreference = "Stop"

Write-Host "=== mfc Plugin E2E Test ===" -ForegroundColor Cyan

# 1. Verificar que mfc.exe existe
$mfc = "Win32\Debug\mfc.exe"
if (-not (Test-Path $mfc)) {
  Write-Error "mfc.exe not found — build first"
  exit 1
}

# 2. Verificar plugin dir
$pluginDir = "$env:LOCALAPPDATA\MinusFramework\plugins"
if (-not (Test-Path $pluginDir)) {
  Write-Host "Plugin dir $pluginDir not found — creating empty" -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
}

# 3. Rodar sem plugin — deve mostrar help
Write-Host "Test: mfc --help (no plugins)" -ForegroundColor Yellow
$help = & $mfc "--help"
if ($LASTEXITCODE -ne 0) {
  Write-Error "--help failed"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

# 4. Rodar comando inexistente
Write-Host "Test: mfc nonexistent" -ForegroundColor Yellow
$result = & $mfc "nonexistent" 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Error "Should have failed with unknown command"
  exit 1
}
Write-Host "  OK" -ForegroundColor Green

# 5. Copiar MinusMigrator.DLL para pasta de plugins
$dllSource = "..\minusframework-migrator\Win32\Debug\MinusMigrator.dll"
if (Test-Path $dllSource) {
  Copy-Item $dllSource "$pluginDir\MinusMigrator.DLL" -Force
  Write-Host "Test: mfc --help (with MinusMigrator plugin)" -ForegroundColor Yellow
  & $mfc "--help"
  Write-Host "  OK" -ForegroundColor Green
} else {
  Write-Host "MinusMigrator.DLL not found — skipping plugin test" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== All E2E tests passed ===" -ForegroundColor Cyan
```

- [ ] **Step 2: Executar E2E**

```powershell
powershell -File e2e/test-plugin-loading.ps1
```
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add e2e/test-plugin-loading.ps1
git commit -m "test(e2e): plugin loading validation script"
```
