USE ParqueRM;
GO

/* ============================================================
   05_seed_tariffs.sql
   Tarifas iniciales ParqueRM
   SQL Server
   ============================================================ */

SET NOCOUNT ON;
GO

/* =========================
   TARIFAS DE VISITANTES
   ========================= */

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN visitor_categories vc ON vc.id = t.visitor_category_id
    WHERE s.code = 'VISITANTES'
      AND vc.name = 'Adulto nacional'
      AND t.applies_to = 'VISITANTE'
)
BEGIN
    INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount, is_foreign)
    SELECT s.id, vc.id, 'Adulto nacional', 'VISITANTE', 20.00, 0
    FROM services s
    INNER JOIN visitor_categories vc ON vc.name = 'Adulto nacional'
    WHERE s.code = 'VISITANTES';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN visitor_categories vc ON vc.id = t.visitor_category_id
    WHERE s.code = 'VISITANTES'
      AND vc.name = 'Niño nacional'
      AND t.applies_to = 'VISITANTE'
)
BEGIN
    INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount, is_foreign)
    SELECT s.id, vc.id, 'Niño nacional', 'VISITANTE', 10.00, 0
    FROM services s
    INNER JOIN visitor_categories vc ON vc.name = 'Niño nacional'
    WHERE s.code = 'VISITANTES';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN visitor_categories vc ON vc.id = t.visitor_category_id
    WHERE s.code = 'VISITANTES'
      AND vc.name = 'Estudiante nacional'
      AND t.applies_to = 'VISITANTE'
)
BEGIN
    INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount, is_foreign)
    SELECT s.id, vc.id, 'Estudiante nacional', 'VISITANTE', 10.00, 0
    FROM services s
    INNER JOIN visitor_categories vc ON vc.name = 'Estudiante nacional'
    WHERE s.code = 'VISITANTES';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN visitor_categories vc ON vc.id = t.visitor_category_id
    WHERE s.code = 'VISITANTES'
      AND vc.name = 'Adulto mayor nacional'
      AND t.applies_to = 'VISITANTE'
)
BEGIN
    INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount, is_foreign)
    SELECT s.id, vc.id, 'Adulto mayor nacional', 'VISITANTE', 10.00, 0
    FROM services s
    INNER JOIN visitor_categories vc ON vc.name = 'Adulto mayor nacional'
    WHERE s.code = 'VISITANTES';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN visitor_categories vc ON vc.id = t.visitor_category_id
    WHERE s.code = 'VISITANTES'
      AND vc.name = 'Adulto extranjero'
      AND t.applies_to = 'VISITANTE'
)
BEGIN
    INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount, is_foreign)
    SELECT s.id, vc.id, 'Adulto extranjero', 'VISITANTE', 50.00, 1
    FROM services s
    INNER JOIN visitor_categories vc ON vc.name = 'Adulto extranjero'
    WHERE s.code = 'VISITANTES';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN visitor_categories vc ON vc.id = t.visitor_category_id
    WHERE s.code = 'VISITANTES'
      AND vc.name = 'Niño extranjero'
      AND t.applies_to = 'VISITANTE'
)
BEGIN
    INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount, is_foreign)
    SELECT s.id, vc.id, 'Niño extranjero', 'VISITANTE', 25.00, 1
    FROM services s
    INNER JOIN visitor_categories vc ON vc.name = 'Niño extranjero'
    WHERE s.code = 'VISITANTES';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN visitor_categories vc ON vc.id = t.visitor_category_id
    WHERE s.code = 'VISITANTES'
      AND vc.name = 'Guía'
      AND t.applies_to = 'VISITANTE'
)
BEGIN
    INSERT INTO tariffs (service_id, visitor_category_id, name, applies_to, amount, is_foreign)
    SELECT s.id, vc.id, 'Guía', 'VISITANTE', 0.00, 0
    FROM services s
    INNER JOIN visitor_categories vc ON vc.name = 'Guía'
    WHERE s.code = 'VISITANTES';
END
GO


/* =========================
   TARIFAS DE VEHÍCULOS
   ========================= */

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN vehicle_types vt ON vt.id = t.vehicle_type_id
    WHERE s.code = 'VEHICULOS'
      AND vt.name = 'Motocicleta'
      AND t.applies_to = 'VEHICULO'
)
BEGIN
    INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount)
    SELECT s.id, vt.id, 'Motocicleta', 'VEHICULO', 5.00
    FROM services s
    INNER JOIN vehicle_types vt ON vt.name = 'Motocicleta'
    WHERE s.code = 'VEHICULOS';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN vehicle_types vt ON vt.id = t.vehicle_type_id
    WHERE s.code = 'VEHICULOS'
      AND vt.name = 'Automóvil'
      AND t.applies_to = 'VEHICULO'
)
BEGIN
    INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount)
    SELECT s.id, vt.id, 'Automóvil', 'VEHICULO', 15.00
    FROM services s
    INNER JOIN vehicle_types vt ON vt.name = 'Automóvil'
    WHERE s.code = 'VEHICULOS';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN vehicle_types vt ON vt.id = t.vehicle_type_id
    WHERE s.code = 'VEHICULOS'
      AND vt.name = 'Pick-up'
      AND t.applies_to = 'VEHICULO'
)
BEGIN
    INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount)
    SELECT s.id, vt.id, 'Pick-up', 'VEHICULO', 15.00
    FROM services s
    INNER JOIN vehicle_types vt ON vt.name = 'Pick-up'
    WHERE s.code = 'VEHICULOS';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN vehicle_types vt ON vt.id = t.vehicle_type_id
    WHERE s.code = 'VEHICULOS'
      AND vt.name = 'Microbús'
      AND t.applies_to = 'VEHICULO'
)
BEGIN
    INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount)
    SELECT s.id, vt.id, 'Microbús', 'VEHICULO', 30.00
    FROM services s
    INNER JOIN vehicle_types vt ON vt.name = 'Microbús'
    WHERE s.code = 'VEHICULOS';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN vehicle_types vt ON vt.id = t.vehicle_type_id
    WHERE s.code = 'VEHICULOS'
      AND vt.name = 'Autobús'
      AND t.applies_to = 'VEHICULO'
)
BEGIN
    INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount)
    SELECT s.id, vt.id, 'Autobús', 'VEHICULO', 50.00
    FROM services s
    INNER JOIN vehicle_types vt ON vt.name = 'Autobús'
    WHERE s.code = 'VEHICULOS';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN vehicle_types vt ON vt.id = t.vehicle_type_id
    WHERE s.code = 'VEHICULOS'
      AND vt.name = 'Otro'
      AND t.applies_to = 'VEHICULO'
)
BEGIN
    INSERT INTO tariffs (service_id, vehicle_type_id, name, applies_to, amount)
    SELECT s.id, vt.id, 'Otro vehículo', 'VEHICULO', 10.00
    FROM services s
    INNER JOIN vehicle_types vt ON vt.name = 'Otro'
    WHERE s.code = 'VEHICULOS';
END
GO


/* =========================
   TARIFAS DE HOSPEDAJE
   ========================= */

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN lodging_types lt ON lt.id = t.lodging_type_id
    WHERE s.code = 'HOSPEDAJE'
      AND lt.name = 'Cabaña'
      AND t.applies_to = 'HOSPEDAJE'
)
BEGIN
    INSERT INTO tariffs (service_id, lodging_type_id, name, applies_to, amount)
    SELECT s.id, lt.id, 'Cabaña', 'HOSPEDAJE', 150.00
    FROM services s
    INNER JOIN lodging_types lt ON lt.name = 'Cabaña'
    WHERE s.code = 'HOSPEDAJE';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN lodging_types lt ON lt.id = t.lodging_type_id
    WHERE s.code = 'HOSPEDAJE'
      AND lt.name = 'Dormitorio'
      AND t.applies_to = 'HOSPEDAJE'
)
BEGIN
    INSERT INTO tariffs (service_id, lodging_type_id, name, applies_to, amount)
    SELECT s.id, lt.id, 'Dormitorio', 'HOSPEDAJE', 75.00
    FROM services s
    INNER JOIN lodging_types lt ON lt.name = 'Dormitorio'
    WHERE s.code = 'HOSPEDAJE';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM tariffs t
    INNER JOIN services s ON s.id = t.service_id
    INNER JOIN lodging_types lt ON lt.id = t.lodging_type_id
    WHERE s.code = 'HOSPEDAJE'
      AND lt.name = 'Habitación doble'
      AND t.applies_to = 'HOSPEDAJE'
)
BEGIN
    INSERT INTO tariffs (service_id, lodging_type_id, name, applies_to, amount)
    SELECT s.id, lt.id, 'Habitación doble', 'HOSPEDAJE', 200.00
    FROM services s
    INNER JOIN lodging_types lt ON lt.name = 'Habitación doble'
    WHERE s.code = 'HOSPEDAJE';
END
GO

PRINT '05_seed_tariffs.sql ejecutado correctamente.';
GO