USE ParqueRM;
GO

/* ============================================================
   04_seed_catalogs.sql
   Catálogos iniciales ParqueRM
   SQL Server
   ============================================================ */

SET NOCOUNT ON;
GO

/* =========================
   SERVICIOS
   ========================= */

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'VISITANTES')
BEGIN
    INSERT INTO services (code, name, is_enabled)
    VALUES ('VISITANTES', 'Registro de visitantes', 1);
END
GO

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'VEHICULOS')
BEGIN
    INSERT INTO services (code, name, is_enabled)
    VALUES ('VEHICULOS', 'Control de parqueo', 1);
END
GO

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'HOSPEDAJE')
BEGIN
    INSERT INTO services (code, name, is_enabled)
    VALUES ('HOSPEDAJE', 'Hospedaje', 1);
END
GO

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'RESTAURANTE')
BEGIN
    INSERT INTO services (code, name, is_enabled)
    VALUES ('RESTAURANTE', 'Restaurante', 0);
END
GO

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'TIENDA')
BEGIN
    INSERT INTO services (code, name, is_enabled)
    VALUES ('TIENDA', 'Tienda / souvenirs', 0);
END
GO

IF NOT EXISTS (SELECT 1 FROM services WHERE code = 'ALQUILER_EQUIPO')
BEGIN
    INSERT INTO services (code, name, is_enabled)
    VALUES ('ALQUILER_EQUIPO', 'Alquiler de equipo', 0);
END
GO


/* =========================
   MEDIOS DE PAGO
   ========================= */

IF NOT EXISTS (SELECT 1 FROM payment_methods WHERE name = 'Efectivo')
BEGIN
    INSERT INTO payment_methods (name) VALUES ('Efectivo');
END
GO

IF NOT EXISTS (SELECT 1 FROM payment_methods WHERE name = 'Tarjeta')
BEGIN
    INSERT INTO payment_methods (name) VALUES ('Tarjeta');
END
GO

IF NOT EXISTS (SELECT 1 FROM payment_methods WHERE name = 'Transferencia')
BEGIN
    INSERT INTO payment_methods (name) VALUES ('Transferencia');
END
GO

IF NOT EXISTS (SELECT 1 FROM payment_methods WHERE name = 'Otro')
BEGIN
    INSERT INTO payment_methods (name) VALUES ('Otro');
END
GO


/* =========================
   CATEGORÍAS DE VISITANTES
   ========================= */

IF NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Adulto nacional')
BEGIN
    INSERT INTO visitor_categories (name) VALUES ('Adulto nacional');
END
GO

IF NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Niño nacional')
BEGIN
    INSERT INTO visitor_categories (name) VALUES ('Niño nacional');
END
GO

IF NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Estudiante nacional')
BEGIN
    INSERT INTO visitor_categories (name) VALUES ('Estudiante nacional');
END
GO

IF NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Adulto mayor nacional')
BEGIN
    INSERT INTO visitor_categories (name) VALUES ('Adulto mayor nacional');
END
GO

IF NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Adulto extranjero')
BEGIN
    INSERT INTO visitor_categories (name) VALUES ('Adulto extranjero');
END
GO

IF NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Niño extranjero')
BEGIN
    INSERT INTO visitor_categories (name) VALUES ('Niño extranjero');
END
GO

IF NOT EXISTS (SELECT 1 FROM visitor_categories WHERE name = 'Guía')
BEGIN
    INSERT INTO visitor_categories (name) VALUES ('Guía');
END
GO


/* =========================
   TIPOS DE VEHÍCULO
   ========================= */

IF NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Motocicleta')
BEGIN
    INSERT INTO vehicle_types (name) VALUES ('Motocicleta');
END
GO

IF NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Automóvil')
BEGIN
    INSERT INTO vehicle_types (name) VALUES ('Automóvil');
END
GO

IF NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Pick-up')
BEGIN
    INSERT INTO vehicle_types (name) VALUES ('Pick-up');
END
GO

IF NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Microbús')
BEGIN
    INSERT INTO vehicle_types (name) VALUES ('Microbús');
END
GO

IF NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Autobús')
BEGIN
    INSERT INTO vehicle_types (name) VALUES ('Autobús');
END
GO

IF NOT EXISTS (SELECT 1 FROM vehicle_types WHERE name = 'Otro')
BEGIN
    INSERT INTO vehicle_types (name) VALUES ('Otro');
END
GO


/* =========================
   TIPOS DE HOSPEDAJE
   ========================= */

IF NOT EXISTS (SELECT 1 FROM lodging_types WHERE name = 'Cabaña')
BEGIN
    INSERT INTO lodging_types (name) VALUES ('Cabaña');
END
GO

IF NOT EXISTS (SELECT 1 FROM lodging_types WHERE name = 'Dormitorio')
BEGIN
    INSERT INTO lodging_types (name) VALUES ('Dormitorio');
END
GO

IF NOT EXISTS (SELECT 1 FROM lodging_types WHERE name = 'Habitación doble')
BEGIN
    INSERT INTO lodging_types (name) VALUES ('Habitación doble');
END
GO


/* =========================
   CONCEPTOS FINANCIEROS
   ========================= */

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Ingreso por visitante')
BEGIN
    INSERT INTO financial_concepts (type, name)
    VALUES ('INGRESO', 'Ingreso por visitante');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Ingreso por vehículo')
BEGIN
    INSERT INTO financial_concepts (type, name)
    VALUES ('INGRESO', 'Ingreso por vehículo');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Ingreso por hospedaje')
BEGIN
    INSERT INTO financial_concepts (type, name)
    VALUES ('INGRESO', 'Ingreso por hospedaje');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'INGRESO' AND name = 'Servicio general')
BEGIN
    INSERT INTO financial_concepts (type, name)
    VALUES ('INGRESO', 'Servicio general');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'EGRESO' AND name = 'Insumos')
BEGIN
    INSERT INTO financial_concepts (type, name)
    VALUES ('EGRESO', 'Insumos');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'EGRESO' AND name = 'Mantenimiento')
BEGIN
    INSERT INTO financial_concepts (type, name)
    VALUES ('EGRESO', 'Mantenimiento');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'EGRESO' AND name = 'Limpieza')
BEGIN
    INSERT INTO financial_concepts (type, name)
    VALUES ('EGRESO', 'Limpieza');
END
GO

IF NOT EXISTS (SELECT 1 FROM financial_concepts WHERE type = 'EGRESO' AND name = 'Movimiento manual')
BEGIN
    INSERT INTO financial_concepts (type, name)
    VALUES ('EGRESO', 'Movimiento manual');
END
GO


/* =========================
   MOTIVOS DE VISITA
   ========================= */

IF NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Naturaleza')
BEGIN
    INSERT INTO visit_reasons (name) VALUES ('Naturaleza');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Recreación')
BEGIN
    INSERT INTO visit_reasons (name) VALUES ('Recreación');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Cultura viva')
BEGIN
    INSERT INTO visit_reasons (name) VALUES ('Cultura viva');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Arqueología')
BEGIN
    INSERT INTO visit_reasons (name) VALUES ('Arqueología');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Aventura')
BEGIN
    INSERT INTO visit_reasons (name) VALUES ('Aventura');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_reasons WHERE name = 'Investigación')
BEGIN
    INSERT INTO visit_reasons (name) VALUES ('Investigación');
END
GO


/* =========================
   ACTIVIDADES
   ========================= */

IF NOT EXISTS (SELECT 1 FROM visit_activities WHERE name = 'Caminata / trekking')
BEGIN
    INSERT INTO visit_activities (name) VALUES ('Caminata / trekking');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_activities WHERE name = 'Canopy')
BEGIN
    INSERT INTO visit_activities (name) VALUES ('Canopy');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_activities WHERE name = 'Observación de aves')
BEGIN
    INSERT INTO visit_activities (name) VALUES ('Observación de aves');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_activities WHERE name = 'Conocer la historia')
BEGIN
    INSERT INTO visit_activities (name) VALUES ('Conocer la historia');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_activities WHERE name = 'Bicicleta')
BEGIN
    INSERT INTO visit_activities (name) VALUES ('Bicicleta');
END
GO

IF NOT EXISTS (SELECT 1 FROM visit_activities WHERE name = 'Acampar')
BEGIN
    INSERT INTO visit_activities (name) VALUES ('Acampar');
END
GO


/* =========================
   FUENTES DE INFORMACIÓN
   ========================= */

IF NOT EXISTS (SELECT 1 FROM info_sources WHERE name = 'Recomendación')
BEGIN
    INSERT INTO info_sources (name) VALUES ('Recomendación');
END
GO

IF NOT EXISTS (SELECT 1 FROM info_sources WHERE name = 'Agencia de viajes')
BEGIN
    INSERT INTO info_sources (name) VALUES ('Agencia de viajes');
END
GO

IF NOT EXISTS (SELECT 1 FROM info_sources WHERE name = 'Guía impresa')
BEGIN
    INSERT INTO info_sources (name) VALUES ('Guía impresa');
END
GO

IF NOT EXISTS (SELECT 1 FROM info_sources WHERE name = 'Trifoliares')
BEGIN
    INSERT INTO info_sources (name) VALUES ('Trifoliares');
END
GO

IF NOT EXISTS (SELECT 1 FROM info_sources WHERE name = 'Internet')
BEGIN
    INSERT INTO info_sources (name) VALUES ('Internet');
END
GO

IF NOT EXISTS (SELECT 1 FROM info_sources WHERE name = 'TV / radio / prensa')
BEGIN
    INSERT INTO info_sources (name) VALUES ('TV / radio / prensa');
END
GO


/* =========================
   FORMAS DE VIAJE
   ========================= */

IF NOT EXISTS (SELECT 1 FROM travel_types WHERE name = 'Solo')
BEGIN
    INSERT INTO travel_types (name) VALUES ('Solo');
END
GO

IF NOT EXISTS (SELECT 1 FROM travel_types WHERE name = 'En familia')
BEGIN
    INSERT INTO travel_types (name) VALUES ('En familia');
END
GO

IF NOT EXISTS (SELECT 1 FROM travel_types WHERE name = 'Con amigos')
BEGIN
    INSERT INTO travel_types (name) VALUES ('Con amigos');
END
GO

IF NOT EXISTS (SELECT 1 FROM travel_types WHERE name = 'Con escuela / colegio')
BEGIN
    INSERT INTO travel_types (name) VALUES ('Con escuela / colegio');
END
GO

IF NOT EXISTS (SELECT 1 FROM travel_types WHERE name = 'Con universidad')
BEGIN
    INSERT INTO travel_types (name) VALUES ('Con universidad');
END
GO

IF NOT EXISTS (SELECT 1 FROM travel_types WHERE name = 'Con agencia de viajes')
BEGIN
    INSERT INTO travel_types (name) VALUES ('Con agencia de viajes');
END
GO


/* =========================
   PAÍSES
   ========================= */

IF NOT EXISTS (SELECT 1 FROM countries WHERE name = 'Guatemala')
BEGIN
    INSERT INTO countries (name, nationality)
    VALUES ('Guatemala', 'Guatemalteca');
END
GO

IF NOT EXISTS (SELECT 1 FROM countries WHERE name = 'México')
BEGIN
    INSERT INTO countries (name, nationality)
    VALUES ('México', 'Mexicana');
END
GO

IF NOT EXISTS (SELECT 1 FROM countries WHERE name = 'Estados Unidos')
BEGIN
    INSERT INTO countries (name, nationality)
    VALUES ('Estados Unidos', 'Estadounidense');
END
GO

IF NOT EXISTS (SELECT 1 FROM countries WHERE name = 'El Salvador')
BEGIN
    INSERT INTO countries (name, nationality)
    VALUES ('El Salvador', 'Salvadoreña');
END
GO

IF NOT EXISTS (SELECT 1 FROM countries WHERE name = 'Honduras')
BEGIN
    INSERT INTO countries (name, nationality)
    VALUES ('Honduras', 'Hondureña');
END
GO

IF NOT EXISTS (SELECT 1 FROM countries WHERE name = 'Otro')
BEGIN
    INSERT INTO countries (name, nationality)
    VALUES ('Otro', 'Otra');
END
GO


/* =========================
   DEPARTAMENTOS DE GUATEMALA
   ========================= */

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Alta Verapaz')
BEGIN
    INSERT INTO departments (name) VALUES ('Alta Verapaz');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Baja Verapaz')
BEGIN
    INSERT INTO departments (name) VALUES ('Baja Verapaz');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Chimaltenango')
BEGIN
    INSERT INTO departments (name) VALUES ('Chimaltenango');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Chiquimula')
BEGIN
    INSERT INTO departments (name) VALUES ('Chiquimula');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'El Progreso')
BEGIN
    INSERT INTO departments (name) VALUES ('El Progreso');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Escuintla')
BEGIN
    INSERT INTO departments (name) VALUES ('Escuintla');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Guatemala')
BEGIN
    INSERT INTO departments (name) VALUES ('Guatemala');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Huehuetenango')
BEGIN
    INSERT INTO departments (name) VALUES ('Huehuetenango');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Izabal')
BEGIN
    INSERT INTO departments (name) VALUES ('Izabal');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Jalapa')
BEGIN
    INSERT INTO departments (name) VALUES ('Jalapa');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Jutiapa')
BEGIN
    INSERT INTO departments (name) VALUES ('Jutiapa');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Petén')
BEGIN
    INSERT INTO departments (name) VALUES ('Petén');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Quetzaltenango')
BEGIN
    INSERT INTO departments (name) VALUES ('Quetzaltenango');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Quiché')
BEGIN
    INSERT INTO departments (name) VALUES ('Quiché');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Retalhuleu')
BEGIN
    INSERT INTO departments (name) VALUES ('Retalhuleu');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Sacatepéquez')
BEGIN
    INSERT INTO departments (name) VALUES ('Sacatepéquez');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'San Marcos')
BEGIN
    INSERT INTO departments (name) VALUES ('San Marcos');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Santa Rosa')
BEGIN
    INSERT INTO departments (name) VALUES ('Santa Rosa');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Sololá')
BEGIN
    INSERT INTO departments (name) VALUES ('Sololá');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Suchitepéquez')
BEGIN
    INSERT INTO departments (name) VALUES ('Suchitepéquez');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Totonicapán')
BEGIN
    INSERT INTO departments (name) VALUES ('Totonicapán');
END
GO

IF NOT EXISTS (SELECT 1 FROM departments WHERE name = 'Zacapa')
BEGIN
    INSERT INTO departments (name) VALUES ('Zacapa');
END
GO


/* =========================
   MUNICIPIOS INICIALES
   ========================= */

IF NOT EXISTS (
    SELECT 1
    FROM municipalities m
    INNER JOIN departments d ON d.id = m.department_id
    WHERE d.name = 'San Marcos'
      AND m.name = 'San Rafael Pie de la Cuesta'
)
BEGIN
    INSERT INTO municipalities (department_id, name)
    SELECT id, 'San Rafael Pie de la Cuesta'
    FROM departments
    WHERE name = 'San Marcos';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM municipalities m
    INNER JOIN departments d ON d.id = m.department_id
    WHERE d.name = 'San Marcos'
      AND m.name = 'San Marcos'
)
BEGIN
    INSERT INTO municipalities (department_id, name)
    SELECT id, 'San Marcos'
    FROM departments
    WHERE name = 'San Marcos';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM municipalities m
    INNER JOIN departments d ON d.id = m.department_id
    WHERE d.name = 'Guatemala'
      AND m.name = 'Guatemala'
)
BEGIN
    INSERT INTO municipalities (department_id, name)
    SELECT id, 'Guatemala'
    FROM departments
    WHERE name = 'Guatemala';
END
GO

PRINT '04_seed_catalogs.sql ejecutado correctamente.';
GO