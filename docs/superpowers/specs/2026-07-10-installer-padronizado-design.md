# Design: Instalador Padronizado Per-Repo

## Motivação

Cada repositorio minusframework tem suporte a instalacao local via `install.ps1` para workflow de dev/testes/release. Atualmente ha inconsistencias:

- `cli/install.ps1` instala em `%LOCALAPPDATA%\MinusFramework\bin`
- `migrator/install.ps1` instala em `%LOCALAPPDATA%\MinusMigrator\bin`
- `migrator/install.ps1` compila o CLI (`MinusMigrator_CLI.dpr`), criando dependencia cross-repo

O meta-repo ja possui o instalador oficial (Inno Setup + pipeline) para usuarios finais. Os `install.ps1` per-repo sao ferramentas internas de dev.

## Paths Padronizados

| Ferramenta | Destino |
|-----------|---------|
| CLI (`MinusMigrator_CLI.exe`) | `%LOCALAPPDATA%\MinusFramework\bin\MinusMigrator_CLI.exe` |
| Migrator DLL (`MinusMigrator.dll`) | `%LOCALAPPDATA%\MinusFramework\plugins\MinusMigrator.dll` |
| Wrapper (`mfc.cmd`) | `%LOCALAPPDATA%\MinusFramework\bin\mfc.cmd` |
| PATH adicionado | `%LOCALAPPDATA%\MinusFramework\bin\` |

## Responsabilidades

### `cli/install.ps1`

- Verifica compilado em `Win32\$Config\MinusMigrator_CLI.exe`
- Instala `.exe` em `%LOCALAPPDATA%\MinusFramework\bin\`
- Cria wrapper `mfc.cmd`
- Adiciona `bin\` ao PATH do usuario (se necessario)

### `migrator/install.ps1`

- Verifica compilado em `Win32\$Config\MinusMigrator.dll`
- Instala `.dll` em `%LOCALAPPDATA%\MinusFramework\plugins\`
- **Nao** builda o CLI (zero dependencia cross-repo)
- **Nao** mexe no PATH (quem faz isso e o CLI)

## Regras

- Cada repo instala APENAS seus proprios artefatos
- Paths sao consistentes com plugin architecture design (`plugins\` para DLLs, `bin\` para EXEs)
- Nenhuma dependencia de build entre repos
- Meta-repo (Inno Setup) e o unico que agregra multiplos modulos
