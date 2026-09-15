; Inno Setup script - FormUp Windows installer
; Dipakai CI (workflow build.yml): ISCC /DAppVersion=x.y.z formup.iss
; Output: build/windows/installer/FormUp-Setup-<versi>.exe (single file)

#define AppName "FormUp"
#define AppExeName "form_up.exe"

#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

[Setup]
AppId={{8F2C1B7E-5A44-4E7D-9B3A-6C51D0F2E9A1}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=FormUp
DefaultDirName={autopf}\FormUp
DisableProgramGroupPage=yes
; Installer bisa dijalankan tanpa admin (install per-user) — hindari UAC.
PrivilegesRequired=lowest
OutputDir=..\..\build\windows\installer
OutputBaseFilename=FormUp-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#AppName}
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Seluruh isi folder Release (exe + dll + data) dibundel jadi satu installer.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
