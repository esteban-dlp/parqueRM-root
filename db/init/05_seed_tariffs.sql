PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* 05_seed_tariffs.sql — SQLite version */
BEGIN TRANSACTION;

/* TARIFAS DE VISITANTES */
INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vc.id, 'Adulto', 'VISITANTE', 20.00, 50.00
FROM services s JOIN visitor_categories vc ON vc.name = 'Adulto'
WHERE s.code = 'VISITANTES'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.visitor_category_id = vc.id AND t.applies_to = 'VISITANTE');

INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vc.id, 'Niño', 'VISITANTE', 10.00, 25.00
FROM services s JOIN visitor_categories vc ON vc.name = 'Niño'
WHERE s.code = 'VISITANTES'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.visitor_category_id = vc.id AND t.applies_to = 'VISITANTE');

INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vc.id, 'Estudiante', 'VISITANTE', 10.00, 25.00
FROM services s JOIN visitor_categories vc ON vc.name = 'Estudiante'
WHERE s.code = 'VISITANTES'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.visitor_category_id = vc.id AND t.applies_to = 'VISITANTE');

INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vc.id, 'Adulto mayor', 'VISITANTE', 10.00, 25.00
FROM services s JOIN visitor_categories vc ON vc.name = 'Adulto mayor'
WHERE s.code = 'VISITANTES'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.visitor_category_id = vc.id AND t.applies_to = 'VISITANTE');

INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vc.id, 'Guía', 'VISITANTE', 0.00, 0.00
FROM services s JOIN visitor_categories vc ON vc.name = 'Guía'
WHERE s.code = 'VISITANTES'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.visitor_category_id = vc.id AND t.applies_to = 'VISITANTE');

/* TARIFAS DE VEHÍCULOS */
INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vt.id, 'Motocicleta', 'VEHICULO', 5.00, 5.00
FROM services s JOIN vehicle_types vt ON vt.name = 'Motocicleta'
WHERE s.code = 'VEHICULOS'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.vehicle_type_id = vt.id AND t.applies_to = 'VEHICULO');

INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vt.id, 'Automóvil', 'VEHICULO', 15.00, 15.00
FROM services s JOIN vehicle_types vt ON vt.name = 'Automóvil'
WHERE s.code = 'VEHICULOS'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.vehicle_type_id = vt.id AND t.applies_to = 'VEHICULO');

INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vt.id, 'Pick-up', 'VEHICULO', 15.00, 15.00
FROM services s JOIN vehicle_types vt ON vt.name = 'Pick-up'
WHERE s.code = 'VEHICULOS'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.vehicle_type_id = vt.id AND t.applies_to = 'VEHICULO');

INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vt.id, 'Microbús', 'VEHICULO', 30.00, 30.00
FROM services s JOIN vehicle_types vt ON vt.name = 'Microbús'
WHERE s.code = 'VEHICULOS'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.vehicle_type_id = vt.id AND t.applies_to = 'VEHICULO');

INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vt.id, 'Autobús', 'VEHICULO', 50.00, 50.00
FROM services s JOIN vehicle_types vt ON vt.name = 'Autobús'
WHERE s.code = 'VEHICULOS'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.vehicle_type_id = vt.id AND t.applies_to = 'VEHICULO');

INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, vt.id, 'Otro vehículo', 'VEHICULO', 10.00, 10.00
FROM services s JOIN vehicle_types vt ON vt.name = 'Otro'
WHERE s.code = 'VEHICULOS'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.vehicle_type_id = vt.id AND t.applies_to = 'VEHICULO');

/* TARIFAS DE HOSPEDAJE */
INSERT INTO tariffs (service_id, lodging_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, lt.id, 'Cabaña', 'HOSPEDAJE', 150.00, 150.00
FROM services s JOIN lodging_types lt ON lt.name = 'Cabaña'
WHERE s.code = 'HOSPEDAJE'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.lodging_type_id = lt.id AND t.applies_to = 'HOSPEDAJE');

INSERT INTO tariffs (service_id, lodging_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, lt.id, 'Dormitorio', 'HOSPEDAJE', 75.00, 75.00
FROM services s JOIN lodging_types lt ON lt.name = 'Dormitorio'
WHERE s.code = 'HOSPEDAJE'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.lodging_type_id = lt.id AND t.applies_to = 'HOSPEDAJE');

INSERT INTO tariffs (service_id, lodging_type_id, name, applies_to, amount_local, amount_foreign)
SELECT s.id, lt.id, 'Habitación doble', 'HOSPEDAJE', 200.00, 200.00
FROM services s JOIN lodging_types lt ON lt.name = 'Habitación doble'
WHERE s.code = 'HOSPEDAJE'
  AND NOT EXISTS (SELECT 1 FROM tariffs t WHERE t.service_id = s.id AND t.lodging_type_id = lt.id AND t.applies_to = 'HOSPEDAJE');

COMMIT;
