program minus;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  minus.router in 'minus.router.pas',
  minus.command in 'minus.command.pas',
  minus.make.entity in 'minus.make.entity.pas',
  minus.new.api in 'minus.new.api.pas';

begin
  TRouter.Run;
end.
