unit MF.Migrator.AutoUpdate;

interface

function GetDLLPath: string;
function CheckForUpdate: Boolean;
function DownloadDLL(const AURL: string): Boolean;
function ExtractAndReplace(const AZipPath: string): Boolean;
function AutoUpdate: Boolean;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Zip,
  Winapi.Windows, Winapi.WinINet,
  System.Net.HttpClient;

type
  TmmPing = function: Integer; stdcall;
  TmmVersionCheck = function(out AURL: PChar): Integer; stdcall;
  TmmGetLastError = function: PChar; stdcall;

function GetDLLPath: string;
begin
  Result := TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'MinusMigrator\bin'), 'MinusMigrator_DLL.dll');
end;

function CheckForUpdate: Boolean;
var
  DLLHandle: HMODULE;
  mmPing: TmmPing;
  mmVersionCheck: TmmVersionCheck;
  mmGetLastError: TmmGetLastError;
  ReleaseURL: PChar;
  DLLPath: string;
begin
  DLLPath := GetDLLPath;

  if not TFile.Exists(DLLPath) then
    Exit(True);

  DLLHandle := LoadLibrary(PChar(DLLPath));
  if DLLHandle = 0 then
    Exit(True);

  try
    @mmPing := GetProcAddress(DLLHandle, 'mmPing');
    @mmVersionCheck := GetProcAddress(DLLHandle, 'mmVersionCheck');
    @mmGetLastError := GetProcAddress(DLLHandle, 'mmGetLastError');

    if not Assigned(@mmPing) then
      Exit(True);

    if mmPing <> 0 then
      Exit(True);

    if Assigned(@mmVersionCheck) then
    begin
      ReleaseURL := nil;
      if mmVersionCheck(ReleaseURL) = 0 then
        Exit(True);
    end;

    Result := False;
  finally
    FreeLibrary(DLLHandle);
  end;
end;

function DownloadDLL(const AURL: string): Boolean;
var
  HTTP: THTTPClient;
  Response: IHTTPResponse;
  TempFile: string;
  FS: TFileStream;
begin
  TempFile := TPath.GetTempFileName;
  try
    HTTP := THTTPClient.Create;
    try
      Response := HTTP.Get(AURL);
      if Response.StatusCode <> 200 then
        Exit(False);
      Response.ContentStream.Position := 0;
      FS := TFileStream.Create(TempFile, fmCreate);
      try
        FS.CopyFrom(Response.ContentStream, 0);
      finally
        FS.Free;
      end;
    finally
      HTTP.Free;
    end;
    Result := ExtractAndReplace(TempFile);
  finally
    if TFile.Exists(TempFile) then
      TFile.Delete(TempFile);
  end;
end;

function ExtractAndReplace(const AZipPath: string): Boolean;
var
  DestDir: string;
  DLLPath: string;
begin
  DestDir := TPath.GetDirectoryName(GetDLLPath);
  DLLPath := GetDLLPath;

  if not TDirectory.Exists(DestDir) then
    TDirectory.CreateDirectory(DestDir);

  try
    TZipFile.ExtractZipFile(AZipPath, DestDir);
  except
    Exit(False);
  end;

  Result := TFile.Exists(DLLPath);
end;

function AutoUpdate: Boolean;
var
  DLLPath: string;
  DLLHandle: HMODULE;
  mmPing: TmmPing;
  URL: string;
begin
  DLLPath := GetDLLPath;

  if not TFile.Exists(DLLPath) then
  begin
    if CheckForUpdate then
    begin
      URL := 'https://api.github.com/repos/GabrielFerreiraMendes/minusframework-migrator/releases/latest';
      if not DownloadDLL(URL) then
        Exit(False);
    end;
    Exit(TFile.Exists(DLLPath));
  end;

  DLLHandle := LoadLibrary(PChar(DLLPath));
  if DLLHandle = 0 then
  begin
    if CheckForUpdate then
    begin
      URL := 'https://api.github.com/repos/GabrielFerreiraMendes/minusframework-migrator/releases/latest';
      if not DownloadDLL(URL) then
        Exit(False);
    end;
    Exit(TFile.Exists(DLLPath));
  end;
  try
    @mmPing := GetProcAddress(DLLHandle, 'mmPing');
    if Assigned(@mmPing) and (mmPing <> 0) then
    begin
      if CheckForUpdate then
      begin
        URL := 'https://api.github.com/repos/GabrielFerreiraMendes/minusframework-migrator/releases/latest';
        if not DownloadDLL(URL) then
          Exit(False);
      end;
      Exit(TFile.Exists(DLLPath));
    end;

    if CheckForUpdate then
    begin
      URL := 'https://api.github.com/repos/GabrielFerreiraMendes/minusframework-migrator/releases/latest';
      DownloadDLL(URL);
    end;

    Result := TFile.Exists(DLLPath);
  finally
    FreeLibrary(DLLHandle);
  end;
end;

end.