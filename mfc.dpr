program mfc;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MF.Migrator.CLI in 'Source\MF.Migrator.CLI.pas',
  MF.CLI.PluginContract in 'Source\MF.CLI.PluginContract.pas',
  MF.CLI.PluginLoader in 'Source\MF.CLI.PluginLoader.pas';

begin
  Run;
end.
