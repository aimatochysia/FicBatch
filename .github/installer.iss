; Inno Setup Script for FicBatch Windows Installer
#ifndef MyAppVersion
  #define MyAppVersion "1.0"
#endif

[Setup]
AppId={{FICBATCH-A1B2-C3D4-E5F6-123456789ABC}
AppName=FicBatch
AppVersion={#MyAppVersion}
AppPublisher=FicBatch
DefaultDirName={autopf}\FicBatch
DefaultGroupName=FicBatch
AllowNoIcons=yes
OutputBaseFilename=ficbatch-windows
OutputDir=.
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\ficbatch.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FicBatch"; Filename: "{app}\ficbatch.exe"
Name: "{group}\{cm:UninstallProgram,FicBatch}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\FicBatch"; Filename: "{app}\ficbatch.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ficbatch.exe"; Description: "{cm:LaunchProgram,FicBatch}"; Flags: nowait postinstall skipifsilent
