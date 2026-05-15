WinSW -- Windows Service Wrapper
=================================

Place the WinSW binary in this folder.

Expected filename: WinSW-x64.exe
   (rename to WinSW.exe if you prefer -- install-services.ps1 checks both names)

Download from:
  https://github.com/winsw/winsw/releases

Steps:
  1. Go to: https://github.com/winsw/winsw/releases/latest
  2. Download: WinSW-x64.exe  (for 64-bit Windows)
  3. Place it in this folder.
     Name it WinSW-x64.exe OR WinSW.exe -- both are detected.

WinSW is used to register ParqueRM services as Windows auto-start services:
  - ParqueRMBackend  : runs Node.js backend (NestJS)
  - ParqueRMFrontend : runs Caddy web server

For each service, install-services.ps1:
  1. Copies WinSW.exe to C:\ParqueRM\services\<ServiceId>\<ServiceId>.exe
  2. Writes a <ServiceId>.xml config file
  3. Calls <ServiceId>.exe install

Services are set to start automatically with Windows.
On failure, they restart after 10 seconds (then 20 seconds, then stop).

Note: Do NOT commit WinSW binary to git. Add runtime-cache/ to .gitignore.
