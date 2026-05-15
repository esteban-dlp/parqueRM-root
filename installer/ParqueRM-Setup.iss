; ============================================================
; ParqueRM-Setup.iss
; Inno Setup 6 script -- ParqueRM production installer
;
; Defines passed from build-installer.ps1:
;   /DAppVersion=1.0.0
;   /DBuildNumber=202501011200
;   /DReleaseDir=C:\...\parqueRM-root\release
;
; Install modes:
;   - Full (server)  : SQL Server + backend + frontend + services
;   - Client-only    : creates browser shortcut only
; ============================================================

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef BuildNumber
  #define BuildNumber "dev"
#endif
#ifndef ReleaseDir
  #define ReleaseDir "..\release"
#endif

#define AppName      "ParqueRM"
#define AppPublisher "Parque Nacional"
#define AppURL       "http://localhost"
#define DefaultDir   "C:\ParqueRM"
#define SetupExeName "ParqueRM-Setup-v" + AppVersion

[Setup]
AppId={{8A2C1F4D-3B7E-4F9A-8C2D-1E5B6F9A3C7D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={#DefaultDir}
DefaultGroupName={#AppName}
OutputDir={#ReleaseDir}
OutputBaseFilename={#SetupExeName}
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
ShowLanguageDialog=no
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\tools\open-parquerm.bat
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName} Installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
DisableFinishedPage=no
CloseApplications=force

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Types]
Name: "server";     Description: "Instalacion completa (servidor)"
Name: "clientonly"; Description: "Solo cliente (acceso desde navegador)"

[Components]
Name: "server";     Description: "Servidor completo (Backend + Frontend + Base de datos)"; Types: server; Flags: fixed
Name: "clientonly"; Description: "Acceso de cliente (solo acceso LAN)";                   Types: clientonly; Flags: fixed

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Opciones adicionales"

[Files]
; --- Full server installation ---------------------------------------------------
; Backend application (compiled dist + node_modules)
Source: "{#ReleaseDir}\app\backend\*"; DestDir: "{app}\app\backend"; \
  Flags: recursesubdirs ignoreversion createallsubdirs; Components: server

; Frontend dist (config.json generated at install time -- not bundled here)
Source: "{#ReleaseDir}\app\frontend\dist\*"; DestDir: "{app}\app\frontend\dist"; \
  Flags: recursesubdirs ignoreversion createallsubdirs; Components: server

; Database init + migration scripts
Source: "{#ReleaseDir}\app\database\*"; DestDir: "{app}\app\database"; \
  Flags: recursesubdirs ignoreversion createallsubdirs; Components: server

; Config templates (used by generate-config.ps1)
Source: "{#ReleaseDir}\app\config\*"; DestDir: "{app}\app\config"; \
  Flags: recursesubdirs ignoreversion createallsubdirs; Components: server

; Tool scripts (.bat) and installer scripts (.ps1)
Source: "{#ReleaseDir}\app\tools\*"; DestDir: "{app}\tools"; \
  Flags: recursesubdirs ignoreversion createallsubdirs; Components: server

; Runtime binaries (SQL Server Express, Node.js, Caddy, WinSW)
Source: "{#ReleaseDir}\runtime\*"; DestDir: "{app}\runtime"; \
  Flags: recursesubdirs ignoreversion createallsubdirs; Components: server

; Release version metadata
Source: "{#ReleaseDir}\version.json"; DestDir: "{app}"; \
  Flags: ignoreversion; Components: server

[Dirs]
Name: "{app}\logs\backend";  Components: server
Name: "{app}\logs\frontend"; Components: server
Name: "{app}\logs\updates";  Components: server
Name: "{app}\logs\db-init";  Components: server
Name: "{app}\backups";       Components: server
Name: "{app}\config";        Components: server
Name: "{app}\services";      Components: server

[Icons]
; --- Server shortcuts -----------------------------------------------------------
Name: "{group}\Abrir ParqueRM";          Filename: "{app}\tools\open-parquerm.bat";       Components: server
Name: "{group}\Ver estado de ParqueRM";  Filename: "{app}\tools\show-status.bat";         Components: server
Name: "{group}\Iniciar servicios";       Filename: "{app}\tools\start-services.bat";      Components: server
Name: "{group}\Detener servicios";       Filename: "{app}\tools\stop-services.bat";       Components: server
Name: "{group}\Crear backup";            Filename: "{app}\tools\backup-db.bat";           Components: server
Name: "{group}\Restaurar backup";        Filename: "{app}\tools\restore-db.bat";          Components: server
Name: "{group}\Cambiar IP del servidor"; Filename: "{app}\tools\change-server-ip.bat";    Components: server
Name: "{group}\Aplicar actualizacion";  Filename: "{app}\tools\apply-update.bat";        Components: server

; --- Desktop shortcut (server) --------------------------------------------------
Name: "{userdesktop}\ParqueRM";          Filename: "{app}\tools\open-parquerm.bat"; \
  Components: server; Tasks: desktopicon

; --- Client-only shortcuts ------------------------------------------------------
Name: "{group}\Abrir ParqueRM";          Filename: "{app}\open-parquerm-client.url";      Components: clientonly
Name: "{userdesktop}\ParqueRM";          Filename: "{app}\open-parquerm-client.url"; \
  Components: clientonly; Tasks: desktopicon

[Run]
; --- Step 1: Configure firewall (open ports 80 and 3000) -----------------------
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\installer-scripts\configure-firewall.ps1"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Configurando firewall..."; \
  Components: server

; --- Step 2: Initialize SQL Server and database --------------------------------
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\installer-scripts\initialize-db.ps1"" \
    -InstallDir ""{app}"" \
    -RuntimeCacheDir ""{app}\runtime"" \
    -DbPassword ""{code:GetDbPassword}"" \
    -InitScriptsDir ""{app}\app\database\init"" \
    -MigrationsDir ""{app}\app\database\migrations"" \
    -SkipSqlServerInstall:{code:SkipSqlInstall}"; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Inicializando base de datos..."; \
  Components: server

; --- Step 3: Generate configuration files (backend .env, frontend config.json) -
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\installer-scripts\generate-config.ps1"" \
    -InstallDir ""{app}"" \
    -ServerIp ""{code:GetServerIp}"" \
    -DbPassword ""{code:GetDbPassword}"" \
    -JwtSecret ""{code:GetJwtSecret}"" \
    -JwtRefreshSecret ""{code:GetJwtRefreshSecret}"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Generando configuracion..."; \
  Components: server

; --- Step 4: Install Windows services (backend + frontend) ---------------------
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\installer-scripts\install-services.ps1"" \
    -InstallDir ""{app}"" \
    -RuntimeDir ""{app}\runtime"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Instalando servicios de Windows..."; \
  Components: server

; --- Step 5: Show final URLs (visible window so user sees the result) ----------
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\installer-scripts\show-final-url.ps1"" \
    -InstallDir ""{app}"""; \
  Flags: shellexec waituntilterminated; \
  StatusMsg: "Instalacion completada."; \
  Components: server

[UninstallRun]
; Stop and remove Windows services first
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\installer-scripts\uninstall-services.ps1"" \
    -InstallDir ""{app}"""; \
  Flags: runhidden waituntilterminated

; Remove firewall rules
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\installer-scripts\configure-firewall.ps1"" -Remove"; \
  Flags: runhidden waituntilterminated

[UninstallDelete]
; Remove log files on uninstall (backups are NOT deleted -- they are in {app}\backups)
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\services"
; NOTE: {app}\backups and {app}\app\backend\.env are intentionally NOT removed.
; The user may need to recover data after uninstall.

[Code]
{ ===== Custom installer wizard pages ===== }

var
  ServerIpPage:       TInputQueryWizardPage;
  DbPasswordPage:     TInputQueryWizardPage;
  JwtPage:            TInputQueryWizardPage;
  ClientServerIpPage: TInputQueryWizardPage;
  GServerIp:          String;
  GDbPassword:        String;
  GJwtSecret:         String;
  GJwtRefreshSecret:  String;

function GenerateSecret(len: Integer): String;
var
  chars: String;
  i, idx: Integer;
begin
  chars := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
  Result := '';
  for i := 1 to len do begin
    idx := (Random(Length(chars)) + 1);
    Result := Result + Copy(chars, idx, 1);
  end;
end;

procedure InitializeWizard;
begin
  { Server IP page -- shown only in server mode }
  ServerIpPage := CreateInputQueryPage(wpSelectComponents,
    'Direccion IP del servidor',
    'Ingrese la IP de esta computadora en la red local.',
    'Las demas computadoras usaran esta IP para conectarse. Ejemplo: 192.168.1.10');
  ServerIpPage.Add('IP del servidor:', False);
  ServerIpPage.Values[0] := '192.168.1.10';

  { Client-only server IP page -- shown only in client-only mode }
  ClientServerIpPage := CreateInputQueryPage(wpSelectComponents,
    'IP del servidor ParqueRM',
    'Ingrese la IP del servidor donde ParqueRM esta instalado.',
    'Ejemplo: 192.168.1.10');
  ClientServerIpPage.Add('IP del servidor ParqueRM:', False);
  ClientServerIpPage.Values[0] := '192.168.1.10';

  { DB password page }
  DbPasswordPage := CreateInputQueryPage(ServerIpPage.ID,
    'Contrasena de base de datos',
    'Ingrese la contrasena para SQL Server.',
    'Esta contrasena se usara para el usuario "sa" de SQL Server. Minimo 8 caracteres.');
  DbPasswordPage.Add('Contrasena:', True);
  DbPasswordPage.Add('Confirmar contrasena:', True);

  { JWT secrets page -- pre-filled with random secrets }
  JwtPage := CreateInputQueryPage(DbPasswordPage.ID,
    'Secretos JWT',
    'Secretos para firmar tokens de acceso y refresco.',
    'Se generaron secretos aleatorios. Puede dejarlos como estan o ingresar los suyos.');
  JwtPage.Add('JWT Secret:', False);
  JwtPage.Add('JWT Refresh Secret:', False);
  JwtPage.Values[0] := GenerateSecret(64);
  JwtPage.Values[1] := GenerateSecret(64);
end;

function ShouldSkipPage(PageID: Integer): Boolean;
var
  isServer: Boolean;
begin
  isServer := WizardIsComponentSelected('server');
  if (PageID = ServerIpPage.ID) and (not isServer) then Result := True
  else if (PageID = DbPasswordPage.ID) and (not isServer) then Result := True
  else if (PageID = JwtPage.ID) and (not isServer) then Result := True
  else if (PageID = ClientServerIpPage.ID) and isServer then Result := True
  else Result := False;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if CurPageID = ServerIpPage.ID then begin
    if Trim(ServerIpPage.Values[0]) = '' then begin
      MsgBox('La IP del servidor no puede estar vacia.', mbError, MB_OK);
      Result := False; Exit;
    end;
    GServerIp := Trim(ServerIpPage.Values[0]);
  end;

  if CurPageID = ClientServerIpPage.ID then begin
    if Trim(ClientServerIpPage.Values[0]) = '' then begin
      MsgBox('La IP del servidor no puede estar vacia.', mbError, MB_OK);
      Result := False; Exit;
    end;
    GServerIp := Trim(ClientServerIpPage.Values[0]);
  end;

  if CurPageID = DbPasswordPage.ID then begin
    if DbPasswordPage.Values[0] = '' then begin
      MsgBox('La contrasena no puede estar vacia.', mbError, MB_OK);
      Result := False; Exit;
    end;
    if Length(DbPasswordPage.Values[0]) < 8 then begin
      MsgBox('La contrasena debe tener al menos 8 caracteres.', mbError, MB_OK);
      Result := False; Exit;
    end;
    if DbPasswordPage.Values[0] <> DbPasswordPage.Values[1] then begin
      MsgBox('Las contrasenas no coinciden.', mbError, MB_OK);
      Result := False; Exit;
    end;
    GDbPassword := DbPasswordPage.Values[0];
  end;

  if CurPageID = JwtPage.ID then begin
    if JwtPage.Values[0] = '' then begin
      MsgBox('El JWT Secret no puede estar vacio.', mbError, MB_OK);
      Result := False; Exit;
    end;
    GJwtSecret := JwtPage.Values[0];
    GJwtRefreshSecret := JwtPage.Values[1];
  end;
end;

{ ===== Code callbacks used by [Run] section ===== }

function GetServerIp(Param: String): String;
begin
  Result := GServerIp;
end;

function GetDbPassword(Param: String): String;
begin
  Result := GDbPassword;
end;

function GetJwtSecret(Param: String): String;
begin
  Result := GJwtSecret;
end;

function GetJwtRefreshSecret(Param: String): String;
begin
  Result := GJwtRefreshSecret;
end;

function SkipSqlInstall(Param: String): String;
begin
  { Always attempt SQL Server install unless already present.
    initialize-db.ps1 checks if SQL Server is already installed. }
  Result := 'false';
end;

{ ===== Client-only: write URL shortcut file ===== }
procedure CurStepChanged(CurStep: TSetupStep);
var
  urlFile:    String;
  urlContent: String;
begin
  if CurStep = ssPostInstall then begin
    if WizardIsComponentSelected('clientonly') then begin
      urlFile    := ExpandConstant('{app}\open-parquerm-client.url');
      urlContent := '[InternetShortcut]' + #13#10 +
                    'URL=http://' + GServerIp + #13#10 +
                    'IconIndex=0' + #13#10;
      SaveStringToFile(urlFile, urlContent, False);
    end;
  end;
end;
