unit MF.Migrator.API;

{* MinusMigrator DLL API — importa funcoes exportadas por MinusMigrator_DLL.dll *}

interface

const
  MM_OK = 0;
  MM_ERR = -1;

{ Core lifecycle }
function mmInit(AConnection: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmMigrate(AConnection, APath: PChar; ADryRun: Integer): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmRollback(AConnection, APath: PChar; ASteps: Integer; AContext, ATag: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmStatus(AConnection, APath, AFormat: PChar): PChar; stdcall; external 'MinusMigrator_DLL.dll';

{ Scaffold }
function mmAddMigration(ADescription, AConnection, AEntitiesPath, AMigrationsPath: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmAutoMigrate(AConnection, AEntitiesPath: PChar; ADryRun, AForce: Integer): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmGenerateModels(AConnection, AOutputPath, ANamespace: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';

{ Changelog / Snapshot }
function mmDiffChangelog(AConnection, AEntitiesPath, AOutputFile, AFormat: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmApplyChangelog(AConnection, AChangelogFile: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmSnapshot(AConnection, AOutputFile: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmDiffSnapshots(AFile1, AFile2, AOutputFile, AFormat: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';

{ Utilities }
function mmDiffDatabases(AOrigin, ADestiny, AFormat: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmLint(AFilePath: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmTag(ATagName, AConnection: PChar): Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmLintRules: PChar; stdcall; external 'MinusMigrator_DLL.dll';

{ Info }
function mmPing: Integer; stdcall; external 'MinusMigrator_DLL.dll';
function mmVersion: PChar; stdcall; external 'MinusMigrator_DLL.dll';
function mmGetLastError: PChar; stdcall; external 'MinusMigrator_DLL.dll';

implementation

end.
