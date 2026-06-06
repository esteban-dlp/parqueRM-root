# Manual completo del instalador de ParqueRM

Documento tecnico y operativo para construir, instalar, diagnosticar y mantener ParqueRM en Windows.

Fecha de referencia: 2026-06-02  
Ruta del instalador en el repo: `parqueRM-root/installer`  
Ruta por defecto en equipos instalados: `C:\ParqueRM`

---

## 1. Objetivo del instalador

El instalador de ParqueRM esta diseñado para entregar un solo ejecutable Windows que pueda instalar el sistema en un equipo servidor sin depender de internet durante la instalacion final.

El objetivo operativo es que el usuario final haga esto:

1. Ejecutar `ParqueRM-Setup-vX.X.X.exe`.
2. Elegir instalacion completa o solo cliente.
3. Ingresar la IP del servidor si no fue detectada automaticamente.
4. Ingresar la contrasena tecnica de SQL Server.
5. Leer las credenciales iniciales del usuario `admin` de ParqueRM.
6. Esperar a que el instalador configure base de datos, archivos, servicios, firewall y accesos directos.
7. Abrir ParqueRM desde el acceso directo.

El usuario final no deberia tener que abrir PowerShell, editar archivos, instalar Node.js, instalar Caddy, instalar WinSW ni correr scripts manuales para una instalacion normal.

---

## 2. Alcance

Este documento cubre:

- Requisitos para compilar el instalador.
- Requisitos para instalarlo en un equipo cliente/servidor.
- Componentes incluidos en el instalador.
- Flujo exacto de instalacion.
- Manejo de SQL Server nuevo y SQL Server existente.
- Manejo de contrasenas.
- Configuracion automatica de IP.
- Servicios de Windows.
- Logs, diagnostico y soporte remoto/offline.
- Backup y restore.
- Desinstalacion y pruebas desde cero.
- Casos de falla y acciones recomendadas.

Este documento no cubre la funcionalidad de negocio de ParqueRM dentro de la aplicacion web, salvo cuando afecta instalacion, login o soporte.

---

## 3. Arquitectura general

El instalador evita depender de Docker en produccion Windows. Empaqueta y configura los componentes necesarios directamente:

| Componente | Proposito | Donde queda instalado |
|---|---|---|
| SQL Server Express | Motor de base de datos local | Windows service `MSSQLSERVER` o instancia existente |
| Base de datos `ParqueRM` | Datos del sistema | SQL Server local, puerto 1433 |
| Backend NestJS | API REST de ParqueRM | `C:\ParqueRM\app\backend` |
| Frontend React | Aplicacion web | `C:\ParqueRM\app\frontend\dist` |
| Node.js | Runtime del backend | `C:\ParqueRM\runtime\node\node.exe` |
| Caddy | Servidor web y proxy `/api` | `C:\ParqueRM\runtime\caddy\caddy.exe` |
| WinSW | Wrapper para servicios Windows | `C:\ParqueRM\runtime\winsw` |
| sqlcmd | Herramienta CLI para SQL Server | `C:\ParqueRM\runtime\sqlcmd\sqlcmd.exe` o SQL tools instaladas |
| Scripts de instalador | Inicializacion, configuracion, diagnostico | `C:\ParqueRM\tools\installer-scripts` |
| Herramientas `.bat` | Accesos de soporte y operacion | `C:\ParqueRM\tools` |

El flujo de red esperado es:

```text
Navegador LAN
    |
    | http://IP_DEL_SERVIDOR
    v
Caddy / ParqueRMFrontend, puerto 80
    |
    | /api/*
    v
Backend NestJS / ParqueRMBackend, puerto 3000
    |
    | 127.0.0.1:1433
    v
SQL Server + base ParqueRM
```

SQL Server no se expone a la LAN por defecto. El frontend y backend si se abren en firewall.

---

## 4. Modos de instalacion

El instalador tiene dos modos:

| Modo | Uso | Que instala |
|---|---|---|
| Instalacion completa, servidor | Equipo principal donde correra ParqueRM | Backend, frontend, base de datos, servicios, firewall, herramientas |
| Solo cliente | PC que solo necesita abrir el sistema del servidor | Acceso directo `.url` hacia `http://IP_DEL_SERVIDOR` |

### 4.1 Instalacion completa

Este modo instala todo en el equipo servidor. Es el modo que se debe usar en la maquina donde estara la base de datos y la aplicacion.

Preguntas principales:

- IP del servidor, si no se detecta automaticamente.
- Contrasena SQL Server `sa`.
- Credenciales iniciales del usuario web `admin`.
- Secretos JWT, generados automaticamente y editables.

### 4.2 Solo cliente

Este modo no instala backend, frontend, SQL Server ni servicios. Solo crea un acceso directo que abre:

```text
http://IP_DEL_SERVIDOR
```

Se usa en equipos secundarios de la misma red local.

---

## 5. Requisitos para instalar en un equipo final

### 5.1 Requisitos minimos del equipo servidor

| Requisito | Detalle |
|---|---|
| Sistema operativo | Windows con soporte para servicios, PowerShell 5.1 y tareas programadas |
| Permisos | Ejecutar instalador como administrador |
| Red | IP LAN estable o detectable |
| Puertos locales | 80, 3000 y 1433 disponibles |
| Espacio en disco | Suficiente para SQL Server Express, Node.js, app, logs y backups |
| Internet | No requerido si el `.exe` fue compilado con runtime-cache completo |

### 5.2 Puertos usados

| Puerto | Uso | Alcance |
|---|---|---|
| TCP 80 | Frontend servido por Caddy | Abierto a LAN por firewall |
| TCP 3000 | Backend NestJS | Abierto por firewall, aunque el uso normal pasa por `/api` en puerto 80 |
| TCP 1433 | SQL Server local | Configurado para `127.0.0.1`; no se abre a LAN por defecto |

### 5.3 Requisitos de permisos

La instalacion completa requiere permisos de administrador porque hace acciones de sistema:

- Instala o reutiliza SQL Server.
- Configura TCP/IP de SQL Server.
- Reinicia el servicio de SQL Server.
- Crea reglas de firewall.
- Crea servicios de Windows.
- Crea una tarea programada con usuario `SYSTEM`.

Si el usuario no tiene permisos de administrador, la instalacion completa puede fallar.

---

## 6. Requisitos para compilar el instalador

La compilacion se realiza desde:

```powershell
cd C:\Users\Esteban\OneDrive\PROYECTOS\parqueRM\parqueRM-root\installer
.\build-installer.bat
```

En PowerShell es importante usar `.\build-installer.bat`, porque PowerShell no ejecuta comandos desde el directorio actual sin `.\`.

### 6.1 Estructura esperada del proyecto

El script espera esta estructura:

```text
PROYECTOS\parqueRM\
  parqueRM-root\
  parqueRM-backend\
  parqueRM-frontend\
```

Si falta `parqueRM-backend` o `parqueRM-frontend`, el build falla en la validacion de repos.

### 6.2 Runtime cache requerido

Antes de compilar para entrega offline, deben existir archivos reales en:

```text
parqueRM-root\installer\runtime-cache\
  sqlserver-express\
  node\
  caddy\
  winsw\
  sqlcmd\
```

| Carpeta | Archivo requerido |
|---|---|
| `runtime-cache\sqlserver-express` | `SQLEXPR_x64_ENU.exe` o instalador equivalente |
| `runtime-cache\node` | `node.exe` |
| `runtime-cache\caddy` | `caddy.exe` |
| `runtime-cache\winsw` | `WinSW.exe`, `WinSW-x64.exe` o equivalente |
| `runtime-cache\sqlcmd` | `sqlcmd.exe` |

Si se compila sin esos archivos, el instalador puede no servir para equipos sin internet.

### 6.3 Herramientas necesarias en la maquina de build

| Herramienta | Uso |
|---|---|
| PowerShell 5.1+ | Ejecutar build scripts |
| Node.js/npm | Ejecutar `npm ci` y `npm run build` si no se usa `-SkipNpmInstall` |
| Inno Setup 6 | Compilar `ParqueRM-Setup.iss` a `.exe` |
| Robocopy | Copiar carpetas de release |

### 6.4 Flags utiles del build

| Flag | Uso |
|---|---|
| `-SkipRuntimeValidation` | Permite generar release sin validar runtime-cache |
| `-SkipInstallerCompile` | Genera `release\` pero no compila el `.exe` |
| `-SkipNpmInstall` | Reusa `dist` y `node_modules` ya existentes |

Ejemplo:

```powershell
.\build-installer.ps1 -SkipNpmInstall
```

---

## 7. Que hace el build

El script `build-installer.ps1` ejecuta nueve pasos:

1. Valida que existan los repos `parqueRM-root`, `parqueRM-backend` y `parqueRM-frontend`.
2. Valida que `installer\runtime-cache` tenga los runtimes necesarios.
3. Lee `version.json`.
4. Limpia y recrea `parqueRM-root\release`.
5. Compila backend con `npm ci --prefer-offline` y `npm run build`, salvo `-SkipNpmInstall`.
6. Compila frontend con `npm ci --prefer-offline` y `npm run build`, salvo `-SkipNpmInstall`.
7. Copia artefactos a `release`.
8. Genera metadata `version.json`.
9. Compila el `.exe` con Inno Setup.

El resultado esperado es:

```text
parqueRM-root\release\ParqueRM-Setup-v1.0.0.exe
```

La version depende de `version.json`.

---

## 8. Que empaqueta el instalador

En instalacion completa, Inno Setup copia:

| Origen en release | Destino instalado |
|---|---|
| `release\app\backend\*` | `C:\ParqueRM\app\backend` |
| `release\app\frontend\dist\*` | `C:\ParqueRM\app\frontend\dist` |
| `release\app\database\*` | `C:\ParqueRM\app\database` |
| `release\app\config\*` | `C:\ParqueRM\app\config` |
| `release\app\tools\*` | `C:\ParqueRM\tools` |
| `release\runtime\*` | `C:\ParqueRM\runtime` |
| `release\version.json` | `C:\ParqueRM\version.json` |

Tambien crea:

```text
C:\ParqueRM\logs\backend
C:\ParqueRM\logs\frontend
C:\ParqueRM\logs\db-init
C:\ParqueRM\backups
C:\ParqueRM\config
C:\ParqueRM\services
```

---

## 9. Flujo de instalacion completa

Cuando se instala en modo servidor, el instalador ejecuta estos pasos despues de copiar archivos:

1. Configura firewall.
2. Inicializa base de datos.
3. Genera configuracion.
4. Instala servicios Windows.
5. Registra tarea de inicio automatico.
6. Valida que la aplicacion responda.

### 9.1 Configuracion de firewall

Script:

```text
C:\ParqueRM\tools\installer-scripts\configure-firewall.ps1
```

Crea reglas:

| Regla | Puerto | Se crea por defecto |
|---|---:|---|
| ParqueRM Frontend TCP 80 | 80 | Si |
| ParqueRM Backend TCP 3000 | 3000 | Si |
| ParqueRM SQL Server TCP 1433 | 1433 | No |

El puerto 1433 se mantiene cerrado a LAN por seguridad. El backend se conecta a SQL Server por `127.0.0.1`.

### 9.2 Inicializacion de base de datos

Script:

```text
C:\ParqueRM\tools\installer-scripts\initialize-db.ps1
```

Hace lo siguiente:

1. Detecta si ya existe un servicio SQL Server (`MSSQLSERVER` o `MSSQL$...`).
2. Si no existe, instala SQL Server Express desde `C:\ParqueRM\runtime\sqlserver-express`.
3. Localiza `sqlcmd`.
4. Configura SQL Server TCP/IP en `127.0.0.1:1433`.
5. Reinicia SQL Server si cambio la configuracion TCP.
6. Valida que SQL Server escuche en `127.0.0.1:1433`.
7. Valida login `sa`.
8. Si `sa` no funciona, intenta habilitar/reparar `sa` con Windows Authentication.
9. Si la contrasena no sirve o SQL la rechaza, devuelve codigo especial para que el instalador la vuelva a pedir.
10. Crea la base `ParqueRM` si no existe.
11. Ejecuta scripts `db\init`, excepto `01_create_database.sql` porque la base ya fue creada por el script.
12. Detecta si el usuario `admin` ya existia antes de correr las seeds.
13. Genera hash bcrypt para la contrasena inicial `admin1`.
14. Actualiza o inserta el usuario `admin` con esa contrasena inicial.
15. Verifica con bcrypt que `admin1` coincida con el hash guardado.
16. Si la verificacion falla, aborta la instalacion.
17. Ejecuta migraciones pendientes.
18. Escribe `C:\ParqueRM\config\db-ready.json`.

El marcador `db-ready.json` es importante. Los servicios no se instalan si la base no fue inicializada correctamente.

### 9.3 Generacion de configuracion

Script:

```text
C:\ParqueRM\tools\installer-scripts\generate-config.ps1
```

Escribe:

```text
C:\ParqueRM\app\backend\.env
C:\ParqueRM\app\frontend\dist\config.json
C:\ParqueRM\config\parquerm.config.json
C:\ParqueRM\config\Caddyfile
```

Tambien actualiza en SQL:

```text
dbo.park_config.system_lan_url
```

El valor queda como:

```text
http://IP_DEL_SERVIDOR
```

El frontend se configura con API same-origin:

```json
{
  "apiUrl": "/api"
}
```

Esto permite que el navegador use el mismo host desde donde abre el frontend. Caddy se encarga de mandar `/api/*` al backend local.

### 9.4 Instalacion de servicios

Script:

```text
C:\ParqueRM\tools\installer-scripts\install-services.ps1
```

Crea dos servicios mediante WinSW:

| Servicio | Display name | Ejecuta | Puerto |
|---|---|---|---:|
| `ParqueRMBackend` | ParqueRM Backend | `node dist\main.js` | 3000 |
| `ParqueRMFrontend` | ParqueRM Frontend | `caddy run --config C:\ParqueRM\config\Caddyfile` | 80 |

Ambos servicios quedan con inicio automatico y politica de reinicio ante fallos.

Antes de instalarlos valida que exista:

```text
C:\ParqueRM\config\db-ready.json
```

Esto evita levantar servicios contra una base incompleta.

### 9.5 Tarea programada de arranque

Script:

```text
C:\ParqueRM\tools\installer-scripts\register-startup-task.ps1
```

Registra la tarea:

```text
ParqueRM_IpCheck
```

Caracteristicas:

- Corre como `SYSTEM`.
- Corre con privilegios altos.
- Se ejecuta al iniciar Windows.
- Espera 30 segundos para que la red levante.
- Verifica si la IP LAN cambio.
- Si cambio, regenera configuracion preservando secretos.
- Intenta iniciar servicios si estan detenidos.

Log:

```text
C:\ParqueRM\logs\startup-check.log
```

### 9.6 Validacion final

Script:

```text
C:\ParqueRM\tools\installer-scripts\show-final-url.ps1
```

Valida:

- Existe `C:\ParqueRM\config\db-ready.json`.
- Existen y estan corriendo `ParqueRMBackend` y `ParqueRMFrontend`.
- Responde frontend.
- Responde backend health.
- Responde database health.

URLs probadas:

```text
http://127.0.0.1/
http://127.0.0.1/api/health
http://127.0.0.1/api/health/database
```

Si falla, el instalador no debe declarar exito silenciosamente; debe abrir diagnostico o indicar logs.

---

## 10. Manejo de SQL Server

### 10.1 Si SQL Server no existe

El instalador:

1. Busca instalador offline en `runtime\sqlserver-express`.
2. Instala SQL Server Express como instancia `MSSQLSERVER`.
3. Usa modo SQL Authentication.
4. Configura la contrasena `sa` ingresada por el usuario.
5. Habilita TCP.

Si SQL Server rechaza la contrasena nueva, el instalador debe volver a pedir una contrasena SQL.

### 10.2 Si SQL Server ya existe

El instalador:

1. Reusa el servicio SQL existente.
2. Pide la contrasena actual de `sa`.
3. Intenta conectar con `sa`.
4. Si falla, intenta reparar/habilitar `sa` usando Windows Authentication.
5. Si no puede reparar, vuelve a pedir la contrasena SQL.

Esto permite manejar equipos donde SQL Server ya estaba instalado.

### 10.3 Que pasa si el usuario ingresa mal la contrasena `sa`

El instalador usa codigo de salida especial `11` para indicar que necesita volver a pedir la contrasena SQL.

Flujo esperado:

```text
Usuario ingresa contrasena SQL
  |
  v
SQL login falla o SQL setup rechaza la contrasena
  |
  v
Instalador muestra ventana para pedir de nuevo la contrasena de sa
  |
  v
Reintenta inicializacion de base
```

La meta es no dejar al usuario final buscando comandos manuales.

### 10.4 Limitaciones reales con SQL Server existente

Hay escenarios donde el instalador no puede resolver todo solo:

- Windows Authentication no permite alterar `sa`.
- La instancia SQL existente tiene politicas corporativas restrictivas.
- El puerto 1433 esta ocupado por otro proceso.
- SQL Server esta danado o no arranca.
- La instancia no permite modo mixto.
- El usuario de Windows no tiene permisos de administrador SQL.

En esos casos se debe usar diagnostico y soporte tecnico.

---

## 11. Manejo de contrasenas

### 11.1 Contrasena SQL Server

La contrasena SQL es la contrasena tecnica del usuario:

```text
sa
```

Se usa para:

- Instalar SQL Server nuevo.
- Conectar a SQL Server existente.
- Crear o actualizar base `ParqueRM`.
- Ejecutar scripts SQL.
- Generar configuracion `.env`.
- Actualizar `park_config.system_lan_url`.

Reglas actuales:

- No puede estar vacia.
- Debe confirmarse.
- No se aplica validacion estricta desde el instalador.
- Si SQL Server la rechaza, el instalador vuelve a pedirla.

### 11.2 Contrasena del usuario web admin

El usuario de login web es:

```text
admin
```

La contrasena configurada por el instalador es:

```text
admin1
```

El instalador ya no pide la contrasena de este usuario. Durante la instalacion, escribe y verifica un hash bcrypt para `admin1`.

Solo se guarda un hash bcrypt en:

```text
dbo.users.password_hash
```

No se guarda la contrasena en texto plano.

El flujo actual:

1. El instalador usa la contrasena inicial `admin1`.
2. Genera un hash bcrypt usando Node.js y `bcrypt`.
3. Actualiza o crea `dbo.users` con `username = N'admin'`.
4. Lee el hash guardado.
5. Verifica que `admin1` coincida con el hash guardado.

Si la verificacion falla, la instalacion debe fallar con log claro.

### 11.3 Si se olvida la contrasena admin

No se puede recuperar porque esta hasheada. Solo se puede resetear.

Procedimiento de reset en el servidor, PowerShell como administrador:

```powershell
$newAdminPassword = 'admin1234'
$install = 'C:\ParqueRM'
$backend = Join-Path $install 'app\backend'
$node = Join-Path $install 'runtime\node\node.exe'
$sqlcmd = Join-Path $install 'runtime\sqlcmd\sqlcmd.exe'

if (-not (Test-Path $sqlcmd)) {
  $sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE'
}

$env:PARQUERM_ADMIN_PASSWORD = $newAdminPassword
Push-Location $backend
$hash = & $node -e "const path=require('path'); const bcrypt=require(path.join(process.cwd(),'node_modules','bcrypt')); bcrypt.hash(process.env.PARQUERM_ADMIN_PASSWORD,12).then(h=>process.stdout.write(h)).catch(e=>{console.error(e);process.exit(1);});"
Pop-Location

$sqlHash = $hash.Replace("'", "''")
$sql = "UPDATE dbo.users SET password_hash=N'$sqlHash', is_active=1, deleted_at=NULL, updated_at=SYSDATETIME() WHERE username=N'admin';"

& $sqlcmd -S 127.0.0.1,1433 -E -d ParqueRM -Q $sql -b
```

Si `-E` no tiene permisos, usar `-U sa -P "CONTRASENA_SQL"`.

---

## 12. Configuracion automatica de IP

### 12.1 Deteccion inicial

El instalador intenta detectar la IP LAN del equipo servidor, excluyendo:

- Loopback.
- APIPA `169.254.*`.
- Adaptadores virtuales comunes.
- VirtualBox.
- VMware.
- Hyper-V.
- WSL.
- Bluetooth.
- Wi-Fi Direct.
- Tunnel/WAN Miniport.

Si detecta una IP valida, la usa automaticamente. Si no detecta, muestra pagina para que el usuario la ingrese.

### 12.2 Donde se guarda la IP

La IP queda en:

```text
C:\ParqueRM\config\parquerm.config.json
C:\ParqueRM\app\backend\.env
dbo.park_config.system_lan_url
```

El frontend usa `/api`, por lo que no depende directamente de la IP para llamar al backend.

### 12.3 Si cambia la IP por DHCP

Hay dos mecanismos:

1. Tarea programada `ParqueRM_IpCheck`, que corre al iniciar Windows.
2. Herramienta manual `change-server-ip.bat`.

Herramienta manual:

```bat
C:\ParqueRM\tools\change-server-ip.bat
```

Esta herramienta:

- Muestra IPs detectadas.
- Pide nueva IP.
- Pide contrasena SQL `sa`.
- Regenera configuracion.
- Preserva secretos JWT.
- Actualiza `park_config.system_lan_url`.
- Reinicia servicios.

---

## 13. Servicios de Windows

### 13.1 Servicios instalados

| Servicio | Descripcion | Log principal |
|---|---|---|
| `ParqueRMBackend` | API REST NestJS | `C:\ParqueRM\logs\backend` |
| `ParqueRMFrontend` | Caddy frontend + proxy API | `C:\ParqueRM\logs\frontend` |

### 13.2 Comandos de servicio

Estado:

```powershell
Get-Service ParqueRMBackend,ParqueRMFrontend
```

Iniciar:

```powershell
Start-Service ParqueRMBackend
Start-Service ParqueRMFrontend
```

Detener:

```powershell
Stop-Service ParqueRMFrontend
Stop-Service ParqueRMBackend
```

Reiniciar:

```powershell
Restart-Service ParqueRMBackend
Restart-Service ParqueRMFrontend
```

### 13.3 Herramientas instaladas

| Herramienta | Uso |
|---|---|
| `open-parquerm.bat` | Verifica servicios y abre ParqueRM |
| `show-status.bat` | Muestra estado, puertos, IPs y ultimas lineas de logs |
| `start-services.bat` | Inicia servicios con elevacion |
| `stop-services.bat` | Detiene servicios con elevacion |
| `restart-services.bat` | Reinicia servicios con elevacion |
| `backup-db.bat` | Crea backup manual `.bak` |
| `restore-db.bat` | Restaura backup `.bak` |
| `change-server-ip.bat` | Regenera configuracion con otra IP |
| `collect-diagnostics.bat` | Genera zip de diagnostico |

---

## 14. Logs y diagnostico

### 14.1 Logs principales

| Ruta | Contenido |
|---|---|
| `C:\ParqueRM\logs\db-init\*.log` | Instalacion SQL, seed, admin, migraciones |
| `C:\ParqueRM\logs\backend` | Logs de WinSW y Node/backend |
| `C:\ParqueRM\logs\frontend` | Logs de Caddy/frontend |
| `C:\ParqueRM\logs\startup-check.log` | Tarea de arranque y actualizacion de IP |
| `C:\ParqueRM\diagnostics` | Reportes y zips generados por diagnostico |

### 14.2 Generar diagnostico

Desde menu inicio:

```text
Diagnostico ParqueRM
```

O manual:

```bat
C:\ParqueRM\tools\collect-diagnostics.bat
```

El diagnostico genera:

```text
C:\ParqueRM\diagnostics\YYYYMMDD-HHMMSS\diagnostics.txt
C:\ParqueRM\diagnostics\ParqueRM-diagnostics-YYYYMMDD-HHMMSS.zip
```

Incluye:

- Estado de servicios.
- Estado de puertos 80, 3000 y 1433.
- Health checks HTTP.
- Configuracion central.
- `.env` con secretos censurados.
- Ultimo log de init DB.
- Logs recientes de backend y frontend.
- Eventos recientes de Windows relacionados con ParqueRM, Node, Caddy, WinSW o SQL.

### 14.3 Que pedir al cliente si falla algo

Pedir siempre:

1. Archivo `.zip` en `C:\ParqueRM\diagnostics`.
2. Captura del error visible.
3. Si estaba instalando o abriendo la app.
4. Si SQL Server ya existia en esa maquina.
5. Si recuerda la contrasena SQL `sa`.
6. Si el equipo tiene IP fija o DHCP.

---

## 15. Backups y restauracion

### 15.1 Crear backup

Herramienta:

```bat
C:\ParqueRM\tools\backup-db.bat
```

Pide la contrasena SQL `sa` y crea:

```text
C:\ParqueRM\backups\ParqueRM-backup-YYYYMMDD-HHMMSS.bak
```

### 15.2 Restaurar backup

Herramienta:

```bat
C:\ParqueRM\tools\restore-db.bat
```

Advertencia: la restauracion reemplaza la base actual. Todo dato creado despues del backup se pierde.

Flujo:

1. Pide elevacion admin.
2. Pide ruta completa del `.bak`.
3. Pide confirmacion escribiendo `YES`.
4. Pide contrasena SQL `sa`.
5. Detiene servicios.
6. Pone base en single user.
7. Restaura con `WITH REPLACE`.
8. Devuelve base a multi user.
9. Reinicia servicios.

### 15.3 Recomendacion de operacion

Antes de cualquier soporte destructivo:

```bat
C:\ParqueRM\tools\backup-db.bat
```

Guardar el `.bak` fuera del equipo si el soporte implica reinstalar Windows, mover equipo, cambiar disco o eliminar `C:\ParqueRM`.

---

## 16. Desinstalacion

El desinstalador:

- Detiene y desinstala servicios ParqueRM.
- Remueve reglas de firewall de ParqueRM.
- Elimina tarea programada `ParqueRM_IpCheck`.
- Remueve archivos instalados por Inno.
- Remueve logs y carpeta `services`.

No esta pensado para eliminar automaticamente:

- Backups en `C:\ParqueRM\backups`.
- Credenciales o `.env` preservados.
- Base de datos SQL `ParqueRM`.
- SQL Server Express completo.

Esta decision protege datos del cliente ante desinstalaciones accidentales.

### 16.1 Probar desde cero en una VM

Checklist recomendado:

1. Crear backup si hay datos importantes.
2. Desinstalar ParqueRM desde Apps de Windows.
3. Verificar que no existan servicios:

```powershell
Get-Service ParqueRMBackend,ParqueRMFrontend -ErrorAction SilentlyContinue
```

4. Si la prueba requiere base totalmente limpia, eliminar base `ParqueRM` manualmente con cuidado.

Comando destructivo, solo para VM de prueba:

```powershell
sqlcmd -S 127.0.0.1,1433 -E -Q "ALTER DATABASE [ParqueRM] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [ParqueRM];"
```

Si `-E` no tiene permisos:

```powershell
sqlcmd -S 127.0.0.1,1433 -U sa -P "CONTRASENA_SQL" -Q "ALTER DATABASE [ParqueRM] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [ParqueRM];"
```

5. Eliminar `C:\ParqueRM` solo si no se necesita conservar backups.
6. Reiniciar Windows si SQL Server o servicios quedaron bloqueados.
7. Instalar el nuevo `.exe`.

---

## 17. Casos de falla comunes

### 17.1 Instalador falla en "Inicializando base de datos"

Posibles causas:

- SQL Server no arranca.
- Puerto 1433 ocupado.
- `sqlcmd.exe` no existe.
- Contrasena `sa` incorrecta.
- SQL Server rechaza la contrasena nueva.
- Windows Authentication no permite reparar `sa`.
- Scripts SQL fallan.
- Migracion SQL falla.

Que revisar:

```text
C:\ParqueRM\logs\db-init\*.log
C:\ParqueRM\diagnostics\*.zip
```

Comandos utiles:

```powershell
Get-Service MSSQLSERVER,'MSSQL$SQLEXPRESS'
Test-NetConnection 127.0.0.1 -Port 1433
```

Si el log muestra codigo 11 o login failed para `sa`, la accion correcta es ingresar la contrasena correcta de `sa` cuando el instalador la vuelve a pedir.

### 17.2 Instalador termina, pero el navegador dice "refused to connect"

Posibles causas:

- `ParqueRMFrontend` detenido.
- `ParqueRMBackend` detenido.
- Caddy no pudo tomar puerto 80.
- Backend no pudo conectar a SQL.
- Instalacion anterior dejo procesos bloqueando puertos.

Que revisar:

```powershell
Get-Service ParqueRMBackend,ParqueRMFrontend
Test-NetConnection 127.0.0.1 -Port 80
Test-NetConnection 127.0.0.1 -Port 3000
```

Usar:

```bat
C:\ParqueRM\tools\show-status.bat
C:\ParqueRM\tools\collect-diagnostics.bat
```

### 17.3 Puerto 80 ocupado

Sintomas:

- Frontend no inicia.
- Caddy falla.
- `Test-NetConnection 127.0.0.1 -Port 80` puede responder por otro proceso.

Diagnostico:

```powershell
netstat -ano | findstr ":80"
```

Luego buscar proceso:

```powershell
Get-Process -Id PID
```

Solucion:

- Detener el proceso que ocupa el puerto.
- Cambiar configuracion si se decide usar otro puerto.
- Reinstalar o reiniciar servicios.

### 17.4 Backend no responde

Sintomas:

```text
http://127.0.0.1/api/health falla
http://127.0.0.1:3000/api/health falla
```

Revisar:

```text
C:\ParqueRM\logs\backend\ParqueRMBackend.err.log
C:\ParqueRM\app\backend\.env
C:\ParqueRM\config\db-ready.json
```

Causas comunes:

- `.env` no generado.
- DB_PASSWORD incorrecta.
- SQL Server detenido.
- `node.exe` no existe.
- `node_modules` incompleto.
- Backend build incompleto.

### 17.5 Database health falla

Sintomas:

```text
http://127.0.0.1/api/health responde
http://127.0.0.1/api/health/database falla
```

Causas:

- SQL Server detenido.
- Base `ParqueRM` no existe.
- Credenciales en `.env` incorrectas.
- Puerto 1433 no escucha.
- SQL Server no permite autenticacion `sa`.

Revisar:

```powershell
Get-Service MSSQLSERVER
Test-NetConnection 127.0.0.1 -Port 1433
```

### 17.6 Login admin no funciona

Posibles causas:

- Se ingreso una contrasena distinta.
- Se ingreso un espacio accidental.
- Instalador viejo no actualizo el hash.
- Usuario `admin` estaba inactivo o eliminado logicamente.
- Rol Administrador estaba inactivo.
- Se esta entrando contra otra base/instancia.

El instalador actual debe:

- Reactivar `admin`.
- Limpiar `deleted_at`.
- Reactivar rol Administrador.
- Verificar bcrypt despues de escribir el hash.

No se puede recuperar la contrasena admin. Solo resetear.

### 17.7 IP incorrecta

Sintomas:

- El servidor abre localmente, pero clientes no conectan.
- El acceso directo usa IP vieja.
- `park_config.system_lan_url` muestra IP vieja.

Solucion:

```bat
C:\ParqueRM\tools\change-server-ip.bat
```

Tambien revisar:

```text
C:\ParqueRM\logs\startup-check.log
C:\ParqueRM\config\parquerm.config.json
```

### 17.8 Firewall bloquea acceso LAN

Ver reglas:

```powershell
Get-NetFirewallRule -DisplayName "ParqueRM*"
```

Recrear reglas:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ParqueRM\tools\installer-scripts\configure-firewall.ps1
```

### 17.9 Runtime cache incompleto al compilar

Sintomas:

- Build falla en Step 2.
- Instalador generado no contiene runtime necesario.
- Instalacion final no encuentra `node.exe`, `caddy.exe`, `WinSW.exe`, `sqlcmd.exe` o SQL Express.

Solucion:

Completar:

```text
installer\runtime-cache\sqlserver-express
installer\runtime-cache\node
installer\runtime-cache\caddy
installer\runtime-cache\winsw
installer\runtime-cache\sqlcmd
```

Luego recompilar.

### 17.10 Inno Setup no compila

Sintomas:

```text
ISCC.exe not found
```

Solucion:

- Instalar Inno Setup 6.
- O usar `-SkipInstallerCompile` solo para generar `release`.

### 17.11 Archivo `.exe` bloqueado al recompilar

Sintomas:

- Build falla eliminando `release`.
- `ParqueRM-Setup-vX.X.X.exe` no se puede borrar.

Causas:

- El instalador esta abierto.
- Explorer esta previsualizando el archivo.
- Antivirus lo esta analizando.
- La VM o carpeta compartida mantiene handle abierto.

Solucion:

1. Cerrar instalador.
2. Cerrar Explorer en `release`.
3. Esperar antivirus.
4. Si sigue, reiniciar o borrar manualmente.

---

## 18. Procedimientos de soporte rapido

### 18.1 Ver estado general

```bat
C:\ParqueRM\tools\show-status.bat
```

### 18.2 Abrir sistema con verificacion

```bat
C:\ParqueRM\tools\open-parquerm.bat
```

Este `.bat` intenta iniciar servicios si estan detenidos, espera que responda `http://127.0.0.1/` y abre la URL configurada.

### 18.3 Reiniciar servicios

```bat
C:\ParqueRM\tools\restart-services.bat
```

### 18.4 Generar diagnostico

```bat
C:\ParqueRM\tools\collect-diagnostics.bat
```

### 18.5 Ver logs DB init recientes

```powershell
$log = Get-ChildItem C:\ParqueRM\logs\db-init\*.log |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

$log.FullName
Get-Content $log.FullName -Tail 250
```

### 18.6 Ver puertos

```powershell
Test-NetConnection 127.0.0.1 -Port 80
Test-NetConnection 127.0.0.1 -Port 3000
Test-NetConnection 127.0.0.1 -Port 1433
```

### 18.7 Health checks

```powershell
Invoke-WebRequest http://127.0.0.1/ -UseBasicParsing
Invoke-WebRequest http://127.0.0.1/api/health -UseBasicParsing
Invoke-WebRequest http://127.0.0.1/api/health/database -UseBasicParsing
```

---

## 19. Checklist antes de entregar un instalador a cliente

### 19.1 Checklist de build

- [ ] `runtime-cache` completo.
- [ ] `parqueRM-backend` compila.
- [ ] `parqueRM-frontend` compila.
- [ ] `release` limpio.
- [ ] `.exe` generado en `parqueRM-root\release`.
- [ ] Version correcta en `version.json`.
- [ ] No hay instalador viejo bloqueado.
- [ ] Se probo en VM limpia.

### 19.2 Checklist de instalacion en VM

- [ ] Instalar como administrador.
- [ ] Confirmar que detecta IP correcta.
- [ ] Probar contrasena SQL nueva.
- [ ] Probar login inicial `admin` / `admin1` en VM limpia.
- [ ] Confirmar servicios corriendo.
- [ ] Abrir `http://127.0.0.1/`.
- [ ] Abrir `http://IP_LAN/` desde la misma VM.
- [ ] Probar desde otra PC de la LAN si aplica.
- [ ] Ejecutar `show-status.bat`.
- [ ] Ejecutar `collect-diagnostics.bat`.
- [ ] Confirmar que `park_config.system_lan_url` tiene la IP correcta.
- [ ] Confirmar backup manual.

### 19.3 Checklist de entrega al cliente

- [ ] Entregar instalador `.exe`.
- [ ] Entregar usuario inicial: `admin`.
- [ ] Aclarar que el instalador configura la contrasena admin como `admin1`.
- [ ] Aclarar que una reinstalacion tambien reconfigura `admin` como `admin1`.
- [ ] Aclarar que la contrasena admin no se puede recuperar, solo resetear.
- [ ] Recomendacion de IP fija o reserva DHCP.
- [ ] Indicar ruta de backups: `C:\ParqueRM\backups`.
- [ ] Indicar herramienta de diagnostico: "Diagnostico ParqueRM".
- [ ] Indicar que no se requiere internet durante instalacion si el `.exe` fue generado correctamente.

---

## 20. Seguridad y datos sensibles

### 20.1 Secretos guardados

El backend `.env` contiene:

- `DB_PASSWORD`
- `JWT_SECRET`
- `JWT_REFRESH_SECRET`

Ruta:

```text
C:\ParqueRM\app\backend\.env
```

Este archivo no debe compartirse sin censurar.

El diagnostico censura:

```text
DB_PASSWORD
JWT_SECRET
JWT_REFRESH_SECRET
```

### 20.2 SQL Server

Por defecto:

- SQL Server se usa localmente.
- El firewall no abre 1433 a LAN.
- La app usa `sa` para conectar al SQL local.

### 20.3 Usuario admin

La contrasena web de `admin`:

- El instalador la configura como `admin1`.
- En reinstalaciones tambien se reconfigura como `admin1`.
- No se guarda en texto plano.
- Se guarda como bcrypt.
- No es recuperable.
- Puede resetearse con soporte tecnico.

---

## 21. Relacion con Docker

El repo puede tener flujos Docker para desarrollo o despliegues alternativos, pero el instalador Windows actual no depende de Docker.

Ventajas del instalador actual:

- No requiere Docker Desktop en el cliente.
- No requiere descargar imagenes.
- Funciona sin internet si el `.exe` trae runtime completo.
- Registra servicios Windows nativos.
- Permite soporte con logs y diagnosticos locales.

Ventajas potenciales de Docker:

- Aislamiento de dependencias.
- Menos conflicto con SQL Server existente.
- Menos variacion entre maquinas.

Riesgos de Docker para este caso:

- Docker Desktop puede requerir instalacion adicional.
- Puede requerir WSL2/virtualizacion.
- Las imagenes deben empaquetarse offline.
- El soporte remoto sin internet se vuelve dependiente de imagenes, volumenes y runtime Docker.

Conclusion actual: para cliente Windows offline, el instalador nativo sigue siendo razonable siempre que se pruebe bien en VM y que el runtime-cache este completo.

---

## 22. Mapa de archivos instalados

```text
C:\ParqueRM
  app
    backend
      dist
      node_modules
      .env
    frontend
      dist
        config.json
    database
      init
      migrations
  backups
  config
    Caddyfile
    db-ready.json
    parquerm.config.json
  diagnostics
  logs
    backend
    frontend
    db-init
    startup-check.log
  runtime
    caddy
    node
    sqlcmd
    sqlserver-express
    winsw
  services
    ParqueRMBackend
    ParqueRMFrontend
  tools
    installer-scripts
    open-parquerm.bat
    show-status.bat
    start-services.bat
    stop-services.bat
    restart-services.bat
    backup-db.bat
    restore-db.bat
    change-server-ip.bat
    collect-diagnostics.bat
  version.json
```

---

## 23. Glosario rapido

| Termino | Significado |
|---|---|
| `sa` | Usuario administrador tecnico de SQL Server |
| `admin` | Usuario web inicial de ParqueRM |
| WinSW | Herramienta que permite correr ejecutables como servicios Windows |
| Caddy | Servidor web que sirve frontend y proxy `/api` |
| `db-ready.json` | Marcador que confirma que DB init termino correctamente |
| `runtime-cache` | Carpeta usada para empaquetar instalador offline |
| `diagnostics.zip` | Paquete de soporte generado en campo |
| `system_lan_url` | URL LAN guardada en configuracion del parque dentro de SQL |

---

## 24. Resumen de rutas importantes

| Uso | Ruta |
|---|---|
| Instalacion | `C:\ParqueRM` |
| Config central | `C:\ParqueRM\config\parquerm.config.json` |
| Backend env | `C:\ParqueRM\app\backend\.env` |
| Frontend config | `C:\ParqueRM\app\frontend\dist\config.json` |
| Caddyfile | `C:\ParqueRM\config\Caddyfile` |
| Logs DB | `C:\ParqueRM\logs\db-init` |
| Logs backend | `C:\ParqueRM\logs\backend` |
| Logs frontend | `C:\ParqueRM\logs\frontend` |
| Logs IP startup | `C:\ParqueRM\logs\startup-check.log` |
| Backups | `C:\ParqueRM\backups` |
| Diagnosticos | `C:\ParqueRM\diagnostics` |
| Herramientas | `C:\ParqueRM\tools` |

---

## 25. Resumen ejecutivo para soporte

Cuando el cliente reporta que ParqueRM no abre:

1. Pedir que ejecute "Diagnostico ParqueRM".
2. Pedir el `.zip` de `C:\ParqueRM\diagnostics`.
3. Revisar servicios, puertos, health checks y ultimo DB init log.
4. Si puerto 80 falla, revisar `ParqueRMFrontend` y Caddy.
5. Si `/api/health` falla, revisar `ParqueRMBackend`.
6. Si `/api/health/database` falla, revisar SQL Server y `.env`.
7. Si login admin falla, resetear password; no intentar recuperarla.
8. Si IP cambio, ejecutar `change-server-ip.bat`.
9. Antes de cambios destructivos, crear backup `.bak`.

El instalador debe ser tratado como sistema offline de produccion: cualquier mejora debe probarse en VM limpia y en VM con SQL Server ya instalado.
