unit minus.new.api;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.IOUtils,
  minus.command;

type
  TNewApiCommand = class(TCommandBase)
  protected
    function GetName: string; override;
    function GetDescription: string; override;
    function MakeDpr(const AProjectName: string): string;
    function MakeController(const AProjectName: string): string;
    function MakeConfig(const AProjectName: string): string;
    function MakeDockerCompose: string;
  public
    function Execute(const Args: TArray<string>): Integer; override;
  end;

implementation

{ TNewApiCommand }

function TNewApiCommand.GetName: string;
begin
  Result := 'new api';
end;

function TNewApiCommand.GetDescription: string;
begin
  Result := 'Cria um projeto REST API (Horse + MinusORM)';
end;

function TNewApiCommand.MakeDpr(const AProjectName: string): string;
var
  LSB: TStringBuilder;
  LUnit: string;
begin
  LUnit := PascalCase(AProjectName);
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('program ' + LUnit + ';');
    LSB.AppendLine;
    LSB.AppendLine('{$APPTYPE CONSOLE}');
    LSB.AppendLine;
    LSB.AppendLine('uses');
    LSB.AppendLine('  System.SysUtils,');
    LSB.AppendLine('  Horse,');
    LSB.AppendLine('  Horse.Jhonson,');
    LSB.AppendLine('  Controllers.Home in ''Controllers\HomeController.pas'';');
    LSB.AppendLine;
    LSB.AppendLine('begin');
    LSB.AppendLine('  THorse.Use(Jhonson);');
    LSB.AppendLine;
    LSB.AppendLine('  THorse.Get(''/'',');
    LSB.AppendLine('    procedure(Req: THorseRequest; Res: THorseResponse)');
    LSB.AppendLine('    begin');
    LSB.AppendLine('      Res.Send(''{');
    LSB.AppendLine(
      '        "service": "' + LowerCase(AProjectName) + '",');
    LSB.AppendLine('        "version": "1.0.0"');
    LSB.AppendLine('      }'');');
    LSB.AppendLine('    end);');
    LSB.AppendLine;
    LSB.AppendLine('  THorse.Get(''/health'',');
    LSB.AppendLine('    procedure(Req: THorseRequest; Res: THorseResponse)');
    LSB.AppendLine('    begin');
    LSB.AppendLine('      Res.Send(''{ "status": "healthy" }'');');
    LSB.AppendLine('    end);');
    LSB.AppendLine;
    LSB.AppendLine('  THorse.Listen(9000);');
    LSB.AppendLine('end.');
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TNewApiCommand.MakeController(const AProjectName: string): string;
var
  LSB: TStringBuilder;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('unit Controllers.Home;');
    LSB.AppendLine;
    LSB.AppendLine('interface');
    LSB.AppendLine;
    LSB.AppendLine('uses');
    LSB.AppendLine('  Horse;');
    LSB.AppendLine;
    LSB.AppendLine('procedure RegistrarRotas;');
    LSB.AppendLine;
    LSB.AppendLine('implementation');
    LSB.AppendLine;
    LSB.AppendLine('uses');
    LSB.AppendLine('  System.SysUtils,');
    LSB.AppendLine('  System.JSON;');
    LSB.AppendLine;
    LSB.AppendLine('procedure Home(Req: THorseRequest; Res: THorseResponse);');
    LSB.AppendLine('begin');
    LSB.AppendLine('  Res.Send(''{ "message": "Bem-vindo ao ' +
      LowerCase(AProjectName) + '" }'');');
    LSB.AppendLine('end;');
    LSB.AppendLine;
    LSB.AppendLine('procedure RegistrarRotas;');
    LSB.AppendLine('begin');
    LSB.AppendLine('  THorse.Get(''/api'', Home);');
    LSB.AppendLine('end;');
    LSB.AppendLine;
    LSB.AppendLine('end.');
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TNewApiCommand.MakeConfig(const AProjectName: string): string;
var
  LSB: TStringBuilder;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('{');
    LSB.AppendLine('  "name": "' + LowerCase(AProjectName) + '",');
    LSB.AppendLine('  "version": "1.0.0",');
    LSB.AppendLine('  "description": "API gerada pelo MinusFrameWork CLI",');
    LSB.AppendLine('  "dependencies": {');
    LSB.AppendLine('    "horse": "^3.1.0",');
    LSB.AppendLine('    "minusframework-core": "^1.0.0"');
    LSB.AppendLine('  }');
    LSB.AppendLine('}');
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TNewApiCommand.MakeDockerCompose: string;
var
  LSB: TStringBuilder;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('version: "3.8"');
    LSB.AppendLine;
    LSB.AppendLine('services:');
    LSB.AppendLine('  database:');
    LSB.AppendLine('    image: postgres:16-alpine');
    LSB.AppendLine('    environment:');
    LSB.AppendLine('      POSTGRES_DB: app');
    LSB.AppendLine('      POSTGRES_USER: app');
    LSB.AppendLine('      POSTGRES_PASSWORD: app123');
    LSB.AppendLine('    ports:');
    LSB.AppendLine('      - "5432:5432"');
    LSB.AppendLine('    volumes:');
    LSB.AppendLine('      - pgdata:/var/lib/postgresql/data');
    LSB.AppendLine;
    LSB.AppendLine('volumes:');
    LSB.AppendLine('  pgdata:');
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TNewApiCommand.Execute(const Args: TArray<string>): Integer;
var
  LProjectName: string;
  LRoot: string;
begin
  if Length(Args) < 1 then
  begin
    WriteLn('Uso: minus new api <NomeProjeto> [--dir=output]');
    Exit(1);
  end;

  LProjectName := Args[0];
  LRoot := LProjectName;

  for var I := 1 to Length(Args) - 1 do
    if Args[I].StartsWith('--dir=') then
      LRoot := Args[I].Substring('--dir='.Length);

  if TDirectory.Exists(LRoot) then
  begin
    WriteLn('Erro: Diretório "' + LRoot + '" já existe.');
    Exit(1);
  end;

  CreateDir(LRoot + '\src\Controllers');
  CreateDir(LRoot + '\src\Models');
  CreateDir(LRoot + '\src\Services');
  CreateDir(LRoot + '\src\Entities');

  WriteFile(LRoot + '\src\' + PascalCase(LProjectName) + '.dpr',
    MakeDpr(LProjectName));
  WriteFile(LRoot + '\src\Controllers\HomeController.pas',
    MakeController(LProjectName));
  WriteFile(LRoot + '\minus.json', MakeConfig(LProjectName));
  WriteFile(LRoot + '\docker-compose.yml', MakeDockerCompose);

  WriteLn('  Projeto "' + LProjectName + '" criado em: ' + LRoot);
  WriteLn;
  WriteLn('  Para compilar:');
  WriteLn('    cd ' + LRoot);
  WriteLn('    dcc32 src\' + PascalCase(LProjectName) + '.dpr');
  WriteLn;
  WriteLn('  Para executar:');
  WriteLn('    src\' + PascalCase(LProjectName) + '.exe');
  Result := 0;
end;

end.
