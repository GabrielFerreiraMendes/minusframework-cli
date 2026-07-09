# mfc — MinusFramework CLI

CLI de migracao de banco de dados. Consome `MinusMigrator_DLL.dll`.

Disponivel em tres tiers: **Free** (migrator + ORM), **Pro** (changelog, snapshot),
**Enterprise** (lint, diff-databases).

## Instalacao

```powershell
.\install.ps1           # build Debug + instala global
.\install.ps1 -Release  # build Release + instala global
```

Apos abrir um novo terminal:

```cmd
mfc --help
mfc init -c sqlite://C:\test.db
mfc migrate -c sqlite://C:\test.db -p .\migrations
```

## Comandos

| Comando | Tier | Descricao |
|---------|------|-----------|
| `init` | Free | Inicializa banco |
| `migrate` | Free | Executa migrations |
| `status` | Free | Status das migrations |
| `rollback` | Free | Reverte migrations |
| `tag` | Free | Cria tag |
| `add-migration` | Free | Cria migration |
| `generate-models` | Free | Gera classes ORM |
| `auto-migrate` | Pro | Auto-migration |
| `diff-changelog` | Pro | Diff entities |
| `changelog-apply` | Pro | Aplica changelog |
| `snapshot` | Pro | Cria snapshot |
| `diff-snapshots` | Pro | Diff snapshots |
| `lint` | Enterprise | Lint SQL |
| `lint-rules` | Enterprise | Mostra regras |
| `diff-databases` | Enterprise | Diff bancos |

## Build

```cmd
msbuild mfc.dproj /p:Config=Debug /p:Platform=Win32
```

Requer RAD Studio 11.3 (Delphi) com FireDAC.
