program mfc;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MF.Migrator.CLI in 'Source\MF.Migrator.CLI.pas',
  MF.Migrator.API in 'Source\MF.Migrator.API.pas',
  MF.Migrator.AutoUpdate in 'Source\MF.Migrator.AutoUpdate.pas';

begin
  MF.Migrator.AutoUpdate.AutoUpdate;
  Run;
end.
