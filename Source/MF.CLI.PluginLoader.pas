unit MF.CLI.PluginLoader;

interface

uses
  System.Generics.Collections,
  Winapi.Windows,
  MF.CLI.PluginContract;

type
  TPluginFactory = function(out APlugin: IMFPlugin): Integer; stdcall;

  TPluginLoader = class
  private
    FPlugins: TArray<IMFPlugin>;
    FHandles: TArray<HMODULE>;
  public
    destructor Destroy; override;
    class function GetPluginDir: string;
    procedure LoadAll;
    function FindCommand(const AName: string): IMFPluginCommand;
    function FindPlugin(const AName: string): IMFPlugin;
    function GetPlugins: TArray<IMFPlugin>;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

destructor TPluginLoader.Destroy;
var
  LHandle: HMODULE;
begin
  FPlugins := nil;
  for LHandle in FHandles do
    FreeLibrary(LHandle);
  FHandles := nil;
  inherited Destroy;
end;

class function TPluginLoader.GetPluginDir: string;
begin
  Result := TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'MinusFramework'), 'plugins');
end;

procedure TPluginLoader.LoadAll;
var
  LDir: string;
  LFiles: TArray<string>;
  LFile: string;
  LHandle: HMODULE;
  LFactory: TPluginFactory;
  LPlugin: IMFPlugin;
  LResult: Integer;
begin
  LDir := GetPluginDir;
  if not TDirectory.Exists(LDir) then
    Exit;

  try
    LFiles := TDirectory.GetFiles(LDir, '*.dll');
  except
    Exit;
  end;
  for LFile in LFiles do
  begin
    try
      LHandle := LoadLibrary(PChar(LFile));
    except
      LHandle := 0;
    end;
    if LHandle = 0 then
      Continue;

    try
      @LFactory := GetProcAddress(LHandle, 'mfCreatePlugin');
    except
      @LFactory := nil;
    end;
    if not Assigned(@LFactory) then
    begin
      FreeLibrary(LHandle);
      Continue;
    end;

    LPlugin := nil;
    try
      LResult := LFactory(LPlugin);
    except
      LResult := MM_ERR;
    end;
    if (LResult = MM_OK) and Assigned(LPlugin) then
    begin
      SetLength(FPlugins, Length(FPlugins) + 1);
      FPlugins[High(FPlugins)] := LPlugin;
      SetLength(FHandles, Length(FHandles) + 1);
      FHandles[High(FHandles)] := LHandle;
    end
    else
      FreeLibrary(LHandle);
  end;
end;

function TPluginLoader.FindCommand(const AName: string): IMFPluginCommand;
var
  LPlugin: IMFPlugin;
begin
  for LPlugin in FPlugins do
  begin
    try
      Result := LPlugin.GetCommand(AName);
    except
      Result := nil;
    end;
    if Assigned(Result) then
      Exit;
  end;
  Result := nil;
end;

function TPluginLoader.FindPlugin(const AName: string): IMFPlugin;
var
  LPlugin: IMFPlugin;
begin
  for LPlugin in FPlugins do
  begin
    try
      if SameText(LPlugin.GetName, AName) then
        Exit(LPlugin);
    except
      { skip plugin on error }
    end;
  end;
  Result := nil;
end;

function TPluginLoader.GetPlugins: TArray<IMFPlugin>;
begin
  Result := Copy(FPlugins);
end;

end.
