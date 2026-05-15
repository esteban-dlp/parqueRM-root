# ParqueRM — Installer & Update Pipeline

## What this system does

This folder contains everything needed to build a professional, 100% offline Windows installer for ParqueRM — a local-network management system for a national park.

The build pipeline compiles the NestJS backend and React frontend, packages them with Windows service wrappers and offline runtime binaries, and produces a single `.exe` installer using Inno Setup 6.

---

## Why not Docker in production?

Docker requires:
- Docker Desktop (requires Hyper-V or WSL2, admin setup, ~500 MB)
- Internet access to pull images on first run
- Continuous background daemon

The park operates on a minimal Windows server PC. Docker adds unnecessary complexity and failure modes for non-technical operators. The production installer instead uses:

- **SQL Server Express** (installed from offline package)
- **Node.js** (portable or installed, runs the NestJS backend)
- **Caddy** (single binary web server, serves the React SPA)
- **WinSW** (Windows Service Wrapper — registers Node and Caddy as auto-start Windows services)

---

## What "100% offline" means

Once you place the required runtime files in `installer/runtime-cache/`, the build and installation process never contacts the internet. Everything — SQL Server, Node.js, Caddy, WinSW, npm packages — is bundled in the installer.

---

## Required offline runtime files

Place these in `installer/runtime-cache/` **before** running `build-installer.bat`:

| Folder | Required file | Source |
|--------|--------------|--------|
| `runtime-cache/sqlserver-express/` | `SQLEXPR_x64_ENU.exe` (or similar) | [Microsoft SQL Server Express](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) — Download the "Express" edition offline installer |
| `runtime-cache/node/` | `node.exe` (portable) **or** `node-vX.X.X-win-x64.zip` | [nodejs.org/dist/](https://nodejs.org/dist/) — download Windows binary zip |
| `runtime-cache/caddy/` | `caddy.exe` | [caddyserver.com/download](https://caddyserver.com/download) — Windows AMD64 |
| `runtime-cache/winsw/` | `WinSW-x64.exe` (rename to `WinSW.exe`) | [github.com/winsw/winsw/releases](https://github.com/winsw/winsw/releases) |
| `runtime-cache/sqlcmd/` | `sqlcmd.exe` (optional if SQL tools installed) | Included with SQL Server tools install |

> **Note:** Do NOT commit binary files to git unless the repository explicitly allows large files. Add `runtime-cache/` to `.gitignore` and distribute binaries out-of-band (shared drive, Sharepoint, etc.).

---

## How to build the installer

### Prerequisites (developer machine)

- Node.js (for building backend/frontend)
- [Inno Setup 6](https://jrsoftware.org/isinfo.php) installed at default path
- All `runtime-cache/` folders populated (see above)

### Build command

```bat
cd parqueRM-root\installer
build-installer.bat
```

**Output:** `parqueRM-root\release\ParqueRM-Setup-v1.0.0.exe`

### Build without Inno Setup (dry run)

```bat
build-installer.bat -SkipInstallerCompile
```

Generates all `release/` artifacts without compiling the `.exe`. Useful to verify the pipeline.

### Build without runtime validation (CI / testing)

```bat
build-installer.bat -SkipRuntimeValidation -SkipInstallerCompile
```

### Available flags

| Flag | Purpose |
|------|---------|
| `-SkipRuntimeValidation` | Don't require runtime-cache to have files |
| `-SkipInstallerCompile` | Skip Inno Setup ISCC.exe |
| `-SkipNpmInstall` | Skip both `npm ci` and `npm run build` (use existing dist/ artifacts) |
| `-Clean` | (Always cleans by default) |

---

## How to build an update package

```bat
cd parqueRM-root\installer
build-update.bat
```

**Output:** `parqueRM-root\release\updates\ParqueRM-Update-v1.0.0.zip`

### Default update package (code-only changes)

By default, `build-update.bat` produces a small package (~1 MB) that includes:
- New backend `dist/` (compiled TypeScript)
- `package.json`
- New frontend `dist/` (compiled React)
- New database migrations
- `apply-update.ps1` and `run-migrations.ps1` scripts
- `version.json`

node_modules is **NOT** included. The installed server keeps its existing node_modules.

Use this for most updates -- when only application code changed.

### When npm dependencies changed: include node_modules

```bat
build-update.bat -IncludeNodeModules
```

This produces a larger package (~70+ MB) that also includes the full `node_modules`.
The `apply-update.ps1` script detects and copies them properly.

Use only when `package.json` dependencies changed.

### Skip rebuild (use existing dist artifacts)

```bat
build-update.bat -SkipBuild
```

Uses existing `dist/` from last build. Useful when you already ran a full build.

### Available flags

| Flag | Purpose |
|------|---------|
| `-SkipNpmInstall` | Skip `npm ci` before building |
| `-SkipBuild` | Use existing dist artifacts, skip compile |
| `-IncludeNodeModules` | Include node_modules in the update zip |

### What update packages NEVER contain

- SQL Server installer or runtime binaries
- Existing `.env` (never overwritten by updates)
- Existing `config.json` (never overwritten by updates)

---

## Fresh install vs. update

| Aspect | Fresh install | Update |
|--------|--------------|--------|
| SQL Server | Installed from runtime-cache | Not touched |
| Database | Created + all init scripts run | Only new migrations run |
| Backend .env | Generated by installer | **Preserved** |
| Frontend config.json | Generated by installer | **Preserved** |
| Windows services | Installed as auto-start | Stopped, updated, restarted |
| Runtime binaries | Installed | Not touched |

---

## Client-only install

When the installer runs, the user can choose "Solo cliente" mode. This:
- Does NOT install SQL Server, backend, or frontend
- Asks for the server IP
- Creates an `.url` file (internet shortcut) pointing to `http://SERVER_IP`
- Creates Start Menu and Desktop shortcuts

Use this mode on workstations that only need browser access to the park system.

---

## Server IP detection

The script `installer/scripts/get-local-ip.ps1` auto-detects the LAN IP by:
1. Listing all network adapters with IPv4 addresses
2. Excluding loopback (127.*), APIPA (169.254.*), disconnected adapters
3. Excluding virtual adapters (Docker, VMware, Hyper-V, WSL, Bluetooth, etc.)
4. Preferring wired (Ethernet) over wireless when multiple candidates exist
5. If multiple valid IPs remain, prompting the user to choose

---

## Frontend runtime config

At build time, Vite bakes `VITE_API_URL` from `.env` into the bundle. For production, the API URL depends on the server IP, which is unknown at build time.

**Solution:** The frontend loads `/config.json` at runtime (in `src/main.tsx` → `initRuntimeConfig()`), which overrides `apiClient.defaults.baseURL` before any API call is made.

- Development: `public/config.json` contains `http://localhost:3000/api` (fallback to `.env` if file missing)
- Production: the installer writes `C:\ParqueRM\app\frontend\dist\config.json` with the real server IP
- If `/config.json` fails to load, the bundle falls back to `VITE_API_URL` (fine for dev)

The config.json **is never included** in the update package, so a server IP change doesn't get overwritten by updates.

---

## Backend host/port config

`src/main.ts` already reads:
```typescript
const port = process.env.PORT ?? 3000;
await app.listen(port, '0.0.0.0');
```

The backend listens on all interfaces by default. The installer writes `HOST=0.0.0.0` and `PORT=3000` in `.env`.

---

## How services are installed

Uses **WinSW** (Windows Service Wrapper). For each service, `install-services.ps1`:
1. Copies `WinSW.exe` to `C:\ParqueRM\services\<ServiceId>\<ServiceId>.exe`
2. Writes `<ServiceId>.xml` (WinSW config: executable, args, working dir, log dir, restart policy)
3. Calls `<ServiceId>.exe install` to register the Windows service
4. Sets service to auto-start

Services created:
- `ParqueRMBackend` — runs `node dist/main.js` in `C:\ParqueRM\app\backend`
- `ParqueRMFrontend` — runs `caddy.exe run --config Caddyfile` (serves the React dist on port 80)

**Why WinSW over NSSM?** WinSW uses a simple XML config, has no extra GUI, and is actively maintained. NSSM is also good but requires interactive setup or complex CLI. WinSW integrates cleanly with automated installers.

---

## How firewall rules are created

`configure-firewall.ps1` uses `New-NetFirewallRule` (Windows built-in) to add:

| Rule | Port | Default |
|------|------|---------|
| ParqueRM Frontend TCP 80 | 80 | Created |
| ParqueRM Backend TCP 3000 | 3000 | Created |
| ParqueRM SQL Server TCP 1433 | 1433 | NOT created (LAN exposure discouraged) |

To expose SQL Server on LAN: `configure-firewall.ps1 -EnableSqlServerPort`

---

## How database initialization works

`initialize-db.ps1`:
1. Checks for existing SQL Server service
2. If not found and not skipped, runs offline SQL Server Express installer from `runtime-cache/sqlserver-express/`
3. Ensures the SQL Server service is running
4. Creates the `ParqueRM` database if it doesn't exist
5. Runs all `db/init/*.sql` scripts (idempotent — safe to re-run)
6. Calls `run-migrations.ps1` for any pending migrations

**Admin password note:** The installer UI collects the SA password interactively (never stored in scripts or SQL files). It's written to `C:\ParqueRM\app\backend\.env` as `DB_PASSWORD`.

---

## How migrations work

`run-migrations.ps1`:
1. Connects to SQL Server
2. Creates `schema_migrations` table if it doesn't exist
3. Finds `.sql` files in `db/migrations/` sorted alphabetically
4. Skips files already recorded in `schema_migrations`
5. Runs new migrations with `sqlcmd -b` (stop on error)
6. Records each successful migration
7. Exits with error code 1 on any failure (never silently continues)

Migration files must follow the naming convention: `NNN_description.sql` (e.g., `002_add_vehicles_table.sql`).

---

## How backups work

- **Manual:** `tools/backup-db.bat` — prompts for SA password, writes `.bak` to `C:\ParqueRM\backups\`
- **Before update:** `apply-update.ps1` automatically runs a backup before stopping services
- **Format:** SQL Server `BACKUP DATABASE ... TO DISK=...` native format

---

## How restore works

`tools/restore-db.bat`:
1. Asks for the `.bak` file path
2. Asks for confirmation (irreversible)
3. Stops services
4. Runs `RESTORE DATABASE ... WITH REPLACE`
5. Restarts services

---

## How to change server IP after installation

Run: `tools/change-server-ip.bat`

This:
1. Shows current IP
2. Asks for new IP
3. Updates `app\backend\.env` (replaces all IP occurrences)
4. Updates `app\frontend\dist\config.json`
5. Updates `config\parquerm.config.json`
6. Restarts services

---

## Versioning

`version.json` in `parqueRM-root/`:
```json
{
  "appName": "ParqueRM",
  "version": "1.0.0",
  "buildDate": "",
  "buildNumber": ""
}
```

Build scripts read this and:
- Inject `buildDate` (current timestamp)
- Generate `buildNumber` (yyyyMMddHHmm)
- Name the installer `ParqueRM-Setup-v1.0.0.exe`
- Copy `version.json` with filled fields into `release/`

---

## Troubleshooting

### Inno Setup missing
```
ERROR: ISCC.exe not found
```
Install Inno Setup 6 from https://jrsoftware.org/isinfo.php, or use `-SkipInstallerCompile`.

### runtime-cache missing files
```
MISSING: installer\runtime-cache\caddy\ — Caddy Windows binary
```
Download and place the required binary in the listed folder. See "Required offline runtime files" above.

### Port 80 busy
Caddy fails to start. Check what's using port 80:
```powershell
netstat -ano | findstr :80
```
Stop IIS or any other web server, then restart the ParqueRMFrontend service.

### Port 3000 busy
Same approach. Find and stop the conflicting process.

### SQL Server not installed
`initialize-db.ps1` reports "SQL Server service not found". Ensure `runtime-cache/sqlserver-express/SQLEXPR_x64_ENU.exe` is present and re-run the installer, or install SQL Server Express manually.

### SQL Server service not running
```powershell
Start-Service MSSQLSERVER
```
or
```powershell
Start-Service 'MSSQL$SQLEXPRESS'
```

### Firewall blocking LAN access
Run as admin:
```powershell
.\installer\scripts\configure-firewall.ps1
```
Check Windows Defender Firewall → Inbound Rules → look for "ParqueRM" rules.

### Frontend cannot reach backend
1. Check `C:\ParqueRM\app\frontend\dist\config.json` — `apiUrl` must match the server IP.
2. Check backend service is running: `Get-Service ParqueRMBackend`
3. Check port 3000 is open: `netstat -ano | findstr :3000`

### Wrong API URL (frontend shows network error)
Update `config.json` to the correct IP and restart the browser (hard refresh). If the IP changed, run `change-server-ip.bat`.

### IP changed after installation
Run `C:\ParqueRM\tools\change-server-ip.bat` or `change-server-ip.bat` from the tools folder.

### Update failed midway
The update log is in `C:\ParqueRM\logs\updates\`. Check the last log file.

Services may be stopped. Restart manually:
```powershell
Start-Service ParqueRMBackend
Start-Service ParqueRMFrontend
```

If DB is corrupt, restore the backup created before the update:
```
C:\ParqueRM\backups\ParqueRM-backup-YYYYMMDD-HHMMSS.bak
```
Use `restore-db.bat`.

### Migration failed
Check `C:\ParqueRM\logs\updates\` for the error. Fix the migration SQL file, then re-run:
```powershell
.\installer\scripts\run-migrations.ps1 -DbPassword "..." -DbName "ParqueRM" -MigrationsDir "C:\ParqueRM\app\database\migrations"
```
Migrations already applied will be skipped automatically.
