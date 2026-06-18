# ParqueRM Installer

This folder builds the single offline Windows installer for ParqueRM.

```text
parqueRM-root\release\ParqueRM-Setup-v1.0.7.exe
```

Run the same executable for a clean installation or an update. Existing SQLite data, JWT secrets, and refresh-token secrets are preserved.

## Architecture

The 1.0.7 installer is LAN/offline-first and does not require router DNS changes for the normal flow.

- SQLite command-line tools (`sqlite3.exe`) for the local database.
- Portable Node.js for the NestJS backend.
- Caddy for the React frontend and same-origin `/api` reverse proxy.
- WinSW for Windows services.
- `ParqueRMLocalName` for mDNS aliases and UDP discovery.
- Optional legacy CoreDNS files may be bundled/preserved for 1.0.6 upgrades, but CoreDNS is not required for new installs.

Canonical URL:

```text
http://parquerm.local
```

Legacy alias:

```text
http://parque.rm.local
```

Fallback:

```text
http://<server-lan-ip>
```

## Runtime Cache

Required files under `installer\runtime-cache\`:

| Folder | Required file |
|---|---|
| `node` | `node.exe` |
| `caddy` | `caddy.exe` |
| `winsw` | `WinSW.exe` or equivalent |
| `sqlite` | `sqlite3.exe` |

Optional legacy folder:

| Folder | Purpose |
|---|---|
| `coredns` | Preserved only for compatibility with earlier 1.0.6 DNS-router installs |

## Build

```bat
cd parqueRM-root\installer
build-installer.bat
```

| Flag | Purpose |
|---|---|
| `-SkipRuntimeValidation` | Build without requiring runtime files |
| `-SkipInstallerCompile` | Generate `release\` without compiling Inno Setup |
| `-SkipNpmInstall` | Reuse existing backend/frontend build artifacts |

## Installation Flow

Server installation:

1. Preserves the existing database and secrets during updates.
2. Initializes or migrates `C:\ParqueRM\data\parquerm.db` with SQLite scripts.
3. Generates backend/frontend config for `http://parquerm.local`.
4. Keeps frontend API config as `"/api"` so Caddy owns the same-origin proxy.
5. Opens firewall TCP 80, UDP 5353, and UDP 47880.
6. Installs `ParqueRMBackend`, `ParqueRMFrontend`, and `ParqueRMLocalName`.
7. Preserves `ParqueRMDns` if it already exists, but does not require it.
8. Shows the primary URL and IP fallback. It does not open router, TP-Link, or DHCP setup pages.

## Services

- `ParqueRMBackend`: NestJS on `0.0.0.0:3000`, used internally.
- `ParqueRMFrontend`: Caddy on LAN TCP 80.
- `ParqueRMLocalName`: mDNS for `parquerm.local`/`parque.rm.local` plus UDP discovery on 47880.
- `ParqueRMDns`: optional legacy service preserved only when already installed.

## Networking

Caddy exposes the app through port 80 and proxies:

```text
/api/* -> 127.0.0.1:3000
```

The frontend must not contain a hard-coded IP or host. Its generated `config.json` remains:

```json
{ "apiUrl": "/api" }
```

Firewall defaults:

| Port | Protocol | Purpose |
|---:|---|---|
| 80 | TCP | Caddy web frontend and `/api` proxy |
| 5353 | UDP | mDNS best-effort local names |
| 47880 | UDP | ParqueRM discovery |

TCP 3000 is not opened to LAN by default.

## Client-Only Fallback

Use **Solo cliente** on a Windows PC only when `http://parquerm.local` does not open from that PC.

Client-only mode:

1. Requires administrator permission because it edits `hosts`.
2. Tries a manual IP, last known IP, mDNS, UDP discovery, then a short `/24` TCP 80 scan.
3. Validates candidates only through `http://<ip>/api/health`.
4. Writes `parquerm.local` and `parque.rm.local` to `hosts` only when one clear server is found.
5. If multiple different `instanceId` values are detected, it does not overwrite `hosts`.
6. Registers `ParqueRM_ClientNameRefresh` to refresh after IP/network changes.

## Generated Configuration

- `C:\ParqueRM\app\backend\.env`
- `C:\ParqueRM\app\frontend\dist\config.json`
- `C:\ParqueRM\config\parquerm.config.json`

`PARQUERM_INSTANCE_ID` is generated once if missing and is not a secret. It is used to detect duplicate ParqueRM servers on the same LAN.

## Troubleshooting

Open status:

```bat
C:\ParqueRM\tools\show-status.bat
```

Collect diagnostics:

```bat
C:\ParqueRM\tools\collect-diagnostics.bat
```

Useful checks:

```powershell
Get-Service ParqueRMBackend,ParqueRMFrontend,ParqueRMLocalName
Invoke-WebRequest http://127.0.0.1/api/health -UseBasicParsing
Invoke-WebRequest http://parquerm.local/api/health -UseBasicParsing
Test-NetConnection 127.0.0.1 -Port 80
```

If another PC cannot open `http://parquerm.local`, try `http://<server-lan-ip>` from that PC. If the IP works, install **Solo cliente** on that Windows PC.

## Sharing The IP URL

Inside the Dashboard, the server user can press **Generar URL por IP**.

The frontend calls:

```text
GET /api/health/local-access
```

The backend detects the current useful LAN IP and returns a login URL like:

```text
http://192.168.68.62/login
```

The button shows the URL, shows the server IP, and tries to copy the URL so the administrator can send it to workers on the same LAN. This does not store or expose secrets.
