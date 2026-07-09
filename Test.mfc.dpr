program Test.mfc;

{$APPTYPE CONSOLE}

uses
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  Test.PluginContract in 'Source\Test.PluginContract.pas',
  MF.CLI.PluginContract in 'Source\MF.CLI.PluginContract.pas',
  MF.Migrator.AutoUpdate in 'Source\MF.Migrator.AutoUpdate.pas',
  Test.AutoUpdate in 'Source\Test.AutoUpdate.pas';

begin
  TDUnitX.RegisterTestFixture(Test.PluginContract.TTestPluginContract);
  TDUnitX.RegisterTestFixture(Test.AutoUpdate.TTestAutoUpdate);
  TDUnitX.Run;
end.