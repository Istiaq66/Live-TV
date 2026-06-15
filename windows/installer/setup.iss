; Inno Setup script for Drishto (Windows).
; Packages the ENTIRE Flutter Release folder — the bare .exe will not run
; without the bundled mpv/media_kit DLLs and the data/ + flutter_assets dirs.
;
; Build locally:  iscc /DAppVersion=1.0.0 windows\installer\setup.iss
; CI passes /DAppVersion from the git tag.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "Drishto"
#define AppExeName "live_tv.exe"
#define AppPublisher "Live TV"
; Release build output, relative to this .iss file (windows\installer\).
#define ReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{B7E9F2C4-1A3D-4E6B-9C8A-2F5D7E0A1B34}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user install needs no admin elevation; flip to "admin" for all-users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\dist
OutputBaseFilename=Drishto-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Recurse the whole Release dir (exe, *.dll, data\, flutter_assets, etc.).
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent