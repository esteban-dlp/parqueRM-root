Caddy -- Windows Web Server Binary
===================================

Place the Caddy web server binary in this folder.

Expected file: caddy.exe

Download from:
  https://caddyserver.com/download

Steps:
  1. Go to: https://caddyserver.com/download
  2. Select platform: Windows
  3. Select architecture: amd64
  4. Leave plugins empty (no extra plugins needed)
  5. Click "Download"
  6. Rename the downloaded file to caddy.exe
  7. Place it in this folder.

Alternative -- download directly from GitHub Releases:
  https://github.com/caddyserver/caddy/releases/latest
  Download: caddy_2.x.x_windows_amd64.zip
  Unzip and copy caddy.exe here.

Caddy is used as the production web server for the React frontend.
It serves static files from C:\ParqueRM\app\frontend\dist\ on port 80.
It handles URL rewriting for the React SPA (try_files to /index.html).

The Caddyfile is generated at install time at:
  C:\ParqueRM\config\Caddyfile

Note: Do NOT commit caddy.exe to git. Add runtime-cache/ to .gitignore.
