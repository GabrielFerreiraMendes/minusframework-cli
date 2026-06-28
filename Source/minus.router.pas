unit minus.router;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  minus.command;

type
  TRouter = class
  public
    class procedure Run;
  end;

implementation

uses
  minus.make.entity,
  minus.new.api;

class procedure TRouter.Run;
var
  LCmdName: string;
  LCmd: ICommand;
  LArgs: TArray<string>;
  LStartIdx, I, LExitCode: Integer;
begin
  TCommandRegistry.RegisterCommand(TMakeEntityCommand.Create);
  TCommandRegistry.RegisterCommand(TNewApiCommand.Create);

  if ParamCount = 0 then
  begin
    WriteLn('MinusFrameWork CLI v1.0.0');
    WriteLn;
    WriteLn('Comandos disponiveis:');
    for var LC in TCommandRegistry.All do
      WriteLn('  ' + LC.Name.PadRight(22) + LC.Description);
    WriteLn;
    WriteLn('Uso: minus <comando> [argumentos]');
    Exit;
  end;

  LCmd := nil;
  LStartIdx := 1;

  if ParamCount >= 2 then
  begin
    LCmdName := ParamStr(1) + ' ' + ParamStr(2);
    LCmd := TCommandRegistry.Find(LCmdName);
    if LCmd <> nil then
      LStartIdx := 3;
  end;

  if LCmd = nil then
  begin
    LCmdName := ParamStr(1);
    LCmd := TCommandRegistry.Find(LCmdName);
    if LCmd <> nil then
      LStartIdx := 2;
  end;

  if LCmd = nil then
  begin
    WriteLn('Comando desconhecido: ' + ParamStr(1));
    WriteLn('Use "minus" sem argumentos para listar os comandos.');
    ExitCode := 1;
    Exit;
  end;

  SetLength(LArgs, ParamCount - LStartIdx + 1);
  for I := LStartIdx to ParamCount do
    LArgs[I - LStartIdx] := ParamStr(I);

  LExitCode := LCmd.Execute(LArgs);
  ExitCode := LExitCode;
end;

end.
