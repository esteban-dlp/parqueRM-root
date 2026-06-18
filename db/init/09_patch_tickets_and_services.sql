PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* 09_patch_tickets_and_services.sql — SQLite version */
BEGIN TRANSACTION;

UPDATE park_config
SET ticket_version = COALESCE(ticket_version, 'v1.0'),
    ruv = COALESCE(ruv, 'PENDIENTE');

INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('CAMPING', 'Camping', 1);
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('GUIA', 'Guía turístico', 1);
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('LENA', 'Venta de leña', 1);
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('SERVICIO_GENERAL', 'Servicio general', 1);

INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Camping');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Guía turístico');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Venta de leña');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Alquiler de equipo');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Donación');

INSERT INTO tariffs (service_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, 'Camping (noche)', 'SERVICIO', 25.00, 50.00
FROM services s
WHERE s.code = 'CAMPING'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.applies_to = 'SERVICIO');

INSERT INTO tariffs (service_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, 'Guía turístico', 'SERVICIO', 100.00, 150.00
FROM services s
WHERE s.code = 'GUIA'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.applies_to = 'SERVICIO');

INSERT INTO tariffs (service_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, 'Atado de leña', 'SERVICIO', 15.00, 15.00
FROM services s
WHERE s.code = 'LENA'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.applies_to = 'SERVICIO');

COMMIT;

DROP VIEW IF EXISTS vw_ticket_lines;
CREATE VIEW vw_ticket_lines AS
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

DROP VIEW IF EXISTS vw_visitor_lines;
CREATE VIEW vw_visitor_lines AS
SELECT
    vr.id                    AS visitor_id,
    vr.ticket_number,
    vr.record_date,
    vr.check_in_at,
    vr.full_name,
    vr.is_foreign,
    0                        AS is_companion,
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
    1                        AS is_companion,
    vrc.visitor_category_id  AS category_id,
    vc.name                  AS category_name,
    vrc.quantity,
    vrc.applied_rate         AS unit_price,
    vrc.total_amount         AS line_total
FROM visitor_record_companions vrc
INNER JOIN visitor_records vr ON vr.id = vrc.visitor_record_id
INNER JOIN visitor_categories vc ON vc.id = vrc.visitor_category_id;
