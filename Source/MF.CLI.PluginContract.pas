unit MF.CLI.PluginContract;

{* Plugin contract — COM-like interfaces for MinusFramework CLI plugin architecture.
   DLL plugins implement IMFPlugin via the exported mfCreatePlugin factory.
   The CLI discovers and dispatches commands through IMFPluginCommand. *}

interface

const
  MM_OK  = 0;
  MM_ERR = -1;

type
  IImfPluginCommand = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetName: string; stdcall;
    function GetDescription: string; stdcall;
    function GetSyntax: string; stdcall;
    function Execute(const AArgs: TArray<string>): Integer; stdcall;
  end;

  IImfPlugin = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function GetName: string; stdcall;
    function GetVersion: string; stdcall;
    function GetCommand(const AName: string): IImfPluginCommand; stdcall;
    function GetCommands: TArray<IImfPluginCommand>; stdcall;
  end;

  IMFPluginCommand = IImfPluginCommand;
  IMFPlugin = IImfPlugin;

implementation

end.
