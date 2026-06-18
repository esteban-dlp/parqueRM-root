# Manual del instalador de ParqueRM

Documento tecnico y operativo para construir, instalar, diagnosticar y mantener ParqueRM en Windows.

Fecha de referencia: 2026-06-15  
Version objetivo del instalador: 1.0.7  
Ruta del instalador en el repo: `parqueRM-root/installer`  
Ruta por defecto instalada: `C:\ParqueRM`

## 1. Objetivo

ParqueRM 1.0.7 usa un flujo local/offline-first:

- Principal: `http://parquerm.local`
- Alias heredado: `http://parque.rm.local`
- Fallback: `http://<IP-del-servidor>`
- Sin abrir router, TP-Link ni guia DHCP durante una instalacion normal.
- Sin depender de CoreDNS para instalaciones nuevas.
- Sin tocar base de datos, contrasenas, JWT, refresh secrets ni datos existentes durante actualizaciones.

El usuario final debe poder instalar, abrir el acceso directo y entrar a ParqueRM sin abrir PowerShell ni configurar un router.

## 2. Arquitectura

| Componente | Proposito |
|---|---|
| SQLite | Base local `C:\ParqueRM\data\parquerm.db` |
| Backend NestJS | API REST en `0.0.0.0:3000` |
| Frontend React | App web estatica |
| Caddy | Puerto 80, frontend y proxy `/api/* -> 127.0.0.1:3000` |
| ParqueRMLocalName | mDNS `parquerm.local`/`parque.rm.local` y discovery UDP 47880 |
| WinSW | Servicios Windows |
| ParqueRMDns | Solo legado si ya existia desde 1.0.6 |

Flujo HTTP:

```text
Browser LAN
  -> http://parquerm.local
  -> Caddy TCP 80
  -> /api/* proxy a 127.0.0.1:3000
  -> Backend
  -> SQLite local
```

El frontend debe usar siempre:

```json
{ "apiUrl": "/api" }
```

## 3. Modos de instalacion

| Modo | Uso |
|---|---|
| Instalacion completa | Maquina que hospeda base, backend y frontend |
| Solo cliente | PC Windows donde `.local` no funciona y se necesita mapear `hosts` automaticamente |

### Instalacion completa

Instala:

- `ParqueRMBackend`
- `ParqueRMFrontend`
- `ParqueRMLocalName`
- SQLite/base local
- Reglas firewall TCP 80, UDP 5353 y UDP 47880
- Tarea `ParqueRM_IpCheck`

No instala CoreDNS como requisito. Si `ParqueRMDns` ya existia, se preserva para compatibilidad.

### Solo cliente

Requiere administrador porque edita:

```text
C:\Windows\System32\drivers\etc\hosts
```

Tambien registra:

```text
ParqueRM_ClientNameRefresh
```

Orden de descubrimiento:

1. IP manual/preferida.
2. Ultima IP conocida.
3. mDNS `parquerm.local`, luego `parque.rm.local`.
4. Broadcast UDP 47880.
5. Escaneo rapido de la subred, preferentemente `/24`, solo TCP 80.
6. Validacion unica por `http://<ip>/api/health`.

Si encuentra multiples servidores con distinto `instanceId`, no sobrescribe `hosts`. Si la ultima IP conocida sigue respondiendo, la mantiene.

## 4. Puertos y firewall

| Puerto | Protocolo | Uso | Firewall por defecto |
|---:|---|---|---|
| 80 | TCP | Caddy web y `/api` | Si |
| 5353 | UDP | mDNS best effort | Si |
| 47880 | UDP | Discovery ParqueRM | Si |
| 3000 | TCP | Backend interno | No |
| 53 | TCP/UDP | CoreDNS legado | No en instalaciones nuevas |

## 5. Health publico

Endpoint:

```text
GET /api/health
```

Debe ser publico, rapido y sin JWT.

Respuesta minima:

```json
{
  "app": "ParqueRM",
  "status": "ok",
  "version": "1.0.7",
  "instanceId": "<id-no-secreto>",
  "timestamp": "2026-06-15T..."
}
```

`instanceId` se genera una vez si falta y se guarda en `.env`/config. No es secreto; sirve para detectar conflictos en una red con dos servidores ParqueRM.

## 6. Configuracion generada

Archivos principales:

```text
C:\ParqueRM\app\backend\.env
C:\ParqueRM\app\frontend\dist\config.json
C:\ParqueRM\config\parquerm.config.json
C:\ParqueRM\config\Caddyfile
```

Valores esperados:

```text
PUBLIC_FRONTEND_URL=http://parquerm.local
PUBLIC_BACKEND_URL=http://parquerm.local/api
PARQUERM_INSTANCE_ID=<persistente>
```

El valor SQLite `park_config.system_lan_url` queda alineado con:

```text
http://parquerm.local
```

## 7. Build

Desde PowerShell:

```powershell
cd C:\Users\Esteban\OneDrive\PROYECTOS\parqueRM\parqueRM-root\installer
.\build-installer.bat
```

Runtime cache requerido:

| Carpeta | Archivo |
|---|---|
| `runtime-cache\node` | `node.exe` |
| `runtime-cache\caddy` | `caddy.exe` |
| `runtime-cache\winsw` | WinSW |
| `runtime-cache\sqlite` | `sqlite3.exe` |

Opcional:

| Carpeta | Uso |
|---|---|
| `runtime-cache\coredns` | Compatibilidad con instalaciones 1.0.6 |

Resultado:

```text
parqueRM-root\release\ParqueRM-Setup-v1.0.7.exe
```

## 8. Validacion despues de instalar

En el servidor:

```powershell
Invoke-WebRequest http://127.0.0.1/ -UseBasicParsing
Invoke-WebRequest http://127.0.0.1/api/health -UseBasicParsing
Invoke-WebRequest http://parquerm.local/api/health -UseBasicParsing
Get-Service ParqueRMBackend,ParqueRMFrontend,ParqueRMLocalName
```

Desde otra PC de la LAN:

1. Abrir `http://parquerm.local`.
2. Si no abre, probar `http://<IP-del-servidor>`.
3. Si la IP abre, instalar **Solo cliente** en esa PC.

## 9. Boton para compartir URL por IP

En el Dashboard existe el boton:

```text
Generar URL por IP
```

Al presionarlo, el frontend llama:

```text
GET /api/health/local-access
```

El backend detecta la IP LAN util actual del servidor y devuelve una URL de login:

```text
http://<IP-del-servidor>/login
```

Ejemplo:

```text
http://192.168.68.62/login
```

La pantalla muestra:

- URL para trabajadores en la red.
- IP del servidor.
- Boton para copiar la URL.

Este endpoint no devuelve contrasenas, JWT, secretos ni datos de negocio. Solo expone datos de conectividad local: app, version, instanceId, IPs LAN y URL generada.

## 10. Herramientas instaladas

| Herramienta | Uso |
|---|---|
| `open-parquerm.bat` | Inicia servicios si hace falta y abre ParqueRM |
| `show-status.bat` | Estado, IPs, health, puertos y firewall |
| `start-services.bat` | Inicia servicios |
| `stop-services.bat` | Detiene servicios |
| `restart-services.bat` | Reinicia servicios |
| `change-server-ip.bat` | Repara `hosts` local y reinicia `ParqueRMLocalName` |
| `backup-db.bat` | Backup manual |
| `restore-db.bat` | Restore manual |
| `collect-diagnostics.bat` | Genera diagnostico zip |

## 11. Diagnostico

Generar diagnostico:

```bat
C:\ParqueRM\tools\collect-diagnostics.bat
```

Incluye:

- IPs LAN utiles.
- `instanceId`.
- Health de frontend/API/base.
- Resolucion de `parquerm.local` y `parque.rm.local`.
- Estado firewall TCP 80, UDP 5353 y UDP 47880.
- Estado de discovery y conflictos.
- `.env` con `JWT_SECRET` y `JWT_REFRESH_SECRET` censurados.
- Logs recientes.

## 12. Casos comunes

### `parquerm.local` abre en el servidor pero no en otra PC

Esto puede pasar porque mDNS es best effort y algunas redes bloquean multicast.

Accion:

1. En el servidor ejecutar `show-status.bat` y anotar la IP.
2. En la otra PC abrir `http://<IP-del-servidor>`.
3. Si abre, instalar **Solo cliente** en esa PC.

### La IP del servidor cambia

El servicio `ParqueRMLocalName` recalcula IPs actuales. PCs con **Solo cliente** refrescan `hosts` con la tarea `ParqueRM_ClientNameRefresh` si pueden descubrir el servidor por mDNS, UDP discovery o escaneo.

### Hay dos servidores ParqueRM en la misma red

Discovery detecta distintos `instanceId`. El modo Solo Cliente no sobrescribe `hosts` automaticamente. Use `show-status.bat`/diagnostico para decidir cual servidor debe quedar activo.

### Puerto 80 ocupado

Revisar:

```powershell
netstat -ano | findstr ":80"
Get-Service ParqueRMFrontend
```

### Backend no responde

Revisar:

```powershell
Get-Service ParqueRMBackend
Get-Content C:\ParqueRM\logs\backend\*.log -Tail 100
Invoke-WebRequest http://127.0.0.1/api/health -UseBasicParsing
```

### Database health falla

Revisar:

```powershell
Test-Path C:\ParqueRM\data\parquerm.db
Invoke-WebRequest http://127.0.0.1/api/health/database -UseBasicParsing
```

## 13. Seguridad

No compartir sin censurar:

```text
C:\ParqueRM\app\backend\.env
```

El diagnostico censura:

- `JWT_SECRET`
- `JWT_REFRESH_SECRET`

`PARQUERM_INSTANCE_ID` no es secreto.

SQLite es un archivo local y el backend no se expone directamente a LAN por defecto; el acceso normal es por Caddy en TCP 80.
