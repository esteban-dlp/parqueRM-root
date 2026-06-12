# ParqueRM Installer

This folder builds the single offline Windows installer for ParqueRM.

The output is one versioned executable:

```bat
parqueRM-root\release\ParqueRM-Setup-v1.0.3.exe
```

There is no separate updater. Run the same setup executable on a clean machine or over an existing ParqueRM installation.

## Architecture

The production installer avoids Docker and packages:

- SQL Server Express, installed from the offline runtime cache when needed.
- Portable Node.js, used to run the NestJS backend.
- Caddy, used to serve the React frontend on port 80.
- WinSW, used to register backend and frontend as Windows services.
- A local-name service that publishes `parque.rm.local`/`parquerm.local` through mDNS when the LAN supports it.

## Runtime Cache

Place these files under `installer\runtime-cache\` before building:

| Folder | Required file |
|--------|---------------|
| `sqlserver-express` | `SQLEXPR_x64_ENU.exe` or similar |
| `sqlserver-express\updates` | Optional SQL Server 2022 CU package, for example `SQLServer2022-KBxxxxxxx-x64.exe` |
| `node` | `node.exe` |
| `caddy` | `caddy.exe` |
| `winsw` | `WinSW.exe` or `WinSW-x64.exe` |
| `sqlcmd` | `sqlcmd.exe` |

## Build

```bat
cd parqueRM-root\installer
build-installer.bat
```

Useful flags:

| Flag | Purpose |
|------|---------|
| `-SkipRuntimeValidation` | Build without requiring runtime-cache files |
| `-SkipInstallerCompile` | Generate `release\` files but skip Inno Setup |
| `-SkipNpmInstall` | Reuse existing backend/frontend build artifacts |

## Fresh Or Existing Install

The same installer handles both cases.

| Area | Fresh install | Existing install |
|------|---------------|------------------|
| SQL Server | Installed from runtime cache | Reused if present |
| Database | Created and seeded | Existing data kept; missing init/migrations are applied |
| Backend `.env` | Generated | Regenerated for stable local URL; existing JWT secrets preserved |
| Frontend `config.json` | Generated with same-origin `/api` | Regenerated with same-origin `/api` |
| Services | Installed | Reinstalled and restarted |
| Runtime binaries | Installed | Refreshed from installer |

## Installation Flow

The setup:

1. Configures the stable local URL `http://parque.rm.local`.
2. Opens firewall rules for Caddy TCP 80 and mDNS UDP 5353.
3. Installs or reuses SQL Server Express.
4. Applies the SQL Server NVMe/sector-size compatibility registry fix before SQL install/update when required, then asks for a reboot.
5. Initializes the database, prepares the initial `admin` password only when needed, and runs migrations.
6. Generates backend/frontend configuration.
7. Installs and starts Windows services.
8. Validates frontend, backend health, and database health before reporting success.

If validation fails, the final screen points to the relevant logs instead of claiming the app is ready.

## Services

Services created:

- `ParqueRMBackend`: runs `node dist\main.js` in `C:\ParqueRM\app\backend`.
- `ParqueRMFrontend`: runs Caddy with `C:\ParqueRM\config\Caddyfile`.
- `ParqueRMLocalName`: publishes the current IPv4 address for `parque.rm.local` and `parquerm.local` through mDNS.

## Configuration

The installer writes:

- `C:\ParqueRM\app\backend\.env`
- `C:\ParqueRM\app\frontend\dist\config.json`
- `C:\ParqueRM\config\parquerm.config.json`
- `park_config.system_lan_url` in SQL Server, using `http://parque.rm.local`.
- Windows `hosts`, mapping `parque.rm.local` and `parquerm.local` to `127.0.0.1` on the server.

The frontend runtime config points to the same origin:

```text
/api
```

Caddy serves the frontend on port 80 and proxies `/api/*` to the local backend service on port 3000. The browser opens `http://parque.rm.local`, and the frontend calls the backend with same-origin `/api`.

Recommended access:

```text
http://parque.rm.local
```

Backend access goes through the same origin:

```text
http://parque.rm.local/api
```

`parque.rm.local` is guaranteed on the installed server through the Windows hosts file. For other computers on the same LAN, the installer also starts an mDNS responder. If a router, Windows policy, antivirus, or client OS blocks mDNS multicast, use the fallback URLs shown by diagnostics.

To repair the local URL entries and restart the name responder:

```bat
C:\ParqueRM\tools\change-server-ip.bat
```

The application login user is always:

```text
admin
```

The installer configures the `admin` password as:

```text
admin1
```

The installer no longer asks for this user's password. During installation, it writes and verifies a bcrypt hash for `admin1`.

## Backups And Restore

Manual backup:

```bat
C:\ParqueRM\tools\backup-db.bat
```

Manual restore:

```bat
C:\ParqueRM\tools\restore-db.bat
```

Backups are written to:

```text
C:\ParqueRM\backups
```

## Troubleshooting

Check service state:

```powershell
Get-Service ParqueRMBackend,ParqueRMFrontend,ParqueRMLocalName
```

Check ports:

```powershell
netstat -ano | findstr ":80 :3000 :1433 :5353"
```

Check backend:

```powershell
Invoke-WebRequest http://parque.rm.local/api/health -UseBasicParsing
Invoke-WebRequest http://parque.rm.local/api/health/database -UseBasicParsing
```

Useful logs:

```text
C:\ParqueRM\logs\backend\ParqueRMBackend.err.log
C:\ParqueRM\logs\backend\ParqueRMBackend.wrapper.log
C:\ParqueRM\logs\db-init\
C:\ParqueRM\logs\network\
```

Collect full diagnostics:

```bat
C:\ParqueRM\tools\collect-diagnostics.bat
```

Build command:

```bat
cd parqueRM-root\installer
build-installer.bat
```
