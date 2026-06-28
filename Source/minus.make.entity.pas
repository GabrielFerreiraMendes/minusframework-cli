unit minus.make.entity;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  minus.command;

type
  TMakeEntityCommand = class(TCommandBase)
  protected
    function GetName: string; override;
    function GetDescription: string; override;
    function ParseFields(const AValue: string): TArray<TPair<string, string>>;
    function GenerateEntity(const AEntityName, AOutputDir: string;
      AFields: TArray<TPair<string, string>>): string;
  public
    function Execute(const Args: TArray<string>): Integer; override;
  end;

implementation

{ TMakeEntityCommand }

function TMakeEntityCommand.GetName: string;
begin
  Result := 'make:entity';
end;

function TMakeEntityCommand.GetDescription: string;
begin
  Result := 'Gera uma entidade ORM (POCO + atributos)';
end;

function TMakeEntityCommand.ParseFields(
  const AValue: string): TArray<TPair<string, string>>;
begin
  if AValue = '' then
    Exit(nil);
  var LList := TList<TPair<string, string>>.Create;
  try
    for var LPart in AValue.Split([','], '"') do
    begin
      var LPair := LPart.Trim.Split([':']);
      if Length(LPair) = 2 then
        LList.Add(TPair<string, string>.Create(LPair[0].Trim, LPair[1].Trim));
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TMakeEntityCommand.GenerateEntity(const AEntityName, AOutputDir: string;
  AFields: TArray<TPair<string, string>>): string;
var
  LClassName, LTableName, LUnitName: string;
  LSB: TStringBuilder;
  LField, LType: string;
begin
  LClassName := PascalCase(AEntityName);
  LTableName := LowerCase(AEntityName);
  if LTableName = '' then
    LTableName := 'minha_entidade';
  if LClassName = '' then
    LClassName := 'MinhaEntidade';

  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('unit Entities.' + LClassName + ';');
    LSB.AppendLine;
    LSB.AppendLine('interface');
    LSB.AppendLine;
    LSB.AppendLine('uses');
    LSB.AppendLine('  System.SysUtils,');
    LSB.AppendLine('  MF.Attributes;');
    LSB.AppendLine;
    LSB.AppendLine('type');
    LSB.AppendLine('  [Tabela(''' + LTableName + ''')]');
    LSB.AppendLine('  T' + LClassName + ' = class');
    LSB.AppendLine('  private');

    if Length(AFields) = 0 then
    begin
      AFields := TArray<TPair<string, string>>.Create(
        TPair<string, string>.Create('Id', 'Integer'),
        TPair<string, string>.Create('Nome', 'string'),
        TPair<string, string>.Create('CriadoEm', 'TDateTime')
      );
    end;

    for var LFPair in AFields do
    begin
      LField := LFPair.Key;
      LType := LFPair.Value;
      LSB.AppendLine('    F' + LField + ': ' + LType + ';');
    end;

    LSB.AppendLine('  public');

    for var LIdx := 0 to Length(AFields) - 1 do
    begin
      LField := AFields[LIdx].Key;
      LType := AFields[LIdx].Value;

      if (LIdx = 0) and (LowerCase(LField) = 'id') then
      begin
        LSB.AppendLine('    [ChavePrimaria]');
        LSB.AppendLine('    [AutoIncremento]');
      end;
      LSB.AppendLine('    [Campo(''' + LowerCase(LField) + ''')]');
      LSB.AppendLine('    property ' + LField + ': ' + LType +
        ' read F' + LField + ' write F' + LField + ';');
    end;

    LSB.AppendLine('  end;');
    LSB.AppendLine;
    LSB.AppendLine('implementation');
    LSB.AppendLine;
    LSB.AppendLine('end.');

    LUnitName := 'Entities.' + LClassName + '.pas';
    if AOutputDir <> '' then
      LUnitName := TPath.Combine(AOutputDir, LUnitName);

    WriteFile(LUnitName, LSB.ToString);
    Result := LUnitName;
  finally
    LSB.Free;
  end;
end;

function TMakeEntityCommand.Execute(const Args: TArray<string>): Integer;
var
  LEntityName: string;
  LOutputDir: string;
  LFieldsRaw: string;
  LFields: TArray<TPair<string, string>>;
  LFile: string;
begin
  if Length(Args) < 1 then
  begin
    WriteLn('Uso: minus make:entity <NomeEntidade> [--fields=Campo1:Tipo1,Campo2:Tipo2] [--output=dir]');
    Exit(1);
  end;

  LEntityName := Args[0];

  LOutputDir := 'src\Entities';
  LFieldsRaw := '';

  for var I := 1 to Length(Args) - 1 do
  begin
    if Args[I].StartsWith('--fields=') then
      LFieldsRaw := Args[I].Substring('--fields='.Length)
    else if Args[I].StartsWith('--output=') then
      LOutputDir := Args[I].Substring('--output='.Length);
  end;

  LFields := ParseFields(LFieldsRaw);

  LFile := GenerateEntity(LEntityName, LOutputDir, LFields);

  WriteLn('  Criado: ' + LFile);
  Result := 0;
end;

end.
