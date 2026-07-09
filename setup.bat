@echo off
REM Cria o repositorio minusframework-cli no GitHub e faz push inicial
REM Requer: gh autenticado, git configurado

set REPO=minusframework-cli

echo === Criando repositorio %REPO% no GitHub ===
gh repo create %REPO% --public --description "MinusFramework CLI (mfc)" --source "." --push

if %ERRORLEVEL% EQU 0 (
  echo.
  echo Repositorio criado e codigo enviado com sucesso!
  echo   https://github.com/%%USERNAME%%/%REPO%
) else (
  echo.
  echo Falha ao criar repositorio. Verifique sua autenticacao:
  echo   gh auth login
)
