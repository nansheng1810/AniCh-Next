; AniCh Windows 安装包脚本（Inno Setup 6）
; 用法：
;   ISCC.exe installer\AniCh.iss
; 指定其他构建目录：
;   ISCC.exe /DBuildDir="D:\path\to\Release" installer\AniCh.iss

#define AppName "AniCh"
#define AppVersion "1.1.0"

#ifndef BuildDir
  #define BuildDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{8F3C2B1A-7D4E-4A62-9C1B-5E8F0D2A6B74}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=AniCh
AppPublisherURL=https://github.com/Sle2p/AniCh
DefaultDirName={autopf}\AniCh
DefaultGroupName=AniCh
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=AniCh-{#AppVersion}-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\AniCh.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
VersionInfoVersion=1.1.0.0
VersionInfoCompany=AniCh
VersionInfoDescription=AniCh 安装程序
VersionInfoProductName=AniCh
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
chinesesimplified.CreateDesktopIcon=创建桌面快捷方式(&D)
chinesesimplified.AdditionalIcons=附加快捷方式：
chinesesimplified.LaunchProgram=运行 %1
chinesesimplified.UninstallProgram=卸载 %1

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\AniCh"; Filename: "{app}\AniCh.exe"
Name: "{group}\卸载 AniCh"; Filename: "{uninstallexe}"
Name: "{autodesktop}\AniCh"; Filename: "{app}\AniCh.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\AniCh.exe"; Description: "{cm:LaunchProgram,AniCh}"; Flags: nowait postinstall skipifsilent
