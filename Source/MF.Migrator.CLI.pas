unit MF.Migrator.CLI;

{* Ponto de entrada CLI do MinusMigrator.
   Interpreta argumentos e despacha comandos via MinusMigrator_DLL.dll.
   A validacao de tier (free/pro/enterprise) e feita pela DLL. *}

interface

function Run: Integer;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  MF.CLI.PluginContract,
  MF.CLI.PluginLoader;

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

var
  FPluginLoader: TPluginLoader;

function Run: Integer;
var
  LArgList: TArray<string>;
  I: Integer;
  LPlugin: IMFPlugin;
  LCmd: IMFPluginCommand;
begin
  Result := 0;
  SetLength(LArgList, ParamCount);
  for I := 0 to ParamCount - 1 do
    LArgList[I] := ParamStr(I + 1);

  if (Length(LArgList) > 0) and ((LArgList[0] = '--version') or (LArgList[0] = '-v')) then
  begin
    WriteLn('mfc');
    Exit;
  end;

  if (Length(LArgList) = 0) or (LArgList[0] = '--help') or (LArgList[0] = '-h') then
  begin
    PrintHelp;
    Exit;
  end;

  if LArgList[0] = 'plugin' then
  begin
    if (Length(LArgList) > 1) and (LArgList[1] = 'list') then
    begin
      if Assigned(FPluginLoader) then
        for LPlugin in FPluginLoader.GetPlugins do
          try
            WriteLn(LPlugin.GetName + ' v' + LPlugin.GetVersion);
          except
            WriteLn('(plugin error)');
          end;
      Exit;
    end;
    if Length(LArgList) > 1 then
      Escrever('Comando desconhecido: plugin ' + LArgList[1], COR_VERMELHO)
    else
      Escrever('Comando plugin requer subcomando (ex: plugin list)', COR_VERMELHO);
    WriteLn;
    Result := 1;
    Exit;
  end;

  try
    LCmd := FPluginLoader.FindCommand(LArgList[0]);
  except
    LCmd := nil;
  end;
  if Assigned(LCmd) then
  begin
    try
      if LCmd.Execute(LArgList) <> MM_OK then
      begin
        Escrever('Erro: comando falhou.', COR_VERMELHO);
        WriteLn;
      end;
    except
      Escrever('Erro: execucao do comando falhou.', COR_VERMELHO);
      WriteLn;
    end;
  end
  else
  begin
    Escrever('Comando desconhecido: ' + LArgList[0], COR_VERMELHO);
    WriteLn;
    PrintHelp;
    Result := 1;
  end;
end;

initialization
  try
    FPluginLoader := TPluginLoader.Create;
    FPluginLoader.LoadAll;
  except
    FPluginLoader := nil;
  end;

finalization
  if Assigned(FPluginLoader) then
    FPluginLoader.Free;

end.
