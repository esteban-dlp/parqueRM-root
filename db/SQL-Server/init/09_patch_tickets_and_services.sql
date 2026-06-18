USE ParqueRM;
GO

/* ============================================================
   09_patch_tickets_and_services.sql
   Patches idempotentes:
     - park_config: agrega ticket_version y ruv
     - services: habilita por defecto un servicio "Camping"
                 y otros servicios generales útiles
     - tariffs: relaja CHECK applies_to para permitir 'SERVICIO'
     - financial_concepts: agrega conceptos de servicio (camping,
       guía, alquiler de equipo, leña, donación)
   ============================================================ */

SET NOCOUNT ON;
GO

/* =========================
   park_config: ticket_version + ruv
   ========================= */

IF COL_LENGTH('dbo.park_config', 'ticket_version') IS NULL
BEGIN
    ALTER TABLE dbo.park_config
        ADD ticket_version NVARCHAR(50) NULL;
    PRINT 'Columna park_config.ticket_version agregada.';
END
GO

IF COL_LENGTH('dbo.park_config', 'ruv') IS NULL
BEGIN
    ALTER TABLE dbo.park_config
        ADD ruv NVARCHAR(80) NULL;
    PRINT 'Columna park_config.ruv agregada.';
END
GO

-- Inicializa valores por defecto si están en NULL
UPDATE dbo.park_config
SET ticket_version = ISNULL(ticket_version, 'v1.0'),
    ruv            = ISNULL(ruv, 'PENDIENTE');
GO


/* =========================
   tariffs: permitir applies_to = 'SERVICIO'
   ========================= */

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'ck_tariffs_applies_to'
      AND parent_object_id = OBJECT_ID('dbo.tariffs')
)
BEGIN
    ALTER TABLE dbo.tariffs DROP CONSTRAINT ck_tariffs_applies_to;
    PRINT 'Constraint ck_tariffs_applies_to anterior eliminada.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'ck_tariffs_applies_to'
      AND parent_object_id = OBJECT_ID('dbo.tariffs')
)
BEGIN
    ALTER TABLE dbo.tariffs
        ADD CONSTRAINT ck_tariffs_applies_to CHECK (
            applies_to IN ('VISITANTE', 'VEHICULO', 'HOSPEDAJE', 'SERVICIO')
        );
    PRINT 'Constraint ck_tariffs_applies_to (con SERVICIO) creada.';
END
GO


/* =========================
   services: catálogo de servicios "vendibles"
   ========================= */

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'CAMPING')
BEGIN
    INSERT INTO services (code, name, is_enabled) VALUES ('CAMPING', 'Camping', 1);
END
GO

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'GUIA')
BEGIN
    INSERT INTO services (code, name, is_enabled) VALUES ('GUIA', 'Guía turístico', 1);
END
GO

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'LENA')
BEGIN
    INSERT INTO services (code, name, is_enabled) VALUES ('LENA', 'Venta de leña', 1);
END
GO

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'SERVICIO_GENERAL')
BEGIN
    INSERT INTO services (code, name, is_enabled) VALUES ('SERVICIO_GENERAL', 'Servicio general', 1);
END
GO


/* =========================
   financial_concepts: ingresos por servicios extra
   ========================= */

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Camping')
BEGIN
    INSERT INTO financial_concepts (type, name) VALUES ('INGRESO', 'Camping');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Guía turístico')
BEGIN
    INSERT INTO financial_concepts (type, name) VALUES ('INGRESO', 'Guía turístico');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Venta de leña')
BEGIN
    INSERT INTO financial_concepts (type, name) VALUES ('INGRESO', 'Venta de leña');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Alquiler de equipo')
BEGIN
    INSERT INTO financial_concepts (type, name) VALUES ('INGRESO', 'Alquiler de equipo');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Donación')
BEGIN
    INSERT INTO financial_concepts (type, name) VALUES ('INGRESO', 'Donación');
END
GO


/* =========================
   tarifas iniciales para los nuevos servicios
   ========================= */

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    WHERE s.code = 'CAMPING' AND t.applies_to = 'SERVICIO'
)
BEGIN
    INSERT INTO tariffs (service_id, name, applies_to, amount_local, amount_foreign)
    SELECT s.id, 'Camping (noche)', 'SERVICIO', 25.00, 50.00
    FROM services s
    WHERE s.code = 'CAMPING';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    WHERE s.code = 'GUIA' AND t.applies_to = 'SERVICIO'
)
BEGIN
    INSERT INTO tariffs (service_id, name, applies_to, amount_local, amount_foreign)
    SELECT s.id, 'Guía turístico', 'SERVICIO', 100.00, 150.00
    FROM services s
    WHERE s.code = 'GUIA';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    WHERE s.code = 'LENA' AND t.applies_to = 'SERVICIO'
)
BEGIN
    INSERT INTO tariffs (service_id, name, applies_to, amount_local, amount_foreign)
    SELECT s.id, 'Atado de leña', 'SERVICIO', 15.00, 15.00
    FROM services s
    WHERE s.code = 'LENA';
END
GO


/* =========================
   helper view: ticket lines (used by reports & exports)
   ========================= */

IF OBJECT_ID('dbo.vw_ticket_lines', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ticket_lines;
GO

CREATE VIEW dbo.vw_ticket_lines AS
SELECT
    r.id              AS receipt_id,
    r.receipt_number  AS ticket_number,
    r.receipt_date,
    r.origin_type,
    r.origin_id,
    r.contributor_name,
    r.status,
    pm.name           AS payment_method,
    u.full_name       AS issued_by,
    rl.id             AS line_id,
    rl.description    AS line_description,
    rl.quantity       AS line_quantity,
    rl.unit_price     AS line_unit_price,
    rl.total          AS line_total,
    r.subtotal,
    r.discount_amount,
    r.total           AS ticket_total
FROM receipts r
LEFT JOIN receipt_lines  rl ON rl.receipt_id = r.id
LEFT JOIN payment_methods pm ON pm.id = r.payment_method_id
LEFT JOIN users u            ON u.id = r.created_by_user_id;
GO


/* =========================
   helper view: visitor lines (visitante principal + acompañantes)
   ========================= */

IF OBJECT_ID('dbo.vw_visitor_lines', 'V') IS NOT NULL
    DROP VIEW dbo.vw_visitor_lines;
GO

CREATE VIEW dbo.vw_visitor_lines AS
SELECT
    vr.id                    AS visitor_id,
    vr.ticket_number,
    vr.record_date,
    vr.check_in_at,
    vr.full_name,
    vr.is_foreign,
    CAST(0 AS BIT)           AS is_companion,
    vr.visitor_category_id   AS category_id,
    vc.name                  AS category_name,
    vr.quantity,
    vr.applied_rate          AS unit_price,
    vr.total_amount          AS line_total
FROM visitor_records vr
INNER JOIN visitor_categories vc ON vc.id = vr.visitor_category_id
UNION ALL
SELECT
    vr.id                    AS visitor_id,
    vr.ticket_number,
    vr.record_date,
    vr.check_in_at,
    vr.full_name,
    vrc.is_foreign,
    CAST(1 AS BIT)           AS is_companion,
    vrc.visitor_category_id  AS category_id,
    vc.name                  AS category_name,
    vrc.quantity,
    vrc.applied_rate         AS unit_price,
    vrc.total_amount         AS line_total
FROM visitor_record_companions vrc
INNER JOIN visitor_records vr ON vr.id = vrc.visitor_record_id
INNER JOIN visitor_categories vc ON vc.id = vrc.visitor_category_id;
GO

PRINT '09_patch_tickets_and_services.sql ejecutado correctamente.';
GO
