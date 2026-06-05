# ParqueRM Installer

This folder builds the single offline Windows installer for ParqueRM.

The output is one versioned executable:

```bat
parqueRM-root\release\ParqueRM-Setup-v1.0.0.exe
```

There is no separate updater. Run the same setup executable on a clean machine or over an existing ParqueRM installation.

## Architecture

The production installer avoids Docker and packages:

- SQL Server Express, installed from the offline runtime cache when needed.
- Portable Node.js, used to run the NestJS backend.
- Caddy, used to serve the React frontend on port 80.
- WinSW, used to register backend and frontend as Windows services.

## Runtime Cache

Place these files under `installer\runtime-cache\` before building:

| Folder | Required file |
|--------|---------------|
| `sqlserver-express` | `SQLEXPR_x64_ENU.exe` or similar |
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
| Backend `.env` | Generated | Regenerated for current IP/password; existing JWT secrets preserved |
| Frontend `config.json` | Generated with same-origin `/api` | Regenerated with same-origin `/api` |
| Services | Installed | Reinstalled and restarted |
| Runtime binaries | Installed | Refreshed from installer |

## Installation Flow

The setup:

1. Opens firewall rules for frontend/backend.
2. Installs or reuses SQL Server Express.
3. Initializes the database, prepares the initial `admin` password only when needed, and runs migrations.
4. Generates backend/frontend configuration.
5. Installs and starts Windows services.
6. Validates frontend, backend health, and database health before reporting success.

If validation fails, the final screen points to the relevant logs instead of claiming the app is ready.

## Services

Services created:

- `ParqueRMBackend`: runs `node dist\main.js` in `C:\ParqueRM\app\backend`.
- `ParqueRMFrontend`: runs Caddy with `C:\ParqueRM\config\Caddyfile`.

## Configuration

The installer writes:

- `C:\ParqueRM\app\backend\.env`
- `C:\ParqueRM\app\frontend\dist\config.json`
- `C:\ParqueRM\config\parquerm.config.json`
- `park_config.system_lan_url` in SQL Server, using the detected server URL.

The frontend runtime config points to the same origin:

```text
/api
```

Caddy serves the frontend on port 80 and proxies `/api/*` to the local backend service on port 3000. This means the browser can open ParqueRM through `localhost`, the current LAN IP, or a future DHCP-assigned IP without changing the frontend API URL.

If you still want to refresh the displayed LAN URLs after the server IP changes, run:

```bat
C:\ParqueRM\tools\change-server-ip.bat
```

The application login user is always:

```text
admin
```

On a fresh database, the initial password is:

```text
admin1
```

The installer no longer asks for this user's password. If the `admin` user already existed before the installer ran, its current password is preserved.

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
Get-Service ParqueRMBackend,ParqueRMFrontend
```

Check ports:

```powershell
netstat -ano | findstr ":80 :3000 :1433"
```

Check backend:

```powershell
Invoke-WebRequest http://127.0.0.1:3000/api/health -UseBasicParsing
Invoke-WebRequest http://127.0.0.1:3000/api/health/database -UseBasicParsing
```

Useful logs:

```text
C:\ParqueRM\logs\backend\ParqueRMBackend.err.log
C:\ParqueRM\logs\backend\ParqueRMBackend.wrapper.log
C:\ParqueRM\logs\db-init\
```
