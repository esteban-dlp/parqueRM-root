USE ParqueRM;
GO

/* ============================================================
   03_seed_security.sql
   Roles, permisos y asignación de permisos por rol
   SQL Server
   ============================================================ */

SET NOCOUNT ON;
GO

/* =========================
   ROLES
   ========================= */

IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'Administrador')
BEGIN
    INSERT INTO roles (name, description)
    VALUES ('Administrador', 'Acceso total al sistema');
END
GO

IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'Operador de caja')
BEGIN
    INSERT INTO roles (name, description)
    VALUES ('Operador de caja', 'Puede registrar visitantes, vehículos, hospedaje, cobros y operaciones del día');
END
GO

IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'Consulta')
BEGIN
    INSERT INTO roles (name, description)
    VALUES ('Consulta', 'Solo lectura para consultas y reportes');
END
GO


/* =========================
   PERMISOS
   ========================= */

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'VISITANTES_CREATE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('VISITANTES_CREATE', 'Crear visitantes', 'Visitantes', 'Permite registrar visitantes');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'VISITANTES_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('VISITANTES_READ', 'Ver visitantes', 'Visitantes', 'Permite consultar registros de visitantes');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'VISITANTES_UPDATE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('VISITANTES_UPDATE', 'Editar visitantes', 'Visitantes', 'Permite actualizar registros de visitantes');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'VISITANTES_CHECKOUT')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('VISITANTES_CHECKOUT', 'Registrar salida de visitantes', 'Visitantes', 'Permite registrar egreso de visitantes');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'VEHICULOS_CREATE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('VEHICULOS_CREATE', 'Crear vehículos', 'Vehículos', 'Permite registrar vehículos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'VEHICULOS_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('VEHICULOS_READ', 'Ver vehículos', 'Vehículos', 'Permite consultar vehículos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'VEHICULOS_UPDATE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('VEHICULOS_UPDATE', 'Editar vehículos', 'Vehículos', 'Permite actualizar registros de vehículos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'VEHICULOS_ENABLE_EXIT')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('VEHICULOS_ENABLE_EXIT', 'Habilitar salida de vehículos', 'Vehículos', 'Permite marcar vehículos como habilitados para salir');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'HOSPEDAJE_CREATE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('HOSPEDAJE_CREATE', 'Crear hospedaje', 'Hospedaje', 'Permite registrar cobros de hospedaje');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'HOSPEDAJE_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('HOSPEDAJE_READ', 'Ver hospedaje', 'Hospedaje', 'Permite consultar registros de hospedaje');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'RECEIPTS_CREATE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('RECEIPTS_CREATE', 'Crear recibos', 'Recibos', 'Permite emitir recibos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'RECEIPTS_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('RECEIPTS_READ', 'Ver recibos', 'Recibos', 'Permite consultar recibos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'RECEIPTS_CANCEL')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('RECEIPTS_CANCEL', 'Anular recibos', 'Recibos', 'Permite anular recibos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'RECEIPTS_PRINT')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('RECEIPTS_PRINT', 'Imprimir recibos', 'Recibos', 'Permite imprimir recibos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'CAJA_CREATE_MOVEMENT')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('CAJA_CREATE_MOVEMENT', 'Crear movimientos de caja', 'Caja', 'Permite registrar ingresos y egresos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'CAJA_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('CAJA_READ', 'Ver caja', 'Caja', 'Permite consultar caja y movimientos financieros');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'CAJA_CLOSE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('CAJA_CLOSE', 'Cerrar caja', 'Caja', 'Permite realizar cierre de caja');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'CAJA_CANCEL_MOVEMENT')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('CAJA_CANCEL_MOVEMENT', 'Anular movimientos de caja', 'Caja', 'Permite anular movimientos financieros');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'REPORTES_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('REPORTES_READ', 'Ver reportes', 'Reportes', 'Permite consultar reportes');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'REPORTES_EXPORT')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('REPORTES_EXPORT', 'Exportar reportes', 'Reportes', 'Permite exportar reportes a Excel o PDF');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'CONFIG_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('CONFIG_READ', 'Ver configuración', 'Configuración', 'Permite consultar configuración del parque');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'CONFIG_UPDATE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('CONFIG_UPDATE', 'Editar configuración', 'Configuración', 'Permite modificar configuración general del parque');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'CATALOGS_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('CATALOGS_READ', 'Ver catálogos', 'Catálogos', 'Permite consultar catálogos del sistema');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'CATALOGS_MANAGE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('CATALOGS_MANAGE', 'Administrar catálogos', 'Catálogos', 'Permite crear, editar y desactivar catálogos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'USERS_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('USERS_READ', 'Ver usuarios', 'Usuarios', 'Permite consultar usuarios del sistema');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'USERS_MANAGE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('USERS_MANAGE', 'Administrar usuarios', 'Usuarios', 'Permite crear, editar y desactivar usuarios');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'ROLES_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('ROLES_READ', 'Ver roles', 'Roles', 'Permite consultar roles y permisos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'ROLES_MANAGE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('ROLES_MANAGE', 'Administrar roles', 'Roles', 'Permite modificar roles y permisos');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'AUDIT_READ')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('AUDIT_READ', 'Ver auditoría', 'Auditoría', 'Permite consultar bitácora de auditoría');
END
GO

IF NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'TARIFF_OVERRIDE')
BEGIN
    INSERT INTO permissions (code, name, module, description)
    VALUES ('TARIFF_OVERRIDE', 'Sobreescribir tarifa', 'Tarifas', 'Permite modificar manualmente el monto de tarifa aplicada en registros operativos');
END
GO


/* =========================
   ASIGNACIÓN: ADMINISTRADOR
   ========================= */

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Administrador'
  AND NOT EXISTS (
      SELECT 1
      FROM role_permissions rp
      WHERE rp.role_id = r.id
        AND rp.permission_id = p.id
  );
GO


/* =========================
   ASIGNACIÓN: OPERADOR DE CAJA
   ========================= */

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'VISITANTES_CREATE',
    'VISITANTES_READ',
    'VISITANTES_CHECKOUT',

    'VEHICULOS_CREATE',
    'VEHICULOS_READ',
    'VEHICULOS_ENABLE_EXIT',

    'HOSPEDAJE_CREATE',
    'HOSPEDAJE_READ',

    'RECEIPTS_CREATE',
    'RECEIPTS_READ',
    'RECEIPTS_PRINT',

    'CAJA_CREATE_MOVEMENT',
    'CAJA_READ',

    'REPORTES_READ',

    'CONFIG_READ',
    'CATALOGS_READ'
)
WHERE r.name = 'Operador de caja'
  AND NOT EXISTS (
      SELECT 1
      FROM role_permissions rp
      WHERE rp.role_id = r.id
        AND rp.permission_id = p.id
  );
GO


/* =========================
   ASIGNACIÓN: CONSULTA
   ========================= */

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'VISITANTES_READ',
    'VEHICULOS_READ',
    'HOSPEDAJE_READ',
    'RECEIPTS_READ',
    'CAJA_READ',
    'REPORTES_READ',
    'CONFIG_READ',
    'CATALOGS_READ'
)
WHERE r.name = 'Consulta'
  AND NOT EXISTS (
      SELECT 1
      FROM role_permissions rp
      WHERE rp.role_id = r.id
        AND rp.permission_id = p.id
  );
GO

PRINT '03_seed_security.sql ejecutado correctamente.';
GO

/* =========================
   USUARIOS
   ========================= */

IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = N'admin')
BEGIN
    INSERT INTO dbo.users
    (
        role_id,
        username,
        password_hash,
        full_name,
        email,
        is_active,
        last_login_at,
        created_at,
        updated_at
    )
    VALUES
    (
        1,
        N'admin',
        N'$2b$12$TXeaiaVB38WiRC.uZybYGOCVHtqKv6gzLRmCZEwcyuhHBH4iM6ZJu',
        N'Administrador del Sistema',
        N'admin@parquerm.local',
        1,
        NULL,
        SYSDATETIME(),
        SYSDATETIME()
    );
END
