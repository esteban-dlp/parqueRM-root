PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* 03_seed_security.sql — SQLite version */
BEGIN TRANSACTION;
INSERT OR IGNORE INTO roles (name, description) VALUES ('Administrador', 'Acceso total al sistema');
INSERT OR IGNORE INTO roles (name, description) VALUES ('Operador de caja', 'Puede registrar visitantes, vehículos, hospedaje, cobros y operaciones del día');
INSERT OR IGNORE INTO roles (name, description) VALUES ('Consulta', 'Solo lectura para consultas y reportes');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('VISITANTES_CREATE', 'Crear visitantes', 'Visitantes', 'Permite registrar visitantes');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('VISITANTES_READ', 'Ver visitantes', 'Visitantes', 'Permite consultar registros de visitantes');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('VISITANTES_UPDATE', 'Editar visitantes', 'Visitantes', 'Permite actualizar registros de visitantes');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('VISITANTES_CHECKOUT', 'Registrar salida de visitantes', 'Visitantes', 'Permite registrar egreso de visitantes');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('VEHICULOS_CREATE', 'Crear vehículos', 'Vehículos', 'Permite registrar vehículos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('VEHICULOS_READ', 'Ver vehículos', 'Vehículos', 'Permite consultar vehículos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('VEHICULOS_UPDATE', 'Editar vehículos', 'Vehículos', 'Permite actualizar registros de vehículos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('VEHICULOS_ENABLE_EXIT', 'Habilitar salida de vehículos', 'Vehículos', 'Permite marcar vehículos como habilitados para salir');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('HOSPEDAJE_CREATE', 'Crear hospedaje', 'Hospedaje', 'Permite registrar cobros de hospedaje');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('HOSPEDAJE_READ', 'Ver hospedaje', 'Hospedaje', 'Permite consultar registros de hospedaje');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('RECEIPTS_CREATE', 'Crear recibos', 'Recibos', 'Permite emitir recibos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('RECEIPTS_READ', 'Ver recibos', 'Recibos', 'Permite consultar recibos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('RECEIPTS_CANCEL', 'Anular recibos', 'Recibos', 'Permite anular recibos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('RECEIPTS_PRINT', 'Imprimir recibos', 'Recibos', 'Permite imprimir recibos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('CAJA_CREATE_MOVEMENT', 'Crear movimientos de caja', 'Caja', 'Permite registrar ingresos y egresos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('CAJA_READ', 'Ver caja', 'Caja', 'Permite consultar caja y movimientos financieros');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('CAJA_CLOSE', 'Cerrar caja', 'Caja', 'Permite realizar cierre de caja');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('CAJA_CANCEL_MOVEMENT', 'Anular movimientos de caja', 'Caja', 'Permite anular movimientos financieros');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('REPORTES_READ', 'Ver reportes', 'Reportes', 'Permite consultar reportes');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('REPORTES_EXPORT', 'Exportar reportes', 'Reportes', 'Permite exportar reportes a Excel o PDF');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('CONFIG_READ', 'Ver configuración', 'Configuración', 'Permite consultar configuración del parque');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('CONFIG_UPDATE', 'Editar configuración', 'Configuración', 'Permite modificar configuración general del parque');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('CATALOGS_READ', 'Ver catálogos', 'Catálogos', 'Permite consultar catálogos del sistema');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('CATALOGS_MANAGE', 'Administrar catálogos', 'Catálogos', 'Permite crear, editar y desactivar catálogos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('USERS_READ', 'Ver usuarios', 'Usuarios', 'Permite consultar usuarios del sistema');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('USERS_MANAGE', 'Administrar usuarios', 'Usuarios', 'Permite crear, editar y desactivar usuarios');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('ROLES_READ', 'Ver roles', 'Roles', 'Permite consultar roles y permisos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('ROLES_MANAGE', 'Administrar roles', 'Roles', 'Permite modificar roles y permisos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('AUDIT_READ', 'Ver auditoría', 'Auditoría', 'Permite consultar bitácora de auditoría');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('TARIFF_OVERRIDE', 'Sobreescribir tarifa', 'Tarifas', 'Permite modificar manualmente el monto de tarifa aplicada en registros operativos');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('SURVEYS_CONFIG_READ', 'Ver preguntas de encuesta', 'Encuestas', 'Permite consultar las preguntas configuradas de la encuesta de satisfacción');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('SURVEYS_CONFIG_MANAGE', 'Administrar preguntas de encuesta', 'Encuestas', 'Permite crear, editar, activar/desactivar y reordenar preguntas de encuesta');
INSERT OR IGNORE INTO permissions (code, name, module, description) VALUES ('SURVEYS_REPORT_READ', 'Ver reporte de encuestas', 'Encuestas', 'Permite consultar el reporte agregado de respuestas de encuesta');

INSERT OR IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Administrador';


INSERT OR IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN ('VISITANTES_CREATE', 'VISITANTES_READ', 'VISITANTES_CHECKOUT', 'VEHICULOS_CREATE', 'VEHICULOS_READ', 'VEHICULOS_ENABLE_EXIT', 'HOSPEDAJE_CREATE', 'HOSPEDAJE_READ', 'RECEIPTS_CREATE', 'RECEIPTS_READ', 'RECEIPTS_PRINT', 'CAJA_CREATE_MOVEMENT', 'CAJA_READ', 'REPORTES_READ', 'CONFIG_READ', 'CATALOGS_READ')
WHERE r.name = 'Operador de caja';


INSERT OR IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN ('VISITANTES_READ', 'VEHICULOS_READ', 'HOSPEDAJE_READ', 'RECEIPTS_READ', 'CAJA_READ', 'REPORTES_READ', 'CONFIG_READ', 'CATALOGS_READ', 'SURVEYS_REPORT_READ')
WHERE r.name = 'Consulta';


INSERT OR IGNORE INTO users (
    role_id, username, password_hash, full_name, email, is_active, last_login_at, created_at, updated_at
)
SELECT
    (SELECT id FROM roles WHERE name = 'Administrador'),
    'admin',
    '$2b$12$TXeaiaVB38WiRC.uZybYGOCVHtqKv6gzLRmCZEwcyuhHBH4iM6ZJu',
    'Administrador del Sistema',
    'admin@parquerm.local',
    1,
    NULL,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');
COMMIT;
