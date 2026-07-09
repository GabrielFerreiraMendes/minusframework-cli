unit MF.CLI.PluginLoader;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Winapi.Windows,
  MF.CLI.PluginContract;

type
  TPluginFactory = function(out APlugin: IMFPlugin): Integer; stdcall;

  TPluginLoader = class
  private
    FPlugins: TObjectList<IMFPlugin>;
    FHandles: TList<HMODULE>;
  public
    constructor Create;
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

constructor TPluginLoader.Create;
begin
  inherited Create;
  FPlugins := TObjectList<IMFPlugin>.Create(False);
  FHandles := TList<HMODULE>.Create;
end;

destructor TPluginLoader.Destroy;
var
  LHandle: HMODULE;
begin
  FPlugins.Free;
  for LHandle in FHandles do
    FreeLibrary(LHandle);
  FHandles.Free;
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

  LFiles := TDirectory.GetFiles(LDir, '*.dll');
  for LFile in LFiles do
  begin
    LHandle := LoadLibrary(PChar(LFile));
    if LHandle = 0 then
      Continue;

    @LFactory := GetProcAddress(LHandle, 'mfCreatePlugin');
    if not Assigned(@LFactory) then
    begin
      FreeLibrary(LHandle);
      Continue;
    end;

    LPlugin := nil;
    LResult := LFactory(LPlugin);
    if (LResult = MM_OK) and Assigned(LPlugin) then
    begin
      FPlugins.Add(LPlugin);
      FHandles.Add(LHandle);
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
    Result := LPlugin.GetCommand(AName);
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
    if SameText(LPlugin.GetName, AName) then
      Exit(LPlugin);
  end;
  Result := nil;
end;

function TPluginLoader.GetPlugins: TArray<IMFPlugin>;
begin
  Result := FPlugins.ToArray;
end;

end.
