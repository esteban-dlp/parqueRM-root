SQL Server Express -- Offline Installer
=======================================

Place the SQL Server Express offline installer in this folder.

Expected filename: SQLEXPR_x64_ENU.exe
   (or similar: SQLEXPR_x64_ESP.exe, SQLEXPR2022_x64_ENU.exe, etc.)

Download from:
  https://www.microsoft.com/en-us/sql-server/sql-server-downloads

Steps:
  1. Go to the URL above.
  2. Select the "Express" edition.
  3. Choose "Download Media" (not "Basic" or "Custom").
  4. Select "Express" package type.
  5. Download the .exe file.
  6. Place it in this folder.

The installer will run with these options:
  /Q /ACTION=Install /FEATURES=SQLEngine
  /INSTANCENAME=MSSQLSERVER
  /SECURITYMODE=SQL /SAPWD=<from installer wizard>
  /TCPENABLED=1
  /IACCEPTSQLSERVERLICENSETERMS

Note: SQL Server Express is free for use under Microsoft's license.
Note: Do NOT commit this file to git (it is ~700 MB).
      Add runtime-cache/ to .gitignore and distribute out-of-band.
