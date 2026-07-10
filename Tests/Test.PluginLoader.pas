unit Test.PluginLoader;

interface

uses
  DUnitX.TestFramework,
  MF.CLI.PluginContract,
  MF.CLI.PluginLoader;

type
  [TestFixture]
  TTestPluginLoader = class
  public
    [Test]
    procedure TestGetPluginDir_ReturnsExpected;

    [Test]
    procedure TestLoadAll_NoDirectory_NoCrash;

    [Test]
    procedure TestFindCommand_Empty_ReturnsNil;
  end;

implementation

uses
  System.SysUtils;

procedure TTestPluginLoader.TestGetPluginDir_ReturnsExpected;
var
  LDir: string;
begin
  LDir := TPluginLoader.GetPluginDir;
  Assert.IsTrue(LDir.Contains('MinusFramework'),
    'Plugin directory must contain MinusFramework in path');
  Assert.IsTrue(LDir.Contains('plugins'),
    'Plugin directory must contain plugins in path');
end;

procedure TTestPluginLoader.TestLoadAll_NoDirectory_NoCrash;
var
  LLoader: TPluginLoader;
begin
  LLoader := TPluginLoader.Create;
  try
    LLoader.LoadAll;
  finally
    LLoader.Free;
  end;
end;

procedure TTestPluginLoader.TestFindCommand_Empty_ReturnsNil;
var
  LLoader: TPluginLoader;
begin
  LLoader := TPluginLoader.Create;
  try
    Assert.IsNull(LLoader.FindCommand('nonexistent'),
      'FindCommand must return nil when no plugins are loaded');
  finally
    LLoader.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginLoader);

end.
