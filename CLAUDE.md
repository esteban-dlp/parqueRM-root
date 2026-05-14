# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`parqueRM-root` is the infrastructure and orchestration layer for ParqueRM. It contains:
- `docker-compose.yml` — starts all four services (sqlserver, db-init, backend, frontend)
- `db/init/` — SQL Server initialization scripts, run once in order at first startup
- `docs/` — architecture diagrams and the authoritative permissions model
- `scripts/` — Windows `.bat` helpers (start, stop, reset-db)

The application code lives in sibling repos: `../parqueRM-backend/` (NestJS) and `../parqueRM-frontend/` (React).

## Docker commands (run from this directory)

```bash
docker compose up -d --build    # start everything, rebuild images
docker compose down             # stop all containers
docker compose down -v          # stop + delete DB volume (full reset)
docker compose logs -f backend  # tail backend logs
docker compose logs -f db-init  # check if init scripts ran correctly
```

Windows batch shortcuts: `scripts/start.bat`, `scripts/stop.bat`, `scripts/reset-db.bat`

## Database initialization

Scripts in `db/init/` run **once** in numeric order when the `db-init` container starts on a fresh volume:

| Script | Purpose |
|--------|---------|
| `01_create_database.sql` | Creates `ParqueRM` database (idempotent) |
| `02_schema.sql` | All 24 tables, indexes, FK constraints — **schema source of truth** |
| `03_seed_security.sql` | Roles, 30+ permissions, role_permissions, default `admin` user |
| `04_seed_catalogs.sql` | Countries, departments, visitor categories, vehicle types, etc. |
| `05_seed_tariffs.sql` | Initial tariff rates (visitors Q10–Q50, vehicles Q5–Q50, lodging Q75–Q200) |
| `06_seed_park_config.sql` | Park metadata (name, SIGAP code, capacity, location) |

All scripts are **idempotent** — they use `IF OBJECT_ID`, `IF NOT EXISTS`, and `IF NOT EXISTS (SELECT 1 FROM ...)` guards. Safe to re-run manually via SSMS.

To apply schema changes: edit `02_schema.sql`, then `docker compose down -v && docker compose up -d --build`. There is no migration system — the volume reset is the migration.

## Adding or changing permissions

`docs/permissions.md` is the **source of truth** for the RBAC model. When changing permissions:
1. Update `docs/permissions.md` with the new permission and which roles get it
2. Add the permission insert to `03_seed_security.sql`
3. Add role_permission rows to `03_seed_security.sql`
4. Reset the DB volume to re-seed (`docker compose down -v && docker compose up -d --build`)
5. Update the backend `@RequirePermissions()` decorators and frontend `PERMISSIONS` constants

Current permission naming convention: `MODULE_ACTION` (e.g., `VISITANTES_CREATE`, `CAJA_CLOSE`, `REPORTES_EXPORT`).

## Environment (.env)

```env
SQLSERVER_SA_PASSWORD=...          # Also used as DB_PASSWORD
JWT_SECRET=...
JWT_REFRESH_SECRET=...
VITE_API_URL=http://localhost:3000/api  # Change to LAN IP for park deployment
BACKEND_PORT=3000
FRONTEND_PORT=8080
DB_HOST=sqlserver                  # Docker service name, not localhost
DB_PORT=1433
DB_NAME=ParqueRM
```

For LAN deployment: set `VITE_API_URL=http://<server-ip>:3000/api` — this is baked into the frontend image at build time.

## Key schema design decisions

- **Polymorphic origin**: `receipts` and `financial_movements` use `origin_type` (VISITANTE, VEHICULO, HOSPEDAJE, SERVICIO_GENERAL) + `origin_id` instead of separate FK columns, to support multiple receipt sources from one table.
- **Source field**: visitor/vehicle records have `source IN ('MANUAL', 'MOLINETE', 'BARRERA')` for future hardware turnstile/barrier integration.
- **SICOIN fields**: `receipts` has `sicoin_reference` and `sicoin_error` for future Guatemala government accounting system integration.
- **Status workflow**: Receipts use `ACTIVO / ANULADO / PENDIENTE_SICOIN / ENVIADO_SICOIN`. Cash closures use `ABIERTO / CERRADO`. Cancelled or closed records must not be modified — enforce via backend audit logic.
- **Audit table**: `audit_logs` tracks user, action, entity, old/new JSON values, IP, and timestamp for all sensitive operations.

## Docs

- `docs/permissions.md` — full RBAC model, role capability lists, endpoint-to-permission mapping, frontend authorization patterns
- `docs/docker.md` — detailed deployment guide including SSMS connection, network deployment, service discovery explanation
- `docs/mermaid/architecture.mmd` — system architecture flowchart
- `docs/mermaid/database-er.md` — complete ER diagram for all 24 tables
