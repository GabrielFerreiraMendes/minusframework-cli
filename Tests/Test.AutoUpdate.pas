unit Test.AutoUpdate;

interface

uses
  DUnitX.TestFramework,
  MF.Migrator.AutoUpdate;

type
  [TestFixture]
  TTestAutoUpdate = class
  public
    [Test]
    procedure TestGetDLLPath_ReturnsExpectedPath;

    [Test]
    procedure TestCheckForUpdate_DLLNotFound;
  end;

implementation

uses
  System.SysUtils, System.IOUtils;

procedure TTestAutoUpdate.TestGetDLLPath_ReturnsExpectedPath;
var
  Path: string;
begin
  Path := GetDLLPath;
  Assert.IsTrue(Path.EndsWith('MinusMigrator_DLL.dll'), 'Path should end with MinusMigrator_DLL.dll');
  Assert.Contains(Path, GetEnvironmentVariable('LOCALAPPDATA'), 'Path should contain LOCALAPPDATA');
end;

procedure TTestAutoUpdate.TestCheckForUpdate_DLLNotFound;
var
  DLLPath: string;
begin
  DLLPath := GetDLLPath;
  if TFile.Exists(DLLPath) then
    TFile.Delete(DLLPath);
  Assert.IsTrue(CheckForUpdate, 'CheckForUpdate should return True when DLL does not exist');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAutoUpdate);

end.