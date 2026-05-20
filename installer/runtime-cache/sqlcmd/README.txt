sqlcmd -- SQL Server Command Line Tool (Optional)
==================================================

This folder is OPTIONAL. sqlcmd.exe may be placed here for offline use.

If SQL Server is installed with default tools, sqlcmd.exe is usually found at:
  C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe
  C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe

The scripts (initialize-db.ps1, run-migrations.ps1) search for
sqlcmd in this priority order:
  1. C:\ParqueRM\runtime\sqlcmd\sqlcmd.exe    (this folder after install)
  2. PATH (system-wide sqlcmd)
  3. Common SQL Server install paths

If you want to bundle sqlcmd.exe in the installer, obtain it from:
  https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility

The sqlcmd.exe standalone binary is available in:
  Microsoft ODBC Driver for SQL Server
  SQL Server Command Line Tools (go-sqlcmd)

For go-sqlcmd (modern replacement):
  https://github.com/microsoft/go-sqlcmd/releases
  Download: sqlcmd-windows-amd64.zip or sqlcmd-v1.x.x-windows-x86_64.zip
  Extract sqlcmd.exe and place it here.
  Note: go-sqlcmd uses slightly different syntax -- verify compatibility.

In practice, if you install SQL Server Express, sqlcmd.exe is installed
automatically and found on PATH. This folder is only needed for machines
where SQL Server was installed without the command-line tools.
