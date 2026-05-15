Node.js -- Windows Portable Binary
===================================

Place the Node.js Windows portable executable in this folder.

Expected file: node.exe
   (single portable binary, no installer needed)

Or place the zip: node-vX.X.X-win-x64.zip
   (will be extracted by install-services.ps1)

Download from:
  https://nodejs.org/dist/

Recommended version: Latest LTS (e.g., v22.x.x)

Steps:
  1. Go to: https://nodejs.org/dist/latest-v22.x/
  2. Download: node-vX.X.X-win-x64.zip
  3. Unzip it -- you get a folder like node-v22.0.0-win-x64/
  4. Copy node.exe from that folder into this folder.
     (You only need node.exe for production -- not npm, npx, etc.)
  5. Rename it to node.exe if needed.

Or simply download just node.exe:
  https://nodejs.org/dist/latest-v22.x/win-x64/node.exe

The install-services.ps1 script looks for:
  runtime\node\node.exe

If node.exe is not found here, it falls back to system PATH.
Note: Do NOT commit node.exe to git. Add runtime-cache/ to .gitignore.
