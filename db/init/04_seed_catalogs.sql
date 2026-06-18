PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* 04_seed_catalogs.sql — SQLite version */
BEGIN TRANSACTION;
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('VISITANTES', 'Registro de visitantes', 1);
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('VEHICULOS', 'Control de parqueo', 1);
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('HOSPEDAJE', 'Hospedaje', 1);
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('RESTAURANTE', 'Restaurante', 0);
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('TIENDA', 'Tienda / souvenirs', 0);
INSERT OR IGNORE INTO services (code, name, is_enabled) VALUES ('ALQUILER_EQUIPO', 'Alquiler de equipo', 0);
INSERT OR IGNORE INTO payment_methods (name) VALUES ('Efectivo');
INSERT OR IGNORE INTO payment_methods (name) VALUES ('Tarjeta');
INSERT OR IGNORE INTO payment_methods (name) VALUES ('Transferencia');
INSERT OR IGNORE INTO payment_methods (name) VALUES ('Otro');
INSERT OR IGNORE INTO visitor_categories (name) VALUES ('Adulto');
INSERT OR IGNORE INTO visitor_categories (name) VALUES ('Niño');
INSERT OR IGNORE INTO visitor_categories (name) VALUES ('Estudiante');
INSERT OR IGNORE INTO visitor_categories (name) VALUES ('Adulto mayor');
INSERT OR IGNORE INTO visitor_categories (name) VALUES ('Guía');
INSERT OR IGNORE INTO vehicle_types (name) VALUES ('Motocicleta');
INSERT OR IGNORE INTO vehicle_types (name) VALUES ('Automóvil');
INSERT OR IGNORE INTO vehicle_types (name) VALUES ('Pick-up');
INSERT OR IGNORE INTO vehicle_types (name) VALUES ('Microbús');
INSERT OR IGNORE INTO vehicle_types (name) VALUES ('Autobús');
INSERT OR IGNORE INTO vehicle_types (name) VALUES ('Otro');
INSERT OR IGNORE INTO lodging_types (name) VALUES ('Cabaña');
INSERT OR IGNORE INTO lodging_types (name) VALUES ('Dormitorio');
INSERT OR IGNORE INTO lodging_types (name) VALUES ('Habitación doble');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Ingreso por visitante');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Ingreso por vehículo');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Ingreso por hospedaje');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('INGRESO', 'Servicio general');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('EGRESO', 'Insumos');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('EGRESO', 'Mantenimiento');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('EGRESO', 'Limpieza');
INSERT OR IGNORE INTO financial_concepts (type, name) VALUES ('EGRESO', 'Movimiento manual');
INSERT OR IGNORE INTO visit_reasons (name) VALUES ('Naturaleza');
INSERT OR IGNORE INTO visit_reasons (name) VALUES ('Recreación');
INSERT OR IGNORE INTO visit_reasons (name) VALUES ('Cultura viva');
INSERT OR IGNORE INTO visit_reasons (name) VALUES ('Arqueología');
INSERT OR IGNORE INTO visit_reasons (name) VALUES ('Aventura');
INSERT OR IGNORE INTO visit_reasons (name) VALUES ('Investigación');
INSERT OR IGNORE INTO visit_activities (name) VALUES ('Caminata / trekking');
INSERT OR IGNORE INTO visit_activities (name) VALUES ('Canopy');
INSERT OR IGNORE INTO visit_activities (name) VALUES ('Observación de aves');
INSERT OR IGNORE INTO visit_activities (name) VALUES ('Conocer la historia');
INSERT OR IGNORE INTO visit_activities (name) VALUES ('Bicicleta');
INSERT OR IGNORE INTO visit_activities (name) VALUES ('Acampar');
INSERT OR IGNORE INTO info_sources (name) VALUES ('Recomendación');
INSERT OR IGNORE INTO info_sources (name) VALUES ('Agencia de viajes');
INSERT OR IGNORE INTO info_sources (name) VALUES ('Guía impresa');
INSERT OR IGNORE INTO info_sources (name) VALUES ('Trifoliares');
INSERT OR IGNORE INTO info_sources (name) VALUES ('Internet');
INSERT OR IGNORE INTO info_sources (name) VALUES ('TV / radio / prensa');
INSERT OR IGNORE INTO travel_types (name) VALUES ('Solo');
INSERT OR IGNORE INTO travel_types (name) VALUES ('En familia');
INSERT OR IGNORE INTO travel_types (name) VALUES ('Con amigos');
INSERT OR IGNORE INTO travel_types (name) VALUES ('Con escuela / colegio');
INSERT OR IGNORE INTO travel_types (name) VALUES ('Con universidad');
INSERT OR IGNORE INTO travel_types (name) VALUES ('Con agencia de viajes');
INSERT OR IGNORE INTO countries (name, nationality) VALUES ('Guatemala', 'Guatemalteca');
INSERT OR IGNORE INTO countries (name, nationality) VALUES ('México', 'Mexicana');
INSERT OR IGNORE INTO countries (name, nationality) VALUES ('Estados Unidos', 'Estadounidense');
INSERT OR IGNORE INTO countries (name, nationality) VALUES ('El Salvador', 'Salvadoreña');
INSERT OR IGNORE INTO countries (name, nationality) VALUES ('Honduras', 'Hondureña');
INSERT OR IGNORE INTO countries (name, nationality) VALUES ('Otro', 'Otra');
INSERT OR IGNORE INTO departments (name) VALUES ('Alta Verapaz');
INSERT OR IGNORE INTO departments (name) VALUES ('Baja Verapaz');
INSERT OR IGNORE INTO departments (name) VALUES ('Chimaltenango');
INSERT OR IGNORE INTO departments (name) VALUES ('Chiquimula');
INSERT OR IGNORE INTO departments (name) VALUES ('El Progreso');
INSERT OR IGNORE INTO departments (name) VALUES ('Escuintla');
INSERT OR IGNORE INTO departments (name) VALUES ('Guatemala');
INSERT OR IGNORE INTO departments (name) VALUES ('Huehuetenango');
INSERT OR IGNORE INTO departments (name) VALUES ('Izabal');
INSERT OR IGNORE INTO departments (name) VALUES ('Jalapa');
INSERT OR IGNORE INTO departments (name) VALUES ('Jutiapa');
INSERT OR IGNORE INTO departments (name) VALUES ('Petén');
INSERT OR IGNORE INTO departments (name) VALUES ('Quetzaltenango');
INSERT OR IGNORE INTO departments (name) VALUES ('Quiché');
INSERT OR IGNORE INTO departments (name) VALUES ('Retalhuleu');
INSERT OR IGNORE INTO departments (name) VALUES ('Sacatepéquez');
INSERT OR IGNORE INTO departments (name) VALUES ('San Marcos');
INSERT OR IGNORE INTO departments (name) VALUES ('Santa Rosa');
INSERT OR IGNORE INTO departments (name) VALUES ('Sololá');
INSERT OR IGNORE INTO departments (name) VALUES ('Suchitepéquez');
INSERT OR IGNORE INTO departments (name) VALUES ('Totonicapán');
INSERT OR IGNORE INTO departments (name) VALUES ('Zacapa');

INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Rafael Pie de la Cuesta' FROM departments WHERE name = 'San Marcos';


INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Marcos' FROM departments WHERE name = 'San Marcos';


INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Guatemala' FROM departments WHERE name = 'Guatemala';

COMMIT;
