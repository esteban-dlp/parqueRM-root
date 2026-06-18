PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* 07_seed_demo_data.sql — SQLite version */
BEGIN TRANSACTION;

/* VISITANTE 1: activo, sin recibo */
INSERT INTO visitor_records (
    ticket_number, record_date, check_in_at,
    country_id, department_id, municipality_id,
    travel_type_id, info_source_id,
    visitor_category_id, quantity, tariff_id, applied_rate, total_amount,
    gender, source, created_by_user_id
)
SELECT
    'TKT-DEMO-001', date('now','-6 hours'), datetime('now','-6 hours'),
    (SELECT id FROM countries WHERE name = 'Guatemala'),
    (SELECT id FROM departments WHERE name = 'San Marcos'),
    (SELECT id FROM municipalities WHERE name = 'San Rafael Pie de la Cuesta'),
    (SELECT id FROM travel_types WHERE name = 'En familia'),
    (SELECT id FROM info_sources WHERE name = 'Internet'),
    (SELECT id FROM visitor_categories WHERE name = 'Adulto'),
    2,
    (SELECT id FROM tariffs WHERE name = 'Adulto' AND applies_to = 'VISITANTE' AND is_active = 1 LIMIT 1),
    20.00, 40.00,
    'FEMENINO', 'MANUAL',
    (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM visitor_records WHERE ticket_number = 'TKT-DEMO-001');

INSERT OR IGNORE INTO visitor_record_reasons (visitor_record_id, visit_reason_id)
SELECT vr.id, r.id FROM visitor_records vr JOIN visit_reasons r ON r.name IN ('Naturaleza', 'Recreación') WHERE vr.ticket_number = 'TKT-DEMO-001';
INSERT OR IGNORE INTO visitor_record_activities (visitor_record_id, visit_activity_id)
SELECT vr.id, a.id FROM visitor_records vr JOIN visit_activities a ON a.name IN ('Caminata / trekking', 'Observación de aves') WHERE vr.ticket_number = 'TKT-DEMO-001';

/* VISITANTE 2: completado + recibo */
INSERT INTO visitor_records (
    ticket_number, record_date, check_in_at, check_out_at,
    country_id, department_id, municipality_id,
    travel_type_id, info_source_id,
    visitor_category_id, quantity, tariff_id, applied_rate, total_amount,
    source, created_by_user_id
)
SELECT
    'TKT-DEMO-002', date('now','-1 day','-6 hours'), datetime('now','-25 hours'), datetime('now','-19 hours'),
    (SELECT id FROM countries WHERE name = 'Guatemala'),
    (SELECT id FROM departments WHERE name = 'San Marcos'),
    (SELECT id FROM municipalities WHERE name = 'San Rafael Pie de la Cuesta'),
    (SELECT id FROM travel_types WHERE name = 'Con escuela / colegio'),
    (SELECT id FROM info_sources WHERE name = 'Recomendación'),
    (SELECT id FROM visitor_categories WHERE name = 'Estudiante'),
    3,
    (SELECT id FROM tariffs WHERE name = 'Estudiante' AND applies_to = 'VISITANTE' AND is_active = 1 LIMIT 1),
    10.00, 30.00,
    'MANUAL', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM visitor_records WHERE ticket_number = 'TKT-DEMO-002');

INSERT OR IGNORE INTO visitor_record_reasons (visitor_record_id, visit_reason_id)
SELECT vr.id, r.id FROM visitor_records vr JOIN visit_reasons r ON r.name IN ('Arqueología', 'Investigación') WHERE vr.ticket_number = 'TKT-DEMO-002';
INSERT OR IGNORE INTO visitor_record_activities (visitor_record_id, visit_activity_id)
SELECT vr.id, a.id FROM visitor_records vr JOIN visit_activities a ON a.name = 'Conocer la historia' WHERE vr.ticket_number = 'TKT-DEMO-002';

INSERT INTO receipts (receipt_number, receipt_date, origin_type, origin_id, payment_method_id, total, amount_received, change_amount, status, created_by_user_id)
SELECT 'REC-DEMO-001', datetime('now','-24 hours'), 'VISITANTE',
       (SELECT id FROM visitor_records WHERE ticket_number = 'TKT-DEMO-002'),
       (SELECT id FROM payment_methods WHERE name = 'Efectivo'),
       30.00, 30.00, 0.00, 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM receipts WHERE receipt_number = 'REC-DEMO-001');

INSERT INTO receipt_lines (receipt_id, description, quantity, unit_price, total)
SELECT (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-001'), 'Estudiante nacional x3', 3, 10.00, 30.00
WHERE NOT EXISTS (SELECT 1 FROM receipt_lines WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-001') AND description = 'Estudiante nacional x3');

INSERT INTO financial_movements (movement_type, concept_id, payment_method_id, origin_type, origin_id, receipt_id, amount, description, status, created_by_user_id)
SELECT 'INGRESO', (SELECT id FROM financial_concepts WHERE name = 'Ingreso por visitante'), (SELECT id FROM payment_methods WHERE name = 'Efectivo'),
       'VISITANTE', (SELECT id FROM visitor_records WHERE ticket_number = 'TKT-DEMO-002'), (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-001'),
       30.00, 'Recibo REC-DEMO-001', 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM financial_movements WHERE description = 'Recibo REC-DEMO-001');

/* VISITANTE 3: extranjero + recibo */
INSERT INTO visitor_records (
    ticket_number, record_date, check_in_at,
    country_id, travel_type_id, info_source_id,
    nationality, full_name,
    visitor_category_id, quantity, tariff_id, applied_rate, total_amount,
    is_foreign, source, created_by_user_id
)
SELECT
    'TKT-DEMO-003', date('now','-6 hours'), datetime('now','-2 hours'),
    (SELECT id FROM countries WHERE name = 'Estados Unidos'),
    (SELECT id FROM travel_types WHERE name = 'Solo'),
    (SELECT id FROM info_sources WHERE name = 'Internet'),
    'Estadounidense', 'John Smith',
    (SELECT id FROM visitor_categories WHERE name = 'Adulto'),
    1,
    (SELECT id FROM tariffs WHERE name = 'Adulto' AND applies_to = 'VISITANTE' AND is_active = 1 LIMIT 1),
    50.00, 50.00,
    1, 'MANUAL', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM visitor_records WHERE ticket_number = 'TKT-DEMO-003');

INSERT OR IGNORE INTO visitor_record_reasons (visitor_record_id, visit_reason_id)
SELECT vr.id, r.id FROM visitor_records vr JOIN visit_reasons r ON r.name IN ('Naturaleza', 'Aventura') WHERE vr.ticket_number = 'TKT-DEMO-003';
INSERT OR IGNORE INTO visitor_record_activities (visitor_record_id, visit_activity_id)
SELECT vr.id, a.id FROM visitor_records vr JOIN visit_activities a ON a.name IN ('Canopy', 'Caminata / trekking') WHERE vr.ticket_number = 'TKT-DEMO-003';

INSERT INTO receipts (receipt_number, receipt_date, origin_type, origin_id, payment_method_id, total, amount_received, change_amount, status, created_by_user_id)
SELECT 'REC-DEMO-002', datetime('now','-2 hours'), 'VISITANTE',
       (SELECT id FROM visitor_records WHERE ticket_number = 'TKT-DEMO-003'),
       (SELECT id FROM payment_methods WHERE name = 'Tarjeta'),
       50.00, 50.00, 0.00, 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM receipts WHERE receipt_number = 'REC-DEMO-002');

INSERT INTO receipt_lines (receipt_id, description, quantity, unit_price, total)
SELECT (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-002'), 'Adulto extranjero x1', 1, 50.00, 50.00
WHERE NOT EXISTS (SELECT 1 FROM receipt_lines WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-002') AND description = 'Adulto extranjero x1');

INSERT INTO financial_movements (movement_type, concept_id, payment_method_id, origin_type, origin_id, receipt_id, amount, description, status, created_by_user_id)
SELECT 'INGRESO', (SELECT id FROM financial_concepts WHERE name = 'Ingreso por visitante'), (SELECT id FROM payment_methods WHERE name = 'Tarjeta'),
       'VISITANTE', (SELECT id FROM visitor_records WHERE ticket_number = 'TKT-DEMO-003'), (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-002'),
       50.00, 'Recibo REC-DEMO-002', 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM financial_movements WHERE description = 'Recibo REC-DEMO-002');

/* VEHÍCULO demo */
INSERT INTO vehicle_records (vehicle_type_id, plate_number, check_in_at, check_out_at, tariff_id, applied_rate, total_amount, exit_enabled, source, created_by_user_id)
SELECT (SELECT id FROM vehicle_types WHERE name = 'Microbús'), 'BUS-0392', datetime('now','-26 hours'), datetime('now','-22 hours'),
       (SELECT id FROM tariffs WHERE name = 'Microbús' AND applies_to = 'VEHICULO' AND is_active = 1 LIMIT 1),
       30.00, 30.00, 1, 'MANUAL', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM vehicle_records WHERE plate_number = 'BUS-0392');

INSERT INTO receipts (receipt_number, receipt_date, origin_type, origin_id, payment_method_id, total, amount_received, change_amount, status, created_by_user_id)
SELECT 'REC-DEMO-003', datetime('now','-26 hours'), 'VEHICULO',
       (SELECT id FROM vehicle_records WHERE plate_number = 'BUS-0392' ORDER BY id LIMIT 1),
       (SELECT id FROM payment_methods WHERE name = 'Efectivo'),
       30.00, 50.00, 20.00, 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE EXISTS (SELECT 1 FROM vehicle_records WHERE plate_number = 'BUS-0392')
  AND NOT EXISTS (SELECT 1 FROM receipts WHERE receipt_number = 'REC-DEMO-003');

INSERT INTO receipt_lines (receipt_id, description, quantity, unit_price, total)
SELECT (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-003'), 'Microbús — BUS-0392', 1, 30.00, 30.00
WHERE NOT EXISTS (SELECT 1 FROM receipt_lines WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-003') AND description = 'Microbús — BUS-0392');

INSERT INTO financial_movements (movement_type, concept_id, payment_method_id, origin_type, origin_id, receipt_id, amount, description, status, created_by_user_id)
SELECT 'INGRESO', (SELECT id FROM financial_concepts WHERE name = 'Ingreso por vehículo'), (SELECT id FROM payment_methods WHERE name = 'Efectivo'),
       'VEHICULO', (SELECT id FROM vehicle_records WHERE plate_number = 'BUS-0392' ORDER BY id LIMIT 1), (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-003'),
       30.00, 'Recibo REC-DEMO-003', 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM financial_movements WHERE description = 'Recibo REC-DEMO-003');

/* HOSPEDAJE demo */
INSERT INTO lodging_records (lodging_type_id, record_date, nights, guests, tariff_id, applied_rate, total_amount, observations, created_by_user_id)
SELECT (SELECT id FROM lodging_types WHERE name = 'Dormitorio'), date('now','-1 day','-6 hours'), 2, 6,
       (SELECT id FROM tariffs WHERE name = 'Dormitorio' AND applies_to = 'HOSPEDAJE' AND is_active = 1 LIMIT 1),
       75.00, 150.00, 'Grupo de investigación — demo', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM lodging_records WHERE observations = 'Grupo de investigación — demo');

INSERT INTO receipts (receipt_number, receipt_date, origin_type, origin_id, payment_method_id, total, amount_received, change_amount, status, created_by_user_id)
SELECT 'REC-DEMO-004', datetime('now','-1 day'), 'HOSPEDAJE',
       (SELECT id FROM lodging_records WHERE observations = 'Grupo de investigación — demo' ORDER BY id LIMIT 1),
       (SELECT id FROM payment_methods WHERE name = 'Transferencia'),
       150.00, 150.00, 0.00, 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE EXISTS (SELECT 1 FROM lodging_records WHERE observations = 'Grupo de investigación — demo')
  AND NOT EXISTS (SELECT 1 FROM receipts WHERE receipt_number = 'REC-DEMO-004');

INSERT INTO receipt_lines (receipt_id, description, quantity, unit_price, total)
SELECT (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-004'), 'Dormitorio — 2 noches, 6 huéspedes', 1, 150.00, 150.00
WHERE NOT EXISTS (SELECT 1 FROM receipt_lines WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-004') AND description = 'Dormitorio — 2 noches, 6 huéspedes');

INSERT INTO financial_movements (movement_type, concept_id, payment_method_id, origin_type, origin_id, receipt_id, amount, description, status, created_by_user_id)
SELECT 'INGRESO', (SELECT id FROM financial_concepts WHERE name = 'Ingreso por hospedaje'), (SELECT id FROM payment_methods WHERE name = 'Transferencia'),
       'HOSPEDAJE', (SELECT id FROM lodging_records WHERE observations = 'Grupo de investigación — demo' ORDER BY id LIMIT 1), (SELECT id FROM receipts WHERE receipt_number = 'REC-DEMO-004'),
       150.00, 'Recibo REC-DEMO-004', 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM financial_movements WHERE description = 'Recibo REC-DEMO-004');

/* MOVIMIENTO MANUAL demo */
INSERT INTO financial_movements (movement_type, concept_id, payment_method_id, origin_type, amount, description, status, created_by_user_id)
SELECT 'EGRESO', (SELECT id FROM financial_concepts WHERE name = 'Limpieza'), (SELECT id FROM payment_methods WHERE name = 'Efectivo'),
       'MOVIMIENTO_MANUAL', 85.00, 'Compra insumos de limpieza — demo', 'ACTIVO', (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM financial_movements WHERE description = 'Compra insumos de limpieza — demo');

COMMIT;
