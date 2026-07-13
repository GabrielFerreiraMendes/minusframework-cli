# mfc — MinusFramework CLI

CLI de scaffolding e migracao de banco de dados. Consome `MinusMigrator_DLL.dll`.

O CLI é **Free** (MIT) — todos os comandos sao gratuitos, sem subdivisoes Pro/Enterprise internas.

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

| Comando | Descricao |
|---------|-----------|
| `init` | Inicializa banco |
| `migrate` | Executa migrations |
| `status` | Status das migrations |
| `rollback` | Reverte migrations |
| `tag` | Cria tag |
| `add-migration` | Cria migration |
| `generate-models` | Gera classes ORM |
| `auto-migrate` | Auto-migration |
| `diff-changelog` | Diff entities |
| `changelog-apply` | Aplica changelog |
| `snapshot` | Cria snapshot |
| `diff-snapshots` | Diff snapshots |
| `lint` | Lint SQL |
| `lint-rules` | Mostra regras |
| `diff-databases` | Diff bancos |

## Build

```cmd
msbuild mfc.dproj /p:Config=Debug /p:Platform=Win32
```

Requer RAD Studio 11.3 (Delphi) com FireDAC.
