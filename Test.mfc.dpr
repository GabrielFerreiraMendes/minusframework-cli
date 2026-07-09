program Test.mfc;

{$APPTYPE CONSOLE}

uses
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  MF.Migrator.AutoUpdate in 'Source\MF.Migrator.AutoUpdate.pas',
  Test.AutoUpdate in 'Source\Test.AutoUpdate.pas';

begin
  TDUnitX.RegisterTestFixture(Test.AutoUpdate.TTestAutoUpdate);
  TDUnitX.Run;
end.