unit Test.PluginContract;

interface

uses
  DUnitX.TestFramework,
  MF.CLI.PluginContract;

type
  [TestFixture]
  TTestPluginContract = class
  public
    [Test]
    procedure TestExecute_ReturnsMM_OK;

    [Test]
    procedure TestPlugin_Name_Matches;

    [Test]
    procedure TestPlugin_GetCommand_ByName;

    [Test]
    procedure TestPlugin_GetCommands_ReturnsAll;

    [Test]
    procedure TestPlugin_GetCommand_Unknown;
  end;

implementation

uses
  System.SysUtils;

type
  TTestCommand = class(TInterfacedObject, IMFPluginCommand)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    function GetName: string; stdcall;
    function GetDescription: string; stdcall;
    function GetSyntax: string; stdcall;
    function Execute(const AArgs: TArray<string>): Integer; stdcall;
  end;

  TTestPlugin = class(TInterfacedObject, IMFPlugin)
  private
    FName: string;
    FVersion: string;
  public
    constructor Create(const AName, AVersion: string);
    function GetName: string; stdcall;
    function GetVersion: string; stdcall;
    function GetCommand(const AName: string): IMFPluginCommand; stdcall;
    function GetCommands: TArray<IMFPluginCommand>; stdcall;
  end;

constructor TTestCommand.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

function TTestCommand.GetName: string;
begin
  Result := FName;
end;

function TTestCommand.GetDescription: string;
begin
  Result := 'Test command ' + FName;
end;

function TTestCommand.GetSyntax: string;
begin
  Result := FName + ' <args>';
end;

function TTestCommand.Execute(const AArgs: TArray<string>): Integer;
begin
  Result := MM_OK;
end;

constructor TTestPlugin.Create(const AName, AVersion: string);
begin
  inherited Create;
  FName := AName;
  FVersion := AVersion;
end;

function TTestPlugin.GetName: string;
begin
  Result := FName;
end;

function TTestPlugin.GetVersion: string;
begin
  Result := FVersion;
end;

function TTestPlugin.GetCommand(const AName: string): IMFPluginCommand;
begin
  if SameText(AName, 'test') then
    Result := TTestCommand.Create('test')
  else
    Result := nil;
end;

function TTestPlugin.GetCommands: TArray<IMFPluginCommand>;
begin
  SetLength(Result, 1);
  Result[0] := TTestCommand.Create('test');
end;

{ TTestPluginContract }

procedure TTestPluginContract.TestExecute_ReturnsMM_OK;
var
  LCmd: IMFPluginCommand;
begin
  LCmd := TTestCommand.Create('ping');
  Assert.AreEqual(MM_OK, LCmd.Execute(nil),
    'Execute must return MM_OK for success');
end;

procedure TTestPluginContract.TestPlugin_Name_Matches;
var
  LPlugin: IMFPlugin;
begin
  LPlugin := TTestPlugin.Create('MinusMigrator', '1.0.0');
  Assert.AreEqual('MinusMigrator', LPlugin.GetName,
    'Plugin name must match constructor');
end;

procedure TTestPluginContract.TestPlugin_GetCommand_ByName;
var
  LPlugin: IMFPlugin;
  LCmd: IMFPluginCommand;
begin
  LPlugin := TTestPlugin.Create('TestPlugin', '1.0.0');
  LCmd := LPlugin.GetCommand('test');
  Assert.IsNotNull(LCmd, 'GetCommand must return a command for known name');
  Assert.AreEqual('test', LCmd.GetName);
end;

procedure TTestPluginContract.TestPlugin_GetCommands_ReturnsAll;
var
  LPlugin: IMFPlugin;
  LCmds: TArray<IMFPluginCommand>;
begin
  LPlugin := TTestPlugin.Create('TestPlugin', '1.0.0');
  LCmds := LPlugin.GetCommands;
  Assert.AreEqual(1, Length(LCmds),
    'GetCommands must return exactly one command for this stub');
end;

procedure TTestPluginContract.TestPlugin_GetCommand_Unknown;
var
  LPlugin: IMFPlugin;
  LCmd: IMFPluginCommand;
begin
  LPlugin := TTestPlugin.Create('TestPlugin', '1.0.0');
  LCmd := LPlugin.GetCommand('unknown');
  Assert.IsNull(LCmd,
    'GetCommand must return nil for unknown command name');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginContract);

end.
