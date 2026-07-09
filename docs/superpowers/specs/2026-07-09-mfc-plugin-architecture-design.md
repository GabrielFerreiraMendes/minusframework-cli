# mfc Plugin Architecture — Design

## Visão Geral

Transformar o `mfc` de um CLI de migração em um **CLI único do MinusFramework**.
Cada módulo do framework (migrator, ORM, messaging, core, feature flags, telemetry)
torna-se uma DLL plugin que o `mfc` carrega sob demanda.

## Arquitetura

```
mfc.exe
├── MF.CLI.pas                → parser global + dispatch + help
├── MF.CLI.PluginContract.pas → IMFPlugin, IMFPluginCommand (interfaces COM-like)
├── MF.CLI.PluginLoader.pas   → descobre + carrega plugins
├── MF.CLI.AutoUpdate.pas     → update do mfc + plugins
└── Comandos built-in:
      help, version, plugin list, update

Plugin loader
  │
  ├── %LOCALAPPDATA%\MinusFramework\plugins\MinusMigrator.DLL
  │     → mfc migrate, status, rollback, tag, init
  │
  ├── %LOCALAPPDATA%\MinusFramework\plugins\MinusORM.DLL
  │     → mfc model generate, model add
  │
  ├── %LOCALAPPDATA%\MinusFramework\plugins\MinusMessaging.DLL
  │     → mfc msg send, msg consume, msg queue
  │
  ├── %LOCALAPPDATA%\MinusFramework\plugins\MinusCore.DLL
  │     → mfc config get, config set
  │
  ├── %LOCALAPPDATA%\MinusFramework\plugins\MinusFF.DLL
  │     → mfc feature list, feature enable, feature disable
  │
  └── %LOCALAPPDATA%\MinusFramework\plugins\MinusTelemetry.DLL
        → mfc telemetry export, telemetry status
```

## Contrato do Plugin (COM-like)

### Interface `IMFPluginCommand`

```delphi
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
```

### Interface `IMFPlugin`

```delphi
type
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
```

### Factory export (cada DLL plugin)

```delphi
function mfCreatePlugin(out APlugin: IMFPlugin): Integer; stdcall;
```

Retorna:
- `MM_OK (0)` — plugin criado com sucesso
- `MM_ERR (-1)` — falha (licença inválida, versão incompatível, etc.)

### Constantes compartilhadas

```delphi
const
  MM_OK = 0;
  MM_ERR = -1;
```

Ambas as interfaces usam `GUID` único para identificação via `QueryInterface`.
O `mfc` carrega a DLL, obtém `mfCreatePlugin`, chama e recebe `IMFPlugin`.

## Plugin Loader

### `MF.CLI.PluginLoader.pas`

```delphi
type
  TPluginLoader = class
  private
    FPlugins: TArray<IMFPlugin>;
    function GetPluginDir: string;
    function LoadFromDLL(const APath: string): IMFPlugin;
  public
    procedure LoadAll;
    function FindCommand(const ACmd: string): IMFPluginCommand;
    function FindPlugin(const AName: string): IMFPlugin;
    procedure PrintHelp;
    property Plugins: TArray<IMFPlugin> read FPlugins;
  end;
```

**Fluxo `LoadAll`:**
1. Determina `GetPluginDir` = `%LOCALAPPDATA%\MinusFramework\plugins\`
2. Cria diretório se não existir
3. Encontra todos `*.dll` no diretório
4. Para cada DLL: `LoadLibrary` → `GetProcAddress('mfCreatePlugin')` → chama factory
5. Se factory retorna `MM_OK`, adiciona `IMFPlugin` a `FPlugins`
6. Se falha, loga erro e continua (plugin corrompido não quebra os outros)

**Fluxo `FindCommand`:**
1. Para cada plugin em `FPlugins`:
2. Chama `plugin.GetCommand(ACmd)`
3. Se retornar não-nil, retorna `IMFPluginCommand`
4. Se nenhum plugin tem o comando, retorna nil

### `MF.CLI.pas` — dispatch modificado

```delphi
// Atual: switch/case com mm*()
// Novo:
var
  LCmd: IMFPluginCommand;
begin
  if LArgList[0] = '--help' then begin PluginLoader.PrintHelp; Exit; end;
  if LArgList[0] = '--version' then begin WriteLn(Version); Exit; end;
  if LArgList[0] = 'plugin' then begin HandlePluginCommand(LArgList); Exit; end;

  LCmd := FPluginLoader.FindCommand(LArgList[0]);
  if LCmd = nil then
  begin
    Escrever('Comando desconhecido: ' + LArgList[0], COR_VERMELHO);
    PrintHelp;
    Exit;
  end;
  LCmd.Execute(LArgList);
end;
```

## Comandos Built-in

| Comando | Descrição |
|---------|-----------|
| `mfc --help` | Lista global + comandos de cada plugin |
| `mfc --version` | Versão do `mfc.exe` |
| `mfc plugin list` | Lista plugins carregados |
| `mfc plugin info <nome>` | Detalhes de um plugin |
| `mfc update` | Auto-update do `mfc` + plugins |

## Plugins por Módulo

### 1. MinusMigrator.DLL (repo: `minusframework-migrator`)

**Mudanças:** Converter `MinusMigrator_DLL.dll` (exports `mm*`) para `MinusMigrator.DLL` (exporta `mfCreatePlugin`).

| Comando | Função |
|---------|--------|
| `mfc init -c <conn>` | `mmInit(conn)` |
| `mfc migrate -c <conn> -p <path>` | `mmMigrate(conn, path, dryRun)` |
| `mfc status -c <conn>` | `mmStatus(conn)` |
| `mfc rollback -c <conn> -n <steps>` | `mmRollback(conn, steps)` |
| `mfc tag <name> -c <conn>` | `mmTag(name, conn)` |

**Retirar:** Exports `mm*` avulsas. Manter internamente, mas expor via `IMFPluginCommand`.

**Testes:** Converter `Test.Migrator.API.pas` para testar `IMFPlugin` em vez de `mm*`.

### 2. MinusORM.DLL (repo: `minusframework-orm`)

**Mudanças:** Nova DLL plugin. ORM já existe como biblioteca, mas não tem CLI.

| Comando | Função |
|---------|--------|
| `mfc model generate -c <conn> -o <out>` | Gera classes ORM |
| `mfc model add <name> -c <conn>` | Adiciona entidade ao banco |

**Implementação:** Compila `MinusORM.DLL` com a factory. Usa `MF.ORM.*` units existentes.

### 3. MinusMessaging.DLL (repo: `minusframework-messaging`)

**Mudanças:** Converter `MinusMessaging_CLI.exe` em `MinusMessaging.DLL`.

| Comando | Função |
|---------|--------|
| `mfc msg send <queue> -m <body>` | Envia mensagem |
| `mfc msg consume <queue>` | Consome mensagens |
| `mfc msg queue list` | Lista filas |

**Retirar:** `MinusMessaging_CLI.dpr` — não precisa mais de executável separado.

### 4. MinusCore.DLL (repo: `minusframework-core`)

**Mudanças:** Nova DLL plugin. Core hoje não tem CLI.

| Comando | Função |
|---------|--------|
| `mfc config get <key>` | Lê config do framework |
| `mfc config set <key> <value>` | Escreve config |

**Implementação:** Usa `MF.Config.pas` que já existe.

### 5. MinusFF.DLL (repo: `minusframework-featureflags`)

**Mudanças:** Nova DLL plugin.

| Comando | Função |
|---------|--------|
| `mfc feature list` | Lista feature flags |
| `mfc feature enable <name>` | Ativa flag |
| `mfc feature disable <name>` | Desativa flag |

### 6. MinusTelemetry.DLL (repo: `minusframework-telemetry`)

**Mudanças:** Nova DLL plugin.

| Comando | Função |
|---------|--------|
| `mfc telemetry status` | Status do exportador |
| `mfc telemetry export` | Exporta dados |

## Auto-Update

**Mecanismo (estendido do spec anterior):**

1. `mfc update` → baixa versão mais recente do `mfc.exe` do GitHub
2. Para cada plugin carregado, verifica se há atualização:
   - Chama `IMFPPlugin.GetVersion` → compara com última release do GitHub do respectivo repo
   - Se desatualizado, baixa e substitui a `.dll`
3. Plugins órfãos (DLLs sem correspondente no registro) são removidos

**Repositórios de origem por plugin:**
- mfc.exe: `GabrielFerreiraMendes/minusframework-cli`
- MinusMigrator.DLL: `GabrielFerreiraMendes/minusframework-migrator`
- MinusORM.DLL: `GabrielFerreiraMendes/minusframework-orm`
- MinusMessaging.DLL: `GabrielFerreiraMendes/minusframework-messaging`
- MinusCore.DLL: `GabrielFerreiraMendes/minusframework-core`
- MinusFF.DLL: `GabrielFerreiraMendes/minusframework-featureflags`
- MinusTelemetry.DLL: `GabrielFerreiraMendes/minusframework-telemetry`

## Estratégia de Decomposição

O projeto é grande demais para um plano único. Decomposição em sub-projetos:

| Fase | Sub-projeto | Repositório | Depende de |
|------|-------------|-------------|------------|
| 1 | Plugin contract + PluginLoader | `minusframework-cli` | Nada |
| 2 | Migrator como plugin | `minusframework-migrator` | Fase 1 |
| 3 | Messaging como plugin | `minusframework-messaging` | Fase 1 |
| 4 | Core plugin | `minusframework-core` | Fase 1 |
| 5 | Feature Flags plugin | `minusframework-featureflags` | Fase 1 |
| 6 | Telemetry plugin | `minusframework-telemetry` | Fase 1 |
| 7 | ORM plugin | `minusframework-orm` | Fase 1 |
| 8 | Auto-update multi-plugin | `minusframework-cli` | Fases 2-7 |
| 9 | Retirar CLIs antigos | Todos | Fases 2-3 |

As fases 2-7 são independentes entre si (cada uma num repo diferente) e podem rodar em paralelo.

## Estratégia de Testes

| Tipo | O que testa | Framework |
|------|------------|-----------|
| Unit (contract) | `IMFPlugin`, `IMFPluginCommand` assinaturas | DUnitX |
| Unit (loader) | `LoadAll` com DLL mock | DUnitX |
| Unit (cada plugin) | `mfCreatePlugin` retorna comandos corretos | DUnitX |
| Integration | `FindCommand` → `Execute` com DLL real | DUnitX |
| E2E | Fluxo completo: `mfc init` → migrate → status | PowerShell + assert |

## CI/CD

Cada repositório de plugin tem seu workflow que:
1. Builda a `.dll` (Release, Win32)
2. Roda testes
3. Publica release no GitHub com a `.dll` + `VERSION`

O workflow do `mfc`:
1. Builda `mfc.exe`
2. Roda testes unitários (com mocks de plugin)
3. Roda testes de integração (com DLLs reais baixadas)
4. Publica release

## Próximos Passos

1. Implementar fase 1: `MF.CLI.PluginContract.pas` + `MF.CLI.PluginLoader.pas` + dispatch modificado
2. Implementar fase 2: converter `MinusMigrator_DLL.dll` → `MinusMigrator.DLL` plugin
3. Demais fases em paralelo (cada repo)
4. Fase 8: auto-update multi-plugin
5. Fase 9: limpeza dos CLIs antigos
