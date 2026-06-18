PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   03a_repair_utf8_seed_text.sql
   SQLite version. Kept for compatibility with your existing order.
   Since SQLite reads UTF-8 scripts directly, this is mostly harmless cleanup.
   ============================================================ */
BEGIN TRANSACTION;

UPDATE roles SET description = 'Acceso total al sistema' WHERE name = 'Administrador';
UPDATE roles SET description = 'Puede registrar visitantes, vehículos, hospedaje, cobros y operaciones del día' WHERE name = 'Operador de caja';
UPDATE roles SET description = 'Solo lectura para consultas y reportes' WHERE name = 'Consulta';

UPDATE visitor_categories SET name = 'Niño' WHERE name = 'NiÃ±o' AND NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Niño');
UPDATE visitor_categories SET name = 'Guía' WHERE name = 'GuÃ­a' AND NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Guía');
UPDATE vehicle_types SET name = 'Automóvil' WHERE name = 'AutomÃ³vil' AND NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Automóvil');
UPDATE vehicle_types SET name = 'Microbús' WHERE name = 'MicrobÃºs' AND NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Microbús');
UPDATE vehicle_types SET name = 'Autobús' WHERE name = 'AutobÃºs' AND NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Autobús');
UPDATE lodging_types SET name = 'Cabaña' WHERE name = 'CabaÃ±a' AND NOT EXISTS (SELECT 1 FROM lodging_types WHERE name = 'Cabaña');
UPDATE lodging_types SET name = 'Habitación doble' WHERE name = 'HabitaciÃ³n doble' AND NOT EXISTS (SELECT 1 FROM lodging_types WHERE name = 'Habitación doble');
UPDATE visit_reasons SET name = 'Recreación' WHERE name = 'RecreaciÃ³n' AND NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Recreación');
UPDATE visit_reasons SET name = 'Arqueología' WHERE name = 'ArqueologÃ­a' AND NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Arqueología');
UPDATE visit_reasons SET name = 'Investigación' WHERE name = 'InvestigaciÃ³n' AND NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Investigación');
UPDATE visit_activities SET name = 'Observación de aves' WHERE name = 'ObservaciÃ³n de aves' AND NOT EXISTS (SELECT 1 FROM visit_activities WHERE name = 'Observación de aves');
UPDATE info_sources SET name = 'Recomendación' WHERE name = 'RecomendaciÃ³n' AND NOT EXISTS (SELECT 1 FROM info_sources WHERE name = 'Recomendación');
UPDATE info_sources SET name = 'Guía impresa' WHERE name = 'GuÃ­a impresa' AND NOT EXISTS (SELECT 1 FROM info_sources WHERE name = 'Guía impresa');
UPDATE countries SET name = 'México' WHERE name = 'MÃ©xico' AND NOT EXISTS (SELECT 1 FROM countries WHERE name = 'México');
UPDATE countries SET nationality = 'Mexicana' WHERE name = 'México';
UPDATE countries SET nationality = 'Salvadoreña' WHERE name = 'El Salvador';
UPDATE countries SET nationality = 'Hondureña' WHERE name = 'Honduras';
UPDATE departments SET name = 'Petén' WHERE name = 'PetÃ©n' AND NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Petén');
UPDATE departments SET name = 'Quiché' WHERE name = 'QuichÃ©' AND NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Quiché');
UPDATE departments SET name = 'Sacatepéquez' WHERE name = 'SacatepÃ©quez' AND NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Sacatepéquez');
UPDATE departments SET name = 'Sololá' WHERE name = 'SololÃ¡' AND NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Sololá');
UPDATE departments SET name = 'Suchitepéquez' WHERE name = 'SuchitepÃ©quez' AND NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Suchitepéquez');
UPDATE departments SET name = 'Totonicapán' WHERE name = 'TotonicapÃ¡n' AND NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Totonicapán');
UPDATE tariffs SET name = 'Niño' WHERE name = 'NiÃ±o';
UPDATE tariffs SET name = 'Guía' WHERE name = 'GuÃ­a';
UPDATE tariffs SET name = 'Automóvil' WHERE name = 'AutomÃ³vil';
UPDATE tariffs SET name = 'Microbús' WHERE name = 'MicrobÃºs';
UPDATE tariffs SET name = 'Autobús' WHERE name = 'AutobÃºs';
UPDATE tariffs SET name = 'Otro vehículo' WHERE name = 'Otro vehÃ­culo';
UPDATE tariffs SET name = 'Cabaña' WHERE name = 'CabaÃ±a';
UPDATE tariffs SET name = 'Habitación doble' WHERE name = 'HabitaciÃ³n doble';
UPDATE park_config SET sidebar_color_hex = COALESCE(sidebar_color_hex, '#1A3A2A');

COMMIT;
