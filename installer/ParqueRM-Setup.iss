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
#define DefaultAdminPassword "admin1"
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
Name: "{app}\logs\db-init";  Components: server
Name: "{app}\backups";       Components: server
Name: "{app}\config";        Components: server
Name: "{app}\services";      Components: server
Name: "{app}\data\uploads\logos"; Components: server

[Icons]
; --- Server shortcuts -----------------------------------------------------------
Name: "{group}\Abrir ParqueRM";          Filename: "{app}\tools\open-parquerm.bat";       Components: server
Name: "{group}\Ver estado de ParqueRM";  Filename: "{app}\tools\show-status.bat";         Components: server
Name: "{group}\Iniciar servicios";       Filename: "{app}\tools\start-services.bat";      Components: server
Name: "{group}\Detener servicios";       Filename: "{app}\tools\stop-services.bat";       Components: server
Name: "{group}\Crear backup";            Filename: "{app}\tools\backup-db.bat";           Components: server
Name: "{group}\Restaurar backup";        Filename: "{app}\tools\restore-db.bat";          Components: server
Name: "{group}\Cambiar IP del servidor"; Filename: "{app}\tools\change-server-ip.bat";    Components: server
Name: "{group}\Diagnostico ParqueRM";     Filename: "{app}\tools\collect-diagnostics.bat"; Components: server

; --- Desktop shortcut (server) --------------------------------------------------
Name: "{userdesktop}\ParqueRM";          Filename: "{app}\tools\open-parquerm.bat"; \
  Components: server; Tasks: desktopicon

; --- Client-only shortcuts ------------------------------------------------------
Name: "{group}\Abrir ParqueRM";          Filename: "{app}\open-parquerm-client.url";      Components: clientonly
Name: "{userdesktop}\ParqueRM";          Filename: "{app}\open-parquerm-client.url"; \
  Components: clientonly; Tasks: desktopicon

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

; Remove startup task
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Unregister-ScheduledTask -TaskName 'ParqueRM_IpCheck' -Confirm:$false -ErrorAction SilentlyContinue"""; \
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
  AdminInfoPage:      TOutputMsgWizardPage;
  JwtPage:            TInputQueryWizardPage;
  ClientServerIpPage: TInputQueryWizardPage;
  GServerIp:          String;
  GDbPassword:        String;
  GAdminPassword:     String;
  GJwtSecret:         String;
  GJwtRefreshSecret:  String;
  GExistingInstall:   Boolean;
  GInstallFailed:     Boolean;

function SetEnvironmentVariable(lpName: String; lpValue: String): Boolean;
  external 'SetEnvironmentVariableW@kernel32.dll stdcall';

function DetectLanIp: String;
var
  tmpFile: String;
  rc: Integer;
  ps: String;
  detectedIp: AnsiString;
begin
  Result := '';
  tmpFile := ExpandConstant('{tmp}\parquerm-detected-ip.txt');
  ps :=
    '$patterns=''vEthernet'',''VMware'',''VirtualBox'',''Hyper-V'',''WSL'',''Loopback'',''Pseudo'',''Bluetooth'',''Teredo'',''ISATAP'',''Microsoft Wi-Fi Direct'',''WAN Miniport'',''Tunnel'';' +
    '$ips=Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch ''^127\.'' -and $_.IPAddress -notmatch ''^169\.254\.'' -and $_.PrefixOrigin -ne ''WellKnown'' -and $_.SuffixOrigin -ne ''Random'' } | ForEach-Object { $a=Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue; if ($a -and $a.Status -eq ''Up'') { $name=$a.Name + '' '' + $a.InterfaceDescription; $virtual=$false; foreach($p in $patterns){ if($name -like (''*''+$p+''*'')){ $virtual=$true } }; if(-not $virtual){ [pscustomobject]@{ IP=$_.IPAddress; Name=$name } } } };' +
    '$wired=$ips | Where-Object { $_.Name -notmatch ''Wi-Fi|Wireless|802\.11|WLAN'' } | Select-Object -First 1;' +
    '$pick=if($wired){$wired}else{$ips|Select-Object -First 1};' +
    'if($pick){ Set-Content -Path ''' + tmpFile + ''' -Value $pick.IP -Encoding ASCII }';

  Exec('powershell.exe',
    '-NoProfile -ExecutionPolicy Bypass -Command "' + ps + '"',
    '', SW_HIDE, ewWaitUntilTerminated, rc);

  if FileExists(tmpFile) then begin
    if LoadStringFromFile(tmpFile, detectedIp) then begin
      Result := Trim(String(detectedIp));
    end;
  end;
end;

function GenerateSecret(len: Integer): String;
var
  chars: String;
  i, idx: Integer;
begin
  { Use only dotenv-safe characters. Symbols like # can be parsed as comments
    by dotenv unless quoted perfectly through every installer layer. }
  chars := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  Result := '';
  for i := 1 to len do begin
    idx := (Random(Length(chars)) + 1);
    Result := Result + Copy(chars, idx, 1);
  end;
end;

procedure InitializeWizard;
begin
  GExistingInstall := FileExists(ExpandConstant('{#DefaultDir}\app\backend\.env'));
  GInstallFailed := False;
  GServerIp := DetectLanIp;
  GAdminPassword := '{#DefaultAdminPassword}';

  { Server IP page -- shown only in server mode }
  ServerIpPage := CreateInputQueryPage(wpSelectComponents,
    'Direccion IP del servidor',
    'Ingrese la IP de esta computadora en la red local.',
    'Las demas computadoras usaran esta IP para conectarse. Puede verla con ipconfig.');
  ServerIpPage.Add('IP del servidor:', False);
  ServerIpPage.Values[0] := GServerIp;

  { Client-only server IP page -- shown only in client-only mode }
  ClientServerIpPage := CreateInputQueryPage(wpSelectComponents,
    'IP del servidor ParqueRM',
    'Ingrese la IP del servidor donde ParqueRM esta instalado.',
    'Ejemplo: 192.168.68.51');
  ClientServerIpPage.Add('IP del servidor ParqueRM:', False);
  ClientServerIpPage.Values[0] := '';

  { DB password page }
  DbPasswordPage := CreateInputQueryPage(ServerIpPage.ID,
    'Contrasena de base de datos',
    'Ingrese la contrasena para SQL Server.',
    'Si SQL Server ya existe, ingrese la contrasena actual de "sa". Si no existe, esta sera la contrasena que se intentara configurar.');
  DbPasswordPage.Add('Contrasena:', True);
  DbPasswordPage.Add('Confirmar contrasena:', True);

  { Admin credentials info page }
  AdminInfoPage := CreateOutputMsgPage(DbPasswordPage.ID,
    'Usuario admin inicial',
    'Credenciales iniciales de ParqueRM',
    'Usuario: admin' + #13#10 +
    'Contrasena inicial: {#DefaultAdminPassword}' + #13#10#13#10 +
    'Si esta computadora ya tenia ParqueRM instalado, use la contrasena admin que ya tenia antes. ' +
    'El instalador no cambiara la contrasena de un usuario admin existente.');

  { JWT secrets page -- pre-filled with random secrets }
  JwtPage := CreateInputQueryPage(AdminInfoPage.ID,
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
  else if (PageID = AdminInfoPage.ID) and (not isServer) then Result := True
  else if (PageID = JwtPage.ID) and ((not isServer) or GExistingInstall) then Result := True
  else if (PageID = ClientServerIpPage.ID) and isServer then Result := True
  else Result := False;
end;

function IsValidIPv4(Value: String): Boolean;
var
  i, dots: Integer;
  ch: String;
begin
  Result := True;
  dots := 0;
  if Trim(Value) = '' then begin
    Result := False; Exit;
  end;
  for i := 1 to Length(Value) do begin
    ch := Copy(Value, i, 1);
    if ch = '.' then dots := dots + 1
    else if Pos(ch, '0123456789') = 0 then begin
      Result := False; Exit;
    end;
  end;
  Result := dots = 3;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if CurPageID = ServerIpPage.ID then begin
    if not IsValidIPv4(Trim(ServerIpPage.Values[0])) then begin
      MsgBox('Ingrese una IPv4 valida del servidor. Ejemplo: 192.168.68.51', mbError, MB_OK);
      Result := False; Exit;
    end;
    GServerIp := Trim(ServerIpPage.Values[0]);
  end;

  if CurPageID = ClientServerIpPage.ID then begin
    if not IsValidIPv4(Trim(ClientServerIpPage.Values[0])) then begin
      MsgBox('Ingrese una IPv4 valida del servidor. Ejemplo: 192.168.68.51', mbError, MB_OK);
      Result := False; Exit;
    end;
    GServerIp := Trim(ClientServerIpPage.Values[0]);
  end;

  if CurPageID = DbPasswordPage.ID then begin
    if DbPasswordPage.Values[0] = '' then begin
      MsgBox('La contrasena no puede estar vacia.', mbError, MB_OK);
      Result := False; Exit;
    end;
    if DbPasswordPage.Values[0] <> DbPasswordPage.Values[1] then begin
      MsgBox('Las contrasenas no coinciden.', mbError, MB_OK);
      Result := False; Exit;
    end;
    GDbPassword := DbPasswordPage.Values[0];
  end;

  if CurPageID = JwtPage.ID then begin
    if Length(JwtPage.Values[0]) < 16 then begin
      MsgBox('El JWT Secret debe tener al menos 16 caracteres.', mbError, MB_OK);
      Result := False; Exit;
    end;
    if Length(JwtPage.Values[1]) < 16 then begin
      MsgBox('El JWT Refresh Secret debe tener al menos 16 caracteres.', mbError, MB_OK);
      Result := False; Exit;
    end;
    GJwtSecret := JwtPage.Values[0];
    GJwtRefreshSecret := JwtPage.Values[1];
  end;
end;

{ ===== Code callbacks used by [Run] section ===== }

function PowerShellSingleQuoted(Value: String): String;
var
  i: Integer;
  ch: String;
begin
  Result := #39;
  for i := 1 to Length(Value) do begin
    ch := Copy(Value, i, 1);
    if ch = #39 then
      Result := Result + #39 + #39
    else
      Result := Result + ch;
  end;
  Result := Result + #39;
end;

function GetServerIp(Param: String): String;
begin
  Result := GServerIp;
end;

function GetDbPassword(Param: String): String;
begin
  Result := GDbPassword;
end;

function GetDbPasswordPs(Param: String): String;
begin
  Result := PowerShellSingleQuoted(GDbPassword);
end;

function GetJwtSecret(Param: String): String;
begin
  Result := GJwtSecret;
end;

function GetJwtSecretPs(Param: String): String;
begin
  Result := PowerShellSingleQuoted(GJwtSecret);
end;

function GetJwtRefreshSecret(Param: String): String;
begin
  Result := GJwtRefreshSecret;
end;

function GetJwtRefreshSecretPs(Param: String): String;
begin
  Result := PowerShellSingleQuoted(GJwtRefreshSecret);
end;

function SkipSqlInstall(Param: String): String;
begin
  { Always attempt SQL Server install unless already present.
    initialize-db.ps1 checks if SQL Server is already installed. }
  Result := 'false';
end;

procedure OpenDiagnosticsFolder(appDir: String);
var
  rc: Integer;
  scriptsDir: String;
  diagnosticsDir: String;
begin
  scriptsDir := appDir + '\tools\installer-scripts';
  diagnosticsDir := appDir + '\diagnostics';

  if FileExists(scriptsDir + '\collect-diagnostics.ps1') then begin
    Exec('powershell.exe',
      '-NoProfile -ExecutionPolicy Bypass -File "' + scriptsDir + '\collect-diagnostics.ps1" -InstallDir "' + appDir + '"',
      '', SW_HIDE, ewWaitUntilTerminated, rc);
  end;

  if DirExists(diagnosticsDir) then begin
    ShellExec('open', diagnosticsDir, '', '', SW_SHOWNORMAL, ewNoWait, rc);
  end else if DirExists(appDir + '\logs') then begin
    ShellExec('open', appDir + '\logs', '', '', SW_SHOWNORMAL, ewNoWait, rc);
  end;
end;

procedure TryStartExistingServices;
var
  rc: Integer;
  ps: String;
begin
  ps :=
    '$services=''ParqueRMBackend'',''ParqueRMFrontend'';' +
    'foreach($svcName in $services){' +
    '  $svc=Get-Service $svcName -ErrorAction SilentlyContinue;' +
    '  if($svc -and $svc.Status -ne ''Running''){' +
    '    Start-Service $svcName -ErrorAction SilentlyContinue' +
    '  }' +
    '};';

  Exec('powershell.exe',
    '-NoProfile -ExecutionPolicy Bypass -Command "' + ps + '"',
    '', SW_HIDE, ewWaitUntilTerminated, rc);
end;

procedure FailInstall(StepName: String; ExitCode: Integer);
var
  msg: String;
begin
  GInstallFailed := True;
  OpenDiagnosticsFolder(ExpandConstant('{app}'));
  TryStartExistingServices;

  if ExitCode = -1 then
    msg := 'No se pudo ejecutar el paso: ' + StepName + #13#10 +
      'Revise permisos de administrador y archivos de instalacion.'
  else
    msg := 'La instalacion de ParqueRM no pudo completar el paso:' + #13#10 +
      StepName + #13#10#13#10 +
      'Codigo de salida: ' + IntToStr(ExitCode);

  MsgBox(msg + #13#10#13#10 +
    'Se abrio la carpeta de diagnostico. Envie el archivo .zip que esta en:' + #13#10 +
    ExpandConstant('{app}\diagnostics'), mbError, MB_OK);

  WizardForm.Close;
end;

function PromptSqlPasswordRetry(var NewPassword: String): Boolean;
var
  form: TSetupForm;
  infoLabel: TNewStaticText;
  passwordLabel: TNewStaticText;
  confirmLabel: TNewStaticText;
  passwordEdit: TPasswordEdit;
  confirmEdit: TPasswordEdit;
  okButton: TNewButton;
  cancelButton: TNewButton;
begin
  Result := False;

  while True do begin
    form := CreateCustomForm(ScaleX(430), ScaleY(220), False, True);
    try
      form.Caption := 'Contrasena SQL Server';

      infoLabel := TNewStaticText.Create(form);
      infoLabel.Parent := form;
      infoLabel.Left := ScaleX(12);
      infoLabel.Top := ScaleY(12);
      infoLabel.Width := ScaleX(405);
      infoLabel.Height := ScaleY(55);
      infoLabel.WordWrap := True;
      infoLabel.Caption :=
        'La contrasena SQL ingresada no funciono o SQL Server la rechazo. ' +
        'Ingrese la contrasena actual del usuario "sa" si SQL Server ya existe, ' +
        'o una nueva contrasena para instalar SQL Server.';

      passwordLabel := TNewStaticText.Create(form);
      passwordLabel.Parent := form;
      passwordLabel.Left := ScaleX(12);
      passwordLabel.Top := ScaleY(82);
      passwordLabel.Caption := 'Contrasena de sa:';

      passwordEdit := TPasswordEdit.Create(form);
      passwordEdit.Parent := form;
      passwordEdit.Left := ScaleX(12);
      passwordEdit.Top := ScaleY(100);
      passwordEdit.Width := ScaleX(405);

      confirmLabel := TNewStaticText.Create(form);
      confirmLabel.Parent := form;
      confirmLabel.Left := ScaleX(12);
      confirmLabel.Top := ScaleY(132);
      confirmLabel.Caption := 'Confirmar contrasena:';

      confirmEdit := TPasswordEdit.Create(form);
      confirmEdit.Parent := form;
      confirmEdit.Left := ScaleX(12);
      confirmEdit.Top := ScaleY(150);
      confirmEdit.Width := ScaleX(405);

      okButton := TNewButton.Create(form);
      okButton.Parent := form;
      okButton.Caption := 'Reintentar';
      okButton.Left := ScaleX(217);
      okButton.Top := ScaleY(188);
      okButton.Width := ScaleX(95);
      okButton.ModalResult := mrOk;
      okButton.Default := True;

      cancelButton := TNewButton.Create(form);
      cancelButton.Parent := form;
      cancelButton.Caption := 'Cancelar';
      cancelButton.Left := ScaleX(322);
      cancelButton.Top := ScaleY(188);
      cancelButton.Width := ScaleX(95);
      cancelButton.ModalResult := mrCancel;
      cancelButton.Cancel := True;

      form.ActiveControl := passwordEdit;
      form.FlipAndCenterIfNeeded(True, WizardForm, False);

      if form.ShowModal() <> mrOk then begin
        Result := False;
        Exit;
      end;

      if passwordEdit.Text = '' then begin
        MsgBox('La contrasena SQL no puede estar vacia.', mbError, MB_OK);
        Continue;
      end;

      if passwordEdit.Text <> confirmEdit.Text then begin
        MsgBox('Las contrasenas SQL no coinciden.', mbError, MB_OK);
        Continue;
      end;

      NewPassword := passwordEdit.Text;
      Result := True;
      Exit;
    finally
      form.Free();
    end;
  end;
end;

function RunPowerShellStepRaw(StepName, ScriptPath, Args: String; ShowWindow: Boolean): Integer;
var
  rc: Integer;
  params: String;
  showCmd: Integer;
begin
  WizardForm.StatusLabel.Caption := StepName;

  params := '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '" ' + Args;
  if ShowWindow then
    showCmd := SW_SHOW
  else
    showCmd := SW_HIDE;

  if not Exec('powershell.exe', params, '', showCmd, ewWaitUntilTerminated, rc) then
    Result := -1
  else
    Result := rc;
end;

procedure RunPowerShellStep(StepName, ScriptPath, Args: String; ShowWindow: Boolean);
var
  rc: Integer;
begin
  rc := RunPowerShellStepRaw(StepName, ScriptPath, Args, ShowWindow);
  if rc = -1 then begin
    FailInstall(StepName, rc);
    Exit;
  end;
  if rc <> 0 then begin
    FailInstall(StepName, rc);
    Exit;
  end;
end;

function InitializeDbArgs(appDir: String): String;
begin
  Result :=
    '-InstallDir "' + appDir + '" ' +
    '-RuntimeCacheDir "' + appDir + '\runtime" ' +
    '-DbPassword ' + PowerShellSingleQuoted(GDbPassword) + ' ' +
    '-AdminPasswordEnv "PARQUERM_INSTALLER_ADMIN_PASSWORD" ' +
    '-InitScriptsDir "' + appDir + '\app\database\init" ' +
    '-MigrationsDir "' + appDir + '\app\database\migrations" ' +
    '-SkipSqlServerInstall:' + SkipSqlInstall('');
end;

procedure RunInitializeDbWithRetry(appDir, scriptsDir: String);
var
  rc: Integer;
  retryPassword: String;
begin
  if not SetEnvironmentVariable('PARQUERM_INSTALLER_ADMIN_PASSWORD', GAdminPassword) then begin
    FailInstall('Preparando usuario admin inicial...', -1);
    Exit;
  end;

  try
    while True do begin
      rc := RunPowerShellStepRaw(
        'Inicializando base de datos...',
        scriptsDir + '\initialize-db.ps1',
        InitializeDbArgs(appDir),
        False);

      if rc = 0 then
        Exit;

      if rc = 11 then begin
        if PromptSqlPasswordRetry(retryPassword) then begin
          GDbPassword := retryPassword;
          Continue;
        end;

        FailInstall('Inicializando base de datos...', 11);
        Exit;
      end;

      FailInstall('Inicializando base de datos...', rc);
      Exit;
    end;
  finally
    SetEnvironmentVariable('PARQUERM_INSTALLER_ADMIN_PASSWORD', '');
  end;
end;

procedure RunServerPostInstall;
var
  appDir: String;
  scriptsDir: String;
begin
  appDir := ExpandConstant('{app}');
  scriptsDir := appDir + '\tools\installer-scripts';

  RunPowerShellStep(
    'Configurando firewall...',
    scriptsDir + '\configure-firewall.ps1',
    '',
    False);
  if GInstallFailed then Exit;

  RunInitializeDbWithRetry(appDir, scriptsDir);
  if GInstallFailed then Exit;

  RunPowerShellStep(
    'Generando configuracion...',
    scriptsDir + '\generate-config.ps1',
    '-InstallDir "' + appDir + '" ' +
    '-ServerIp "' + GServerIp + '" ' +
    '-DbPassword ' + PowerShellSingleQuoted(GDbPassword) + ' ' +
    '-JwtSecret ' + PowerShellSingleQuoted(GJwtSecret) + ' ' +
    '-JwtRefreshSecret ' + PowerShellSingleQuoted(GJwtRefreshSecret) + ' ' +
    '-PreserveExistingSecrets',
    False);
  if GInstallFailed then Exit;

  RunPowerShellStep(
    'Instalando servicios de Windows...',
    scriptsDir + '\install-services.ps1',
    '-InstallDir "' + appDir + '" -RuntimeDir "' + appDir + '\runtime"',
    False);
  if GInstallFailed then Exit;

  RunPowerShellStep(
    'Registrando tarea de inicio automatico...',
    scriptsDir + '\register-startup-task.ps1',
    '-InstallDir "' + appDir + '"',
    False);
  if GInstallFailed then Exit;

  RunPowerShellStep(
    'Validando instalacion...',
    scriptsDir + '\show-final-url.ps1',
    '-InstallDir "' + appDir + '"',
    True);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  rc: Integer;
  ps: String;
begin
  Result := '';
  if WizardIsComponentSelected('server') then begin
    ps :=
      '$install=''' + ExpandConstant('{app}') + ''';' +
      '$services=''ParqueRMFrontend'',''ParqueRMBackend'';' +
      'foreach($svcName in $services){' +
      '  $svc=Get-Service $svcName -ErrorAction SilentlyContinue;' +
      '  if($svc -and $svc.Status -ne ''Stopped''){' +
      '    Stop-Service $svcName -Force -ErrorAction SilentlyContinue' +
      '  }' +
      '};' +
      '$deadline=(Get-Date).AddSeconds(45);' +
      'do{' +
      '  $running=@(Get-Service $services -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne ''Stopped'' });' +
      '  if($running.Count -eq 0){ break }' +
      '  Start-Sleep -Milliseconds 500' +
      '} while((Get-Date) -lt $deadline);' +
      '$prefix=([IO.Path]::GetFullPath($install)).TrimEnd(''\'') + ''\'';' +
      '$procs=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {' +
      '  ($_.Name -in @(''node.exe'',''caddy.exe'',''ParqueRMBackend.exe'',''ParqueRMFrontend.exe'')) -and' +
      '  (($_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) -or' +
      '   ($_.CommandLine -and $_.CommandLine.IndexOf($prefix,[StringComparison]::OrdinalIgnoreCase) -ge 0))' +
      '};' +
      'foreach($p in $procs){ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue };' +
      'Start-Sleep -Seconds 2';

    Exec('powershell.exe',
      '-NoProfile -ExecutionPolicy Bypass -Command "' + ps + '"',
      '', SW_HIDE, ewWaitUntilTerminated, rc);
  end;
end;

{ ===== Client-only: write URL shortcut file ===== }
procedure CurStepChanged(CurStep: TSetupStep);
var
  urlFile:    String;
  urlContent: String;
begin
  if CurStep = ssPostInstall then begin
    if WizardIsComponentSelected('server') then begin
      RunServerPostInstall;
    end;

    if WizardIsComponentSelected('clientonly') then begin
      urlFile    := ExpandConstant('{app}\open-parquerm-client.url');
      urlContent := '[InternetShortcut]' + #13#10 +
                    'URL=http://' + GServerIp + #13#10 +
                    'IconIndex=0' + #13#10;
      SaveStringToFile(urlFile, urlContent, False);
    end;
  end;
end;
