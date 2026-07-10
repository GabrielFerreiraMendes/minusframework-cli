program Test.MinusMigrator_CLI;

{$APPTYPE CONSOLE}

uses
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  Test.PluginContract in 'Test.PluginContract.pas',
  MF.CLI.PluginContract in '..\Source\MF.CLI.PluginContract.pas',
  MF.CLI.PluginLoader in '..\Source\MF.CLI.PluginLoader.pas',
  Test.PluginLoader in 'Test.PluginLoader.pas',
  MF.Migrator.AutoUpdate in '..\Source\MF.Migrator.AutoUpdate.pas',
  Test.AutoUpdate in 'Test.AutoUpdate.pas';

begin
  TDUnitX.RegisterTestFixture(Test.PluginContract.TTestPluginContract);
  TDUnitX.RegisterTestFixture(Test.PluginLoader.TTestPluginLoader);
  TDUnitX.RegisterTestFixture(Test.AutoUpdate.TTestAutoUpdate);
  TDUnitX.Run;
end.
