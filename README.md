# ParqueRM Root

## Que es este repo
Orquesta frontend, backend y SQL Server usando Docker Compose.

## Estructura
- parqueRM-frontend
- parqueRM-backend
- parqueRM-root

## Requisitos
- Docker Desktop
- Git
- Windows 10/11

## Como levantar
scripts\start.bat

El script detecta la IP LAN del servidor y escribe `SYSTEM_LAN_URL` en `.env`.
Docker usa ese valor para llenar `park_config.system_lan_url`; si no existe,
usa el fallback `http://192.168.1.10`.

## Como apagar
docker compose down

## Como resetear DB
scripts\reset-db.bat

## URLs
Frontend: http://localhost
Backend: http://localhost:3000/api
SQL Server: localhost,1433

## Scripts de base de datos
01_create_database.sql
02_schema.sql
03_seed_security.sql
04_seed_catalogs.sql
05_seed_tariffs.sql
06_seed_park_config.sql
07_seed_demo_data.sql
08_patch_park_config_sidebar_color_hex.sql
09_patch_tickets_and_services.sql
