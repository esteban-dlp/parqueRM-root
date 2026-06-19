PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   003_add_survey_permissions.sql
   Registers SURVEYS_* permissions and grants them to existing roles
   on an already initialized database. Safe to run multiple times.
   Run 002_add_survey_tables.sql first if the survey tables don't exist yet.

   Manual usage on an existing deployment:
     sqlite3 /path/to/parquerm.db < 003_add_survey_permissions.sql
   ============================================================ */

BEGIN TRANSACTION;

INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('SURVEYS_CONFIG_READ', 'Ver preguntas de encuesta', 'Encuestas', 'Permite consultar las preguntas configuradas de la encuesta de satisfacción');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('SURVEYS_CONFIG_MANAGE', 'Administrar preguntas de encuesta', 'Encuestas', 'Permite crear, editar, activar/desactivar y reordenar preguntas de encuesta');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('SURVEYS_REPORT_READ', 'Ver reporte de encuestas', 'Encuestas', 'Permite consultar el reporte agregado de respuestas de encuesta');

INSERT OR IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Administrador'
  AND p.code IN ('SURVEYS_CONFIG_READ', 'SURVEYS_CONFIG_MANAGE', 'SURVEYS_REPORT_READ');

INSERT OR IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'SURVEYS_REPORT_READ'
WHERE r.name = 'Consulta';

COMMIT;
