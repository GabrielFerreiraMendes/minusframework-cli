unit minus.command;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.IOUtils;

type
  ICommand = interface
    ['{D14A3B8F-5C2E-4A91-9B67-4F8C3D0E1A2B}']
    function GetName: string;
    function GetDescription: string;
    function Execute(const Args: TArray<string>): Integer;
    property Name: string read GetName;
    property Description: string read GetDescription;
  end;

  TCommandBase = class(TInterfacedObject, ICommand)
  protected
    function GetName: string; virtual; abstract;
    function GetDescription: string; virtual; abstract;
    function WriteFile(const APath, AContent: string): Boolean;
    function CreateDir(const APath: string): Boolean;
    function PascalCase(const AValue: string): string;
    function CamelCase(const AValue: string): string;
    function Pluralize(const AValue: string): string;
    function Indent(const AText: string; const ACount: Integer): string;
  public
    function Execute(const Args: TArray<string>): Integer; virtual; abstract;
    property Name: string read GetName;
    property Description: string read GetDescription;
  end;

  TCommandRegistry = class
  private
    class var FCommands: TDictionary<string, ICommand>;
    class constructor Create;
    class destructor Destroy;
  public
    class procedure RegisterCommand(const ACmd: ICommand);
    class function Find(const AName: string): ICommand;
    class function All: TArray<ICommand>;
  end;

implementation

{ TCommandBase }

function TCommandBase.WriteFile(const APath, AContent: string): Boolean;
begin
  try
    TDirectory.CreateDirectory(TPath.GetDirectoryName(APath));
    TFile.WriteAllText(APath, AContent, TEncoding.UTF8);
    Result := True;
  except
    Result := False;
  end;
end;

function TCommandBase.CreateDir(const APath: string): Boolean;
begin
  try
    TDirectory.CreateDirectory(APath);
    Result := True;
  except
    Result := False;
  end;
end;

function TCommandBase.PascalCase(const AValue: string): string;
var
  I: Integer;
  LNextUp: Boolean;
begin
  Result := '';
  LNextUp := True;
  for I := 1 to Length(AValue) do
  begin
    if CharInSet(AValue[I], ['_', '-', ' ']) then
      LNextUp := True
    else if LNextUp then
    begin
      Result := Result + UpperCase(AValue[I]);
      LNextUp := False;
    end
    else
      Result := Result + LowerCase(AValue[I]);
  end;
end;

function TCommandBase.CamelCase(const AValue: string): string;
begin
  Result := PascalCase(AValue);
  if Result <> '' then
    Result[1] := LowerCase(Result[1])[1];
end;

function TCommandBase.Pluralize(const AValue: string): string;
begin
  if AValue = '' then
    Exit(AValue);
  var LLast := LowerCase(AValue[Length(AValue)]);
  if CharInSet(LLast, ['s', 'x', 'z']) then
    Result := AValue + 'es'
  else if CharInSet(LLast, ['o']) then
    Result := AValue + 's'
  else
    Result := AValue + 's';
end;

function TCommandBase.Indent(const AText: string; const ACount: Integer): string;
begin
  Result := StringOfChar(' ', ACount) + AText;
end;

{ TCommandRegistry }

class constructor TCommandRegistry.Create;
begin
  FCommands := TDictionary<string, ICommand>.Create;
end;

class destructor TCommandRegistry.Destroy;
begin
  FCommands.Free;
end;

class procedure TCommandRegistry.RegisterCommand(const ACmd: ICommand);
begin
  FCommands.AddOrSetValue(ACmd.Name.ToLower, ACmd);
end;

class function TCommandRegistry.Find(const AName: string): ICommand;
begin
  if not FCommands.TryGetValue(AName.ToLower, Result) then
    Result := nil;
end;

class function TCommandRegistry.All: TArray<ICommand>;
begin
  Result := FCommands.Values.ToArray;
end;

end.
