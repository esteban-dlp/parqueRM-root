PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   005_add_platform_data_reset_permission.sql
   Agrega el permiso PLATFORM_DATA_RESET y lo asigna al rol
   Administrador en instalaciones existentes.

   IMPORTANTE: No ejecutar si la migración ya está registrada
   en schema_migrations. El script de docker-compose y el
   instalador verifican eso antes de correr este archivo.

   Manual usage on an existing deployment:
     sqlite3 /path/to/parquerm.db < 005_add_platform_data_reset_permission.sql
   ============================================================ */

BEGIN TRANSACTION;

INSERT INTO schema_migrations (migration_name)
VALUES ('005_add_platform_data_reset_permission');

INSERT OR IGNORE INTO permissions (code, name, module, description)
VALUES ('PLATFORM_DATA_RESET', 'Eliminar datos de la plataforma', 'Sistema',
        'Permite ejecutar el borrado masivo de datos operativos ingresados manualmente');

INSERT OR IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Administrador'
  AND p.code = 'PLATFORM_DATA_RESET';

COMMIT;
