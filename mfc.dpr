program mfc;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MF.Migrator.CLI in 'Source\MF.Migrator.CLI.pas',
  MF.Migrator.API in 'Source\MF.Migrator.API.pas';

begin
  Run;
end.
