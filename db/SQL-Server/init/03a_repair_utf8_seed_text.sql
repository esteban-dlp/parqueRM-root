USE ParqueRM;
GO

/* ============================================================
   03a_repair_utf8_seed_text.sql
   Repara textos semilla que pudieron insertarse con UTF-8 leido
   como ANSI/Windows-1252 por sqlcmd (ej: "ó" -> "Ã³").
   Debe correr antes de catalogos/tarifas para evitar duplicados.
   ============================================================ */

SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.roles', N'U') IS NOT NULL
BEGIN
    UPDATE dbo.roles
    SET description = N'Acceso total al sistema'
    WHERE name = N'Administrador';

    UPDATE dbo.roles
    SET description = N'Puede registrar visitantes, vehículos, hospedaje, cobros y operaciones del día'
    WHERE name = N'Operador de caja';

    UPDATE dbo.roles
    SET description = N'Solo lectura para consultas y reportes'
    WHERE name = N'Consulta';
END
GO

IF OBJECT_ID(N'dbo.permissions', N'U') IS NOT NULL
BEGIN
    DECLARE @permissions TABLE (
        code NVARCHAR(100) PRIMARY KEY,
        name NVARCHAR(150) NOT NULL,
        module NVARCHAR(100) NOT NULL,
        description NVARCHAR(255) NULL
    );

    INSERT INTO @permissions (code, name, module, description)
    VALUES
        (N'VISITANTES_CREATE', N'Crear visitantes', N'Visitantes', N'Permite registrar visitantes'),
        (N'VISITANTES_READ', N'Ver visitantes', N'Visitantes', N'Permite consultar registros de visitantes'),
        (N'VISITANTES_UPDATE', N'Editar visitantes', N'Visitantes', N'Permite actualizar registros de visitantes'),
        (N'VISITANTES_CHECKOUT', N'Registrar salida de visitantes', N'Visitantes', N'Permite registrar egreso de visitantes'),
        (N'VEHICULOS_CREATE', N'Crear vehículos', N'Vehículos', N'Permite registrar vehículos'),
        (N'VEHICULOS_READ', N'Ver vehículos', N'Vehículos', N'Permite consultar vehículos'),
        (N'VEHICULOS_UPDATE', N'Editar vehículos', N'Vehículos', N'Permite actualizar registros de vehículos'),
        (N'VEHICULOS_ENABLE_EXIT', N'Habilitar salida de vehículos', N'Vehículos', N'Permite marcar vehículos como habilitados para salir'),
        (N'HOSPEDAJE_CREATE', N'Crear hospedaje', N'Hospedaje', N'Permite registrar cobros de hospedaje'),
        (N'HOSPEDAJE_READ', N'Ver hospedaje', N'Hospedaje', N'Permite consultar registros de hospedaje'),
        (N'RECEIPTS_CREATE', N'Crear recibos', N'Recibos', N'Permite emitir recibos'),
        (N'RECEIPTS_READ', N'Ver recibos', N'Recibos', N'Permite consultar recibos'),
        (N'RECEIPTS_CANCEL', N'Anular recibos', N'Recibos', N'Permite anular recibos'),
        (N'RECEIPTS_PRINT', N'Imprimir recibos', N'Recibos', N'Permite imprimir recibos'),
        (N'CAJA_CREATE_MOVEMENT', N'Crear movimientos de caja', N'Caja', N'Permite registrar ingresos y egresos'),
        (N'CAJA_READ', N'Ver caja', N'Caja', N'Permite consultar caja y movimientos financieros'),
        (N'CAJA_CLOSE', N'Cerrar caja', N'Caja', N'Permite realizar cierre de caja'),
        (N'CAJA_CANCEL_MOVEMENT', N'Anular movimientos de caja', N'Caja', N'Permite anular movimientos financieros'),
        (N'REPORTES_READ', N'Ver reportes', N'Reportes', N'Permite consultar reportes'),
        (N'REPORTES_EXPORT', N'Exportar reportes', N'Reportes', N'Permite exportar reportes a Excel o PDF'),
        (N'CONFIG_READ', N'Ver configuración', N'Configuración', N'Permite consultar configuración del parque'),
        (N'CONFIG_UPDATE', N'Editar configuración', N'Configuración', N'Permite modificar configuración general del parque'),
        (N'CATALOGS_READ', N'Ver catálogos', N'Catálogos', N'Permite consultar catálogos del sistema'),
        (N'CATALOGS_MANAGE', N'Administrar catálogos', N'Catálogos', N'Permite crear, editar y desactivar catálogos'),
        (N'USERS_READ', N'Ver usuarios', N'Usuarios', N'Permite consultar usuarios del sistema'),
        (N'USERS_MANAGE', N'Administrar usuarios', N'Usuarios', N'Permite crear, editar y desactivar usuarios'),
        (N'ROLES_READ', N'Ver roles', N'Roles', N'Permite consultar roles y permisos'),
        (N'ROLES_MANAGE', N'Administrar roles', N'Roles', N'Permite modificar roles y permisos'),
        (N'AUDIT_READ', N'Ver auditoría', N'Auditoría', N'Permite consultar bitácora de auditoría'),
        (N'TARIFF_OVERRIDE', N'Sobreescribir tarifa', N'Tarifas', N'Permite modificar manualmente el monto de tarifa aplicada en registros operativos');

    UPDATE p
    SET p.name = f.name,
        p.module = f.module,
        p.description = f.description
    FROM dbo.permissions p
    INNER JOIN @permissions f ON f.code = p.code;
END
GO

IF OBJECT_ID(N'dbo.visitor_categories', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.visitor_categories WHERE name = N'NiÃ±o')
       AND NOT EXISTS (SELECT 1 FROM dbo.visitor_categories WHERE name = N'Niño')
        UPDATE dbo.visitor_categories SET name = N'Niño' WHERE name = N'NiÃ±o';

    IF EXISTS (SELECT 1 FROM dbo.visitor_categories WHERE name = N'GuÃ­a')
       AND NOT EXISTS (SELECT 1 FROM dbo.visitor_categories WHERE name = N'Guía')
        UPDATE dbo.visitor_categories SET name = N'Guía' WHERE name = N'GuÃ­a';
END
GO

IF OBJECT_ID(N'dbo.vehicle_types', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.vehicle_types WHERE name = N'AutomÃ³vil')
       AND NOT EXISTS (SELECT 1 FROM dbo.vehicle_types WHERE name = N'Automóvil')
        UPDATE dbo.vehicle_types SET name = N'Automóvil' WHERE name = N'AutomÃ³vil';

    IF EXISTS (SELECT 1 FROM dbo.vehicle_types WHERE name = N'MicrobÃºs')
       AND NOT EXISTS (SELECT 1 FROM dbo.vehicle_types WHERE name = N'Microbús')
        UPDATE dbo.vehicle_types SET name = N'Microbús' WHERE name = N'MicrobÃºs';

    IF EXISTS (SELECT 1 FROM dbo.vehicle_types WHERE name = N'AutobÃºs')
       AND NOT EXISTS (SELECT 1 FROM dbo.vehicle_types WHERE name = N'Autobús')
        UPDATE dbo.vehicle_types SET name = N'Autobús' WHERE name = N'AutobÃºs';
END
GO

IF OBJECT_ID(N'dbo.lodging_types', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.lodging_types WHERE name = N'CabaÃ±a')
       AND NOT EXISTS (SELECT 1 FROM dbo.lodging_types WHERE name = N'Cabaña')
        UPDATE dbo.lodging_types SET name = N'Cabaña' WHERE name = N'CabaÃ±a';

    IF EXISTS (SELECT 1 FROM dbo.lodging_types WHERE name = N'HabitaciÃ³n doble')
       AND NOT EXISTS (SELECT 1 FROM dbo.lodging_types WHERE name = N'Habitación doble')
        UPDATE dbo.lodging_types SET name = N'Habitación doble' WHERE name = N'HabitaciÃ³n doble';
END
GO

IF OBJECT_ID(N'dbo.financial_concepts', N'U') IS NOT NULL
BEGIN
    UPDATE dbo.financial_concepts SET name = N'Ingreso por vehículo' WHERE name = N'Ingreso por vehÃ­culo';
END
GO

IF OBJECT_ID(N'dbo.visit_reasons', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.visit_reasons WHERE name = N'RecreaciÃ³n')
       AND NOT EXISTS (SELECT 1 FROM dbo.visit_reasons WHERE name = N'Recreación')
        UPDATE dbo.visit_reasons SET name = N'Recreación' WHERE name = N'RecreaciÃ³n';

    IF EXISTS (SELECT 1 FROM dbo.visit_reasons WHERE name = N'ArqueologÃ­a')
       AND NOT EXISTS (SELECT 1 FROM dbo.visit_reasons WHERE name = N'Arqueología')
        UPDATE dbo.visit_reasons SET name = N'Arqueología' WHERE name = N'ArqueologÃ­a';

    IF EXISTS (SELECT 1 FROM dbo.visit_reasons WHERE name = N'InvestigaciÃ³n')
       AND NOT EXISTS (SELECT 1 FROM dbo.visit_reasons WHERE name = N'Investigación')
        UPDATE dbo.visit_reasons SET name = N'Investigación' WHERE name = N'InvestigaciÃ³n';
END
GO

IF OBJECT_ID(N'dbo.visit_activities', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.visit_activities WHERE name = N'ObservaciÃ³n de aves')
       AND NOT EXISTS (SELECT 1 FROM dbo.visit_activities WHERE name = N'Observación de aves')
        UPDATE dbo.visit_activities SET name = N'Observación de aves' WHERE name = N'ObservaciÃ³n de aves';
END
GO

IF OBJECT_ID(N'dbo.info_sources', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.info_sources WHERE name = N'RecomendaciÃ³n')
       AND NOT EXISTS (SELECT 1 FROM dbo.info_sources WHERE name = N'Recomendación')
        UPDATE dbo.info_sources SET name = N'Recomendación' WHERE name = N'RecomendaciÃ³n';

    IF EXISTS (SELECT 1 FROM dbo.info_sources WHERE name = N'GuÃ­a impresa')
       AND NOT EXISTS (SELECT 1 FROM dbo.info_sources WHERE name = N'Guía impresa')
        UPDATE dbo.info_sources SET name = N'Guía impresa' WHERE name = N'GuÃ­a impresa';
END
GO

IF OBJECT_ID(N'dbo.countries', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.countries WHERE name = N'MÃ©xico')
       AND NOT EXISTS (SELECT 1 FROM dbo.countries WHERE name = N'México')
        UPDATE dbo.countries SET name = N'México' WHERE name = N'MÃ©xico';

    UPDATE dbo.countries SET nationality = N'Mexicana' WHERE name = N'México';
    UPDATE dbo.countries SET nationality = N'Salvadoreña' WHERE name = N'El Salvador';
    UPDATE dbo.countries SET nationality = N'Hondureña' WHERE name = N'Honduras';
END
GO

IF OBJECT_ID(N'dbo.departments', N'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'PetÃ©n')
       AND NOT EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'Petén')
        UPDATE dbo.departments SET name = N'Petén' WHERE name = N'PetÃ©n';

    IF EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'QuichÃ©')
       AND NOT EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'Quiché')
        UPDATE dbo.departments SET name = N'Quiché' WHERE name = N'QuichÃ©';

    IF EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'SacatepÃ©quez')
       AND NOT EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'Sacatepéquez')
        UPDATE dbo.departments SET name = N'Sacatepéquez' WHERE name = N'SacatepÃ©quez';

    IF EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'SololÃ¡')
       AND NOT EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'Sololá')
        UPDATE dbo.departments SET name = N'Sololá' WHERE name = N'SololÃ¡';

    IF EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'SuchitepÃ©quez')
       AND NOT EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'Suchitepéquez')
        UPDATE dbo.departments SET name = N'Suchitepéquez' WHERE name = N'SuchitepÃ©quez';

    IF EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'TotonicapÃ¡n')
       AND NOT EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'Totonicapán')
        UPDATE dbo.departments SET name = N'Totonicapán' WHERE name = N'TotonicapÃ¡n';
END
GO

IF OBJECT_ID(N'dbo.tariffs', N'U') IS NOT NULL
BEGIN
    UPDATE dbo.tariffs SET name = N'Niño' WHERE name = N'NiÃ±o';
    UPDATE dbo.tariffs SET name = N'Guía' WHERE name = N'GuÃ­a';
    UPDATE dbo.tariffs SET name = N'Automóvil' WHERE name = N'AutomÃ³vil';
    UPDATE dbo.tariffs SET name = N'Microbús' WHERE name = N'MicrobÃºs';
    UPDATE dbo.tariffs SET name = N'Autobús' WHERE name = N'AutobÃºs';
    UPDATE dbo.tariffs SET name = N'Otro vehículo' WHERE name = N'Otro vehÃ­culo';
    UPDATE dbo.tariffs SET name = N'Cabaña' WHERE name = N'CabaÃ±a';
    UPDATE dbo.tariffs SET name = N'Habitación doble' WHERE name = N'HabitaciÃ³n doble';
END
GO

IF OBJECT_ID(N'dbo.park_config', N'U') IS NOT NULL
BEGIN
    UPDATE dbo.park_config
    SET address = N'Dirección pendiente de configurar'
    WHERE address = N'DirecciÃ³n pendiente de configurar';
END
GO

PRINT '03a_repair_utf8_seed_text.sql ejecutado correctamente.';
GO
