# mfc CLI — Design

## Visão Geral

CLI standalone (`mfc.exe`) que consome `MinusMigrator_DLL.dll` via imports `external`.
Autossuficiente: baixa a DLL sob demanda na primeira execução.
Auto-update: CLI + DLL se atualizam via GitHub Releases.

## Arquitetura

```
mfc.exe
  ├── MF.Migrator.CLI.pas       — parser de args + dispatch + console UI
  ├── MF.Migrator.API.pas        — 18 funções external 'MinusMigrator_DLL.dll'
  └── MF.Migrator.AutoUpdate.pas — download + version check da DLL
         ↓ mm*() stdcall
MinusMigrator_DLL.dll
  ├── Core: migrator (init, migrate, rollback, status, tag)
  ├── ORM: scaffold (add-migration, generate-models, auto-migrate)
  ├── Pro: changelog/snapshot (diff-changelog, apply, snapshot, diff-snapshots, diff-databases)
  ├── Enterprise: lint
  ├── Sistema: ping, version, getLastError, versionCheck (NOVO)
  └── Tier validation (free/pro/enterprise)
```

## Componentes

### MF.Migrator.CLI.pas
- `Run()` — entry point, parseia `ParamStr`, identifica comando e flags
- `PrintHelp()` — help formatado com cores no console
- `RunCommand(TFunc<Integer>): Boolean` — executa `mm*()` e trata erro via `mmGetLastError`

### MF.Migrator.API.pas
Declarações `external` — sem lógica. Contrato estável entre CLI e DLL.

### MF.Migrator.AutoUpdate.pas (novo)
- `CheckForUpdate(): Boolean` — chama `mmVersionCheck(out URL)`, se `MM_OK` → baixa
- `DownloadDLL(const AURL: string): Boolean` — baixa zip via `WinHTTP`/`URLDownloadToFile`
- `ExtractAndReplace(): Boolean` — extrai DLL do zip, substitui em `%LOCALAPPDATA%\MinusMigrator\bin\`
- `GetDLLPath(): string` — `%LOCALAPPDATA%\MinusMigrator\bin\MinusMigrator_DLL.dll`

## DLL API Contract

### Core (free — migrator)
| Função | Assinatura |
|--------|-----------|
| `mmInit` | `(conn: PChar): Integer; stdcall` |
| `mmMigrate` | `(conn, path: PChar; dryRun: Integer): Integer; stdcall` |
| `mmRollback` | `(conn, path: PChar; steps: Integer; ctx, tag: PChar): Integer; stdcall` |
| `mmStatus` | `(conn, path, format: PChar): PChar; stdcall` |
| `mmTag` | `(tagName, conn: PChar): Integer; stdcall` |

### ORM (free)
| Função | Assinatura |
|--------|-----------|
| `mmAddMigration` | `(desc, conn, entities, migPath: PChar): Integer; stdcall` |
| `mmGenerateModels` | `(conn, outPath, ns: PChar): Integer; stdcall` |
| `mmAutoMigrate` | `(conn, entities: PChar; dryRun, force: Integer): Integer; stdcall` |

### Changelog/Snapshot (pro)
| Função | Assinatura |
|--------|-----------|
| `mmDiffChangelog` | `(conn, entities, outFile, fmt: PChar): Integer; stdcall` |
| `mmApplyChangelog` | `(conn, changelogFile: PChar): Integer; stdcall` |
| `mmSnapshot` | `(conn, outFile: PChar): Integer; stdcall` |
| `mmDiffSnapshots` | `(f1, f2, outFile, fmt: PChar): Integer; stdcall` |
| `mmDiffDatabases` | `(orig, dest, fmt: PChar): Integer; stdcall` |

### Lint (enterprise)
| Função | Assinatura |
|--------|-----------|
| `mmLint` | `(filePath: PChar): Integer; stdcall` |
| `mmLintRules` | `(): PChar; stdcall` |

### Sistema
| Função | Assinatura |
|--------|-----------|
| `mmPing` | `(): Integer; stdcall` — retorna `MM_OK` |
| `mmVersion` | `(): PChar; stdcall` — `"x.y.z"` |
| `mmGetLastError` | `(): PChar; stdcall` — mensagem do último erro |
| `mmVersionCheck` (novo) | `(out URL: PChar): Integer; stdcall` — se há update, `URL` aponta pra release |

### Constantes
```delphi
MM_OK = 0;
MM_ERR = -1;
```

## Auto-Update

### Mecanismo
1. `mfc` inicia → `GetDLLPath()`. Se DLL não existe → baixa do GitHub Releases.
2. Se DLL existe → chama `mmPing()`. Se falha (DLL corrompida) → baixa de novo.
3. Periodicamente (a cada 7 dias ou `mfc update` explícito) → chama `mmVersionCheck(out URL)`.
4. Se `mmVersionCheck` retorna `MM_OK` → `DownloadDLL(URL)` → `ExtractAndReplace()`.
5. Se retorna `MM_ERR` → versão atual é a última.

### mmVersionCheck (implementação na DLL — sem dependências externas)

Usa `System.Net.HttpClient` (Delphi standard library — disponível sem units extras) + `System.JSON`.

```delphi
function mmVersionCheck(out AReleaseURL: PChar): Integer; stdcall;
var
  LHTTP: THTTPClient;
  LResponse: IHTTPResponse;
  LJSON: TJSONObject;
  LTag: string;
begin
  LHTTP := THTTPClient.Create;
  try
    LResponse := LHTTP.Get('https://api.github.com/repos/GabrielFerreiraMendes/' +
      'minusframework-cli/releases/latest');
    if LResponse.StatusCode <> 200 then Exit(MM_ERR);
    LJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    try
      LTag := LJSON.GetValue<string>('tag_name', '');
      if LTag <= FVersion then Exit(MM_ERR);
      AReleaseURL := PChar(StrNew(PChar(
        LJSON.GetValue<string>('assets[0].browser_download_url', ''))));
      Result := MM_OK;
    finally
      LJSON.Free;
    end;
  finally
    LHTTP.Free;
  end;
end;
```

## Distribuição

### GitHub Releases
- `minusframework-migrator`: `MinusMigrator_DLL-v1.2.3.zip` (DLL + VERSION)
- `minusframework-cli`: `mfc-v1.2.3.zip` (mfc.exe + install.ps1)

### Experiência do usuário
| Cenário | Fluxo |
|---------|-------|
| Instalação limpa | Baixa mfc.exe (manual ou install.ps1) → `mfc --help` → baixa DLL automático → pronto |
| Update | `mfc update` → `mmVersionCheck` → baixa DLL+CLI novo → substitui |
| Offline | DLL já presente no mesmo diretório → pula download |
| Cache | DLL fica em `%LOCALAPPDATA%\MinusMigrator\bin\` — persistente entre chamadas |

## Pipeline CI/CD

### minusframework-migrator (workflow: dll-release.yml)
```yaml
on: push (main) + tag "v*"
jobs:
  build:
    - Setup RAD Studio 11.3
    - msbuild MinusMigrator_DLL.dproj /p:Config=Release /p:Platform=Win32
    - Run DUnitX tests (debug)
    - Create Release with MinusMigrator_DLL-v*.zip
```

### minusframework-cli (workflow: cli-release.yml)
```yaml
on: push (main) + tag "v*"
jobs:
  build:
    - Setup RAD Studio 11.3
    - msbuild mfc.dproj /p:Config=Release
    - Run unit tests + integration + E2E (SQLite)
    - Create Release with mfc-v*.zip
```

## Estratégia de Testes

| Tipo | O que testa | Como |
|------|------------|------|
| Unit (parser) | `ParseArgValue`, validações de flag | DUnitX, isolado |
| Unit (auto-update) | `CheckForUpdate` com mock HTTP | DUnitX + interface mock |
| Integration | Dispatch de cada comando com DLL real | DUnitX, SQLite real |
| E2E | Fluxo completo: init → migrate → status → rollback | PowerShell script no CI |

### Testes E2E (powershell, CI)
```powershell
New-Item -ItemType Directory -Path .\fixtures\migrations -Force
"CREATE TABLE users (id INTEGER PRIMARY KEY);" |
  Out-File -FilePath .\fixtures\migrations\001_create_users.sql
mfc init -c sqlite://test_e2e.db
mfc migrate -c sqlite://test_e2e.db -p .\fixtures\migrations
$status = mfc status -c sqlite://test_e2e.db
$status | Should -Match "Batch 1"
```

## Repos e Versionamento

| Repo | Propósito | Versão |
|------|-----------|--------|
| `minusframework-migrator` | DLL com toda lógica de migração | Semver independente (ex: v1.2.3) |
| `minusframework-cli` | CLI standalone `mfc.exe` | Semver independente (ex: v2.0.0) |

A CLI pode consumir DLLs com mesma major (compatível) ou baixar a última DLL que corresponde à sua versão.

## Remoção do CLI antigo

No repo `minusframework-migrator`:
- Remover `MinusMigrator_CLI.dpr`, `MinusMigrator_CLI.dproj`, `MinusMigrator_CLI.res`
- Remover `MinusMigrator_CLI.dproj.local`
- `MF.Migrator.CLI.pas` permanece? Não — o CLI foi movido. Remover.
- Adicionar `mmVersionCheck` na DLL (`MF.Migrator.API.pas`)
- Atualizar `MinusMigrator_DLL.dpr` (se o CLI estava incluído no grupo)

## Próximos Passos

1. Implementar `mmVersionCheck` na DLL
2. Criar `MF.Migrator.AutoUpdate.pas` no CLI
3. Implementar testes unitários do parser
4. Implementar testes de integração com DLL
5. Criar GitHub Actions workflows
6. Testar E2E no CI
7. Fazer primeira release oficial
