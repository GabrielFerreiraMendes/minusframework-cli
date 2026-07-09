unit MF.Migrator.CLI;

{* Ponto de entrada CLI do MinusMigrator.
   Interpreta argumentos e despacha comandos via MinusMigrator_DLL.dll.
   A validacao de tier (free/pro/enterprise) e feita pela DLL. *}

interface

procedure Run;

implementation

uses
  System.SysUtils, System.StrUtils,
  Winapi.Windows,
  MF.Migrator.API;

const
  COR_PADRAO   = 7;
  COR_VERDE    = 10;
  COR_AMARELO  = 14;
  COR_VERMELHO = 12;
  COR_CINZA    = 8;
  COR_BRANCO   = 15;

function ParseArgValue(const AArgs: TArray<string>; const AFlag: string;
  var AIndex: Integer): string;
begin
  if (AIndex + 1 < Length(AArgs)) then
  begin
    Result := AArgs[AIndex + 1];
    Inc(AIndex);
  end
  else
    Result := '';
end;

procedure Escrever(const ATexto: string; ACor: Byte = COR_PADRAO);
var
  LHandle: THandle;
  LConsoleInfo: TConsoleScreenBufferInfo;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if (LHandle <> INVALID_HANDLE_VALUE) and GetConsoleScreenBufferInfo(LHandle, LConsoleInfo) then
  begin
    SetConsoleTextAttribute(LHandle, ACor);
    Write(ATexto);
    SetConsoleTextAttribute(LHandle, LConsoleInfo.wAttributes);
  end
  else
    Write(ATexto);
end;

procedure PrintHelp;
begin
  Escrever('mfc - MinusFramework Migrator CLI', COR_VERDE);
  WriteLn;
  WriteLn;
  Escrever('Uso:', COR_AMARELO);
  WriteLn;
  Escrever('  mfc init -c <string_conexao>', COR_BRANCO);
  WriteLn;
  Escrever('  mfc migrate -c <string_conexao> -p <caminho_migrations> [--dry-run] [--context <nome>]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc status -c <string_conexao> -p <caminho_migrations> [--format json|yaml]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc rollback -c <string_conexao> -p <caminho_migrations> [-n <passos>] [--tag <nome>]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc tag <nome> -c <string_conexao>', COR_BRANCO);
  WriteLn;
  Escrever('  mfc add-migration <descricao> -c <string_conexao> -e <caminho_entidades> [-p <caminho_migrations>]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc generate-models -c <string_conexao> -o <caminho_saida> [-ns <namespace>]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc auto-migrate -c <string_conexao> -e <caminho_entidades> [--dry-run] [--force]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc diff-changelog -c <string_conexao> -e <caminho_entidades> -f <arquivo_saida> [--format liquibase|json|yaml]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc changelog-apply -c <string_conexao> -f <arquivo_changelog>', COR_BRANCO);
  WriteLn;
  Escrever('  mfc snapshot -c <string_conexao> -f <arquivo_saida>', COR_BRANCO);
  WriteLn;
  Escrever('  mfc diff-snapshots -f <snapshot1> -f2 <snapshot2> -o <arquivo_saida> [--format liquibase|json|yaml]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc diff-databases -c <origem> -c2 <destino> [--format json|yaml]', COR_BRANCO);
  WriteLn;
  Escrever('  mfc lint -f <arquivo_sql>', COR_BRANCO);
  WriteLn;
  Escrever('  mfc lint-rules', COR_BRANCO);
  WriteLn;
  Escrever('  mfc --help', COR_BRANCO);
  WriteLn;
  WriteLn;
  Escrever('Formatos de string de conexao:', COR_AMARELO);
  WriteLn;
  Escrever('  sqlite://<caminho_arquivo>', COR_CINZA);
  WriteLn;
  Escrever('  firebird://<host>:<porta>/<caminho>?user=<user>&password=<pass>', COR_CINZA);
  WriteLn;
  Escrever('  postgresql://<host>:<porta>/<database>?user=<user>&password=<pass>', COR_CINZA);
  WriteLn;
  Escrever('  mysql://<host>:<porta>/<database>?user=<user>&password=<pass>', COR_CINZA);
  WriteLn;
  Escrever('  mssql://<host>:<porta>/<database>?user=<user>&password=<pass>', COR_CINZA);
  WriteLn;
  Escrever('  oracle://<host>:<porta>/<service_name>?user=<user>&password=<pass>', COR_CINZA);
  WriteLn;
  Escrever('  mariadb://<host>:<porta>/<database>?user=<user>&password=<pass>', COR_CINZA);
  WriteLn;
end;

function RunCommand(const AFunc: TFunc<Integer>): Boolean;
var
  LResult: Integer;
begin
  LResult := AFunc;
  if LResult <> MM_OK then
  begin
    Escrever('Erro: ' + string(mmGetLastError), COR_VERMELHO);
    WriteLn;
    Exit(False);
  end;
  Result := True;
end;

procedure Run;
var
  LArgList: TArray<string>;
  I: Integer;
  LCommand: string;
  LConnection: string;
  LConnection2: string;
  LPath: string;
  LEntities: string;
  LDescription: string;
  LOutput: string;
  LNamespace: string;
  LFile: string;
  LSteps: Integer;
  LDryRun: Boolean;
  LForce: Boolean;
  LContexto: string;
  LTag: string;
  LFormato: string;
  LFile2: string;
  LStatusResult: string;
begin
  SetLength(LArgList, ParamCount);
  for I := 0 to ParamCount - 1 do
    LArgList[I] := ParamStr(I + 1);

  if (Length(LArgList) > 0) and ((LArgList[0] = '--version') or (LArgList[0] = '-v')) then
  begin
    WriteLn('mfc versao ' + string(mmVersion));
    Exit;
  end;

  if (Length(LArgList) = 0) or (LArgList[0] = '--help') or (LArgList[0] = '-h') then
  begin
    PrintHelp;
    Exit;
  end;

  LCommand := LowerCase(LArgList[0]);
  LConnection := '';
  LConnection2 := '';
  LPath := '';
  LEntities := '';
  LSteps := 1;
  LDryRun := False;
  LForce := False;
  LContexto := '';
  LTag := '';
  LFormato := '';
  LOutput := '';
  LNamespace := '';
  LFile := '';
  LFile2 := '';

  I := 1;

  if (LCommand = 'add-migration') or (LCommand = 'tag') then
  begin
    if I < Length(LArgList) then
    begin
      if LCommand = 'add-migration' then
        LDescription := LArgList[I]
      else
        LTag := LArgList[I];
      Inc(I);
    end;
  end;

  while I < Length(LArgList) do
  begin
    if LArgList[I] = '-c' then
      LConnection := ParseArgValue(LArgList, '-c', I)
    else if LArgList[I] = '-c2' then
      LConnection2 := ParseArgValue(LArgList, '-c2', I)
    else if LArgList[I] = '-p' then
      LPath := ParseArgValue(LArgList, '-p', I)
    else if LArgList[I] = '-e' then
      LEntities := ParseArgValue(LArgList, '-e', I)
    else if LArgList[I] = '-n' then
      LSteps := StrToIntDef(ParseArgValue(LArgList, '-n', I), 1)
    else if LArgList[I] = '-o' then
      LOutput := ParseArgValue(LArgList, '-o', I)
    else if LArgList[I] = '-ns' then
      LNamespace := ParseArgValue(LArgList, '-ns', I)
    else if LArgList[I] = '--context' then
      LContexto := ParseArgValue(LArgList, '--context', I)
    else if LArgList[I] = '--format' then
      LFormato := ParseArgValue(LArgList, '--format', I)
    else if LArgList[I] = '--tag' then
      LTag := ParseArgValue(LArgList, '--tag', I)
    else if LArgList[I] = '--dry-run' then
      LDryRun := True
    else if LArgList[I] = '--force' then
      LForce := True
    else if (LArgList[I] = '-f') then
      LFile := ParseArgValue(LArgList, '-f', I)
    else if (LArgList[I] = '-f2') then
      LFile2 := ParseArgValue(LArgList, '-f2', I);
    Inc(I);
  end;

  if LConnection = '' then
  begin
    Escrever('Erro: String de conexao (-c) obrigatoria.', COR_VERMELHO);
    WriteLn;
    Exit;
  end;

  if LPath = '' then
    LPath := GetCurrentDir;

  if LCommand = 'init' then
    RunCommand(function: Integer begin Result := mmInit(PChar(LConnection)); end)

  else if LCommand = 'migrate' then
    RunCommand(function: Integer begin Result := mmMigrate(PChar(LConnection), PChar(LPath), Ord(LDryRun)); end)

  else if LCommand = 'rollback' then
    RunCommand(function: Integer begin Result := mmRollback(PChar(LConnection), PChar(LPath), LSteps, PChar(LContexto), PChar(LTag)); end)

  else if LCommand = 'tag' then
  begin
    if LTag = '' then
    begin
      Escrever('Erro: Nome da tag obrigatorio.'#13#10'Uso: mfc tag <nome> -c <string_conexao>', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmTag(PChar(LTag), PChar(LConnection)); end);
  end

  else if LCommand = 'add-migration' then
  begin
    if LDescription = '' then
    begin
      Escrever('Erro: Descricao obrigatoria para add-migration.'#13#10'Uso: mfc add-migration <descricao> -c <string_conexao> -e <caminho_entidades>', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    if LEntities = '' then
    begin
      Escrever('Erro: Caminho das entidades (-e) obrigatorio para add-migration.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmAddMigration(PChar(LDescription), PChar(LConnection), PChar(LEntities), PChar(LPath)); end);
  end

  else if LCommand = 'generate-models' then
  begin
    LOutput := IfThen(LOutput = '', GetCurrentDir, LOutput);
    RunCommand(function: Integer begin Result := mmGenerateModels(PChar(LConnection), PChar(LOutput), PChar(LNamespace)); end);
  end

  else if LCommand = 'auto-migrate' then
  begin
    if LEntities = '' then
    begin
      Escrever('Erro: Caminho das entidades (-e) obrigatorio para auto-migrate.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmAutoMigrate(PChar(LConnection), PChar(LEntities), Ord(LDryRun), Ord(LForce)); end);
  end

  else if LCommand = 'diff-changelog' then
  begin
    if LEntities = '' then
    begin
      Escrever('Erro: Caminho das entidades (-e) obrigatorio para diff-changelog.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    if LFile = '' then
    begin
      Escrever('Erro: Arquivo de saida (-f) obrigatorio para diff-changelog.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmDiffChangelog(PChar(LConnection), PChar(LEntities), PChar(LFile), PChar(LFormato)); end);
  end

  else if LCommand = 'changelog-apply' then
  begin
    if LFile = '' then
    begin
      Escrever('Erro: Arquivo de changelog (-f) obrigatorio para changelog-apply.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmApplyChangelog(PChar(LConnection), PChar(LFile)); end);
  end

  else if LCommand = 'snapshot' then
  begin
    if LFile = '' then
    begin
      Escrever('Erro: Arquivo de saida (-f) obrigatorio para snapshot.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmSnapshot(PChar(LConnection), PChar(LFile)); end);
  end

  else if LCommand = 'diff-snapshots' then
  begin
    if LFile = '' then
    begin
      Escrever('Erro: Primeiro snapshot (-f) obrigatorio para diff-snapshots.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    if LFile2 = '' then
    begin
      Escrever('Erro: Segundo snapshot (-f2) obrigatorio.'#13#10'Uso: mfc diff-snapshots -f <snapshot1> -f2 <snapshot2> -o <saida>', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    if LOutput = '' then
    begin
      Escrever('Erro: Arquivo de saida (-o) obrigatorio para diff-snapshots.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmDiffSnapshots(PChar(LFile), PChar(LFile2), PChar(LOutput), PChar(LFormato)); end);
  end

  else if LCommand = 'diff-databases' then
  begin
    if LConnection2 = '' then
    begin
      Escrever('Erro: String de conexao destino (-c2) obrigatoria para diff-databases.'#13#10'Uso: mfc diff-databases -c <origem> -c2 <destino> [--format json|yaml]', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmDiffDatabases(PChar(LConnection), PChar(LConnection2), PChar(LFormato)); end);
  end

  else if LCommand = 'lint' then
  begin
    if LFile = '' then
    begin
      Escrever('Erro: Arquivo SQL (-f) obrigatorio para lint.', COR_VERMELHO);
      WriteLn;
      Exit;
    end;
    RunCommand(function: Integer begin Result := mmLint(PChar(LFile)); end);
  end

  else if LCommand = 'lint-rules' then
    Write(string(mmLintRules))
  else if LCommand = 'status' then
  begin
    LStatusResult := string(mmStatus(PChar(LConnection), PChar(LPath), PChar(LFormato)));
    if LStatusResult <> '' then
      WriteLn(LStatusResult);
  end

  else
  begin
    Escrever('Comando desconhecido: ' + LCommand, COR_VERMELHO);
    WriteLn;
    PrintHelp;
  end;
end;

end.
