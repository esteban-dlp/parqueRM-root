# ParqueRM Root

## Qué es este repo
Orquesta frontend, backend y SQL Server usando Docker Compose.

## Estructura
- parqueRM-frontend
- parqueRM-backend
- parqueRM-root

## Requisitos
- Docker Desktop
- Git
- Windows 10/11

## Cómo levantar
docker compose up -d --build

## Cómo apagar
docker compose down

## Cómo resetear DB
docker compose down -v
docker compose up -d --build

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