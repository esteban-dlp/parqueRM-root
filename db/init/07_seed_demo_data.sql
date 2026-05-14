/* ============================================================
   07_seed_demo_data.sql
   Datos de demostración para ParqueRM — idempotente
   Requiere: 02_schema.sql, 03_seed_security.sql, 04_seed_catalogs.sql,
             05_seed_tariffs.sql, 06_seed_park_config.sql ya ejecutados.
   ============================================================ */

USE ParqueRM;
GO

DECLARE @adminId INT = 1;

/* ---- Resolución de catálogos por nombre ---- */
DECLARE @countryGT      INT = (SELECT id FROM countries      WHERE name = 'Guatemala');
DECLARE @deptSM         INT = (SELECT id FROM departments    WHERE name = 'San Marcos');
DECLARE @munSRafael     INT = (SELECT id FROM municipalities WHERE name = 'San Rafael Pie de la Cuesta');

DECLARE @pmEfectivo     INT = (SELECT id FROM payment_methods WHERE name = 'Efectivo');
DECLARE @pmTarjeta      INT = (SELECT id FROM payment_methods WHERE name = 'Tarjeta');
DECLARE @pmTransfer     INT = (SELECT id FROM payment_methods WHERE name = 'Transferencia');

DECLARE @tarAdultoNac   INT = (SELECT id FROM tariffs WHERE name = 'Adulto nacional'      AND is_active = 1);
DECLARE @tarEstudiante  INT = (SELECT id FROM tariffs WHERE name = 'Estudiante nacional'  AND is_active = 1);
DECLARE @tarExtAdult    INT = (SELECT id FROM tariffs WHERE name = 'Adulto extranjero'    AND is_active = 1);
DECLARE @tarMicrobus    INT = (SELECT id FROM tariffs WHERE name = N'Microbús'            AND is_active = 1);
DECLARE @tarDormit      INT = (SELECT id FROM tariffs WHERE name = 'Dormitorio'           AND is_active = 1);

DECLARE @fcVisitante    INT = (SELECT id FROM financial_concepts WHERE name = 'Ingreso por visitante');
DECLARE @fcVehiculo     INT = (SELECT id FROM financial_concepts WHERE name = N'Ingreso por vehículo');
DECLARE @fcHospedaje    INT = (SELECT id FROM financial_concepts WHERE name = 'Ingreso por hospedaje');
DECLARE @fcLimpieza     INT = (SELECT id FROM financial_concepts WHERE name = 'Limpieza');

DECLARE @ltDormit       INT = (SELECT id FROM lodging_types WHERE name = 'Dormitorio');
DECLARE @vtMicrobus     INT = (SELECT id FROM vehicle_types  WHERE name = N'Microbús');

/* ---- Variables para IDs generados ---- */
DECLARE @visitorId1 INT, @visitorId2 INT, @visitorId3 INT;
DECLARE @vehicleId2 INT;
DECLARE @lodgingId2 INT;
DECLARE @receiptA   INT, @receiptB INT, @receiptC INT, @receiptD INT;
DECLARE @tmpId      INT;

/* ============================================================
   VISITANTE 1: 2 adultos nacionales, familia, HOY, ACTIVO
   Sin recibo — el presentador demostrará el flujo de cobro en vivo
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM visitor_records WHERE ticket_number = 'TKT-DEMO-001')
BEGIN
    INSERT INTO visitor_records (
        ticket_number, record_date, check_in_at,
        country_id, department_id, municipality_id,
        travel_type_id, info_source_id,
        visitor_category_id, quantity, tariff_id, applied_rate, total_amount,
        gender, source, created_by_user_id
    ) VALUES (
        'TKT-DEMO-001', CAST(SYSDATETIME() AS DATE), SYSDATETIME(),
        @countryGT, @deptSM, @munSRafael,
        2, 5,          -- En familia / Internet
        1, 2, @tarAdultoNac, 20.00, 40.00,
        'FEMENINO', 'MANUAL', @adminId
    );
    SET @tmpId = SCOPE_IDENTITY();
    INSERT INTO visitor_record_reasons    VALUES (@tmpId, 1), (@tmpId, 2);   -- Naturaleza, Recreación
    INSERT INTO visitor_record_activities VALUES (@tmpId, 1), (@tmpId, 3);   -- Caminata, Observación de aves
END
SET @visitorId1 = (SELECT id FROM visitor_records WHERE ticket_number = 'TKT-DEMO-001');

/* ============================================================
   VISITANTE 2: 3 estudiantes nacionales, ayer, COMPLETADO + recibo
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM visitor_records WHERE ticket_number = 'TKT-DEMO-002')
BEGIN
    INSERT INTO visitor_records (
        ticket_number, record_date, check_in_at, check_out_at,
        country_id, department_id, municipality_id,
        travel_type_id, info_source_id,
        visitor_category_id, quantity, tariff_id, applied_rate, total_amount,
        source, created_by_user_id
    ) VALUES (
        'TKT-DEMO-002',
        CAST(DATEADD(day, -1, SYSDATETIME()) AS DATE),
        DATEADD(hour, -25, SYSDATETIME()),
        DATEADD(hour, -19, SYSDATETIME()),
        @countryGT, @deptSM, @munSRafael,
        4, 1,          -- Con escuela/colegio / Recomendación
        3, 3, @tarEstudiante, 10.00, 30.00,
        'MANUAL', @adminId
    );
    SET @tmpId = SCOPE_IDENTITY();
    INSERT INTO visitor_record_reasons    VALUES (@tmpId, 4), (@tmpId, 6);   -- Arqueología, Investigación
    INSERT INTO visitor_record_activities VALUES (@tmpId, 4);                -- Conocer la historia
END
SET @visitorId2 = (SELECT id FROM visitor_records WHERE ticket_number = 'TKT-DEMO-002');

IF NOT EXISTS (SELECT 1 FROM receipts WHERE receipt_number = 'REC-DEMO-001')
BEGIN
    INSERT INTO receipts (
        receipt_number, receipt_date, origin_type, origin_id,
        payment_method_id, total, amount_received, change_amount,
        status, created_by_user_id
    ) VALUES (
        'REC-DEMO-001', DATEADD(hour, -24, SYSDATETIME()),
        'VISITANTE', @visitorId2,
        @pmEfectivo, 30.00, 30.00, 0.00,
        'ACTIVO', @adminId
    );
    SET @receiptA = SCOPE_IDENTITY();

    INSERT INTO receipt_lines (receipt_id, description, quantity, unit_price, total)
    VALUES (@receiptA, 'Estudiante nacional x3', 3, 10.00, 30.00);

    INSERT INTO financial_movements (
        movement_type, concept_id, payment_method_id,
        origin_type, origin_id, receipt_id,
        amount, description, status, created_by_user_id
    ) VALUES (
        'INGRESO', @fcVisitante, @pmEfectivo,
        'VISITANTE', @visitorId2, @receiptA,
        30.00, 'Recibo REC-DEMO-001', 'ACTIVO', @adminId
    );
END

/* ============================================================
   VISITANTE 3: 1 adulto extranjero (EE.UU.), HOY, ACTIVO + recibo cobrado
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM visitor_records WHERE ticket_number = 'TKT-DEMO-003')
BEGIN
    INSERT INTO visitor_records (
        ticket_number, record_date, check_in_at,
        country_id,
        travel_type_id, info_source_id,
        nationality, full_name,
        visitor_category_id, quantity, tariff_id, applied_rate, total_amount,
        source, created_by_user_id
    ) VALUES (
        'TKT-DEMO-003', CAST(SYSDATETIME() AS DATE), DATEADD(hour, -2, SYSDATETIME()),
        3,             -- Estados Unidos
        1, 5,          -- Solo / Internet
        'Estadounidense', 'John Smith',
        5, 1, @tarExtAdult, 50.00, 50.00,
        'MANUAL', @adminId
    );
    SET @tmpId = SCOPE_IDENTITY();
    INSERT INTO visitor_record_reasons    VALUES (@tmpId, 1), (@tmpId, 5);   -- Naturaleza, Aventura
    INSERT INTO visitor_record_activities VALUES (@tmpId, 2), (@tmpId, 1);   -- Canopy, Caminata
END
SET @visitorId3 = (SELECT id FROM visitor_records WHERE ticket_number = 'TKT-DEMO-003');

IF NOT EXISTS (SELECT 1 FROM receipts WHERE receipt_number = 'REC-DEMO-002')
BEGIN
    INSERT INTO receipts (
        receipt_number, receipt_date, origin_type, origin_id,
        payment_method_id, total, amount_received, change_amount,
        status, created_by_user_id
    ) VALUES (
        'REC-DEMO-002', DATEADD(hour, -2, SYSDATETIME()),
        'VISITANTE', @visitorId3,
        @pmTarjeta, 50.00, 50.00, 0.00,
        'ACTIVO', @adminId
    );
    SET @receiptB = SCOPE_IDENTITY();

    INSERT INTO receipt_lines (receipt_id, description, quantity, unit_price, total)
    VALUES (@receiptB, 'Adulto extranjero x1', 1, 50.00, 50.00);

    INSERT INTO financial_movements (
        movement_type, concept_id, payment_method_id,
        origin_type, origin_id, receipt_id,
        amount, description, status, created_by_user_id
    ) VALUES (
        'INGRESO', @fcVisitante, @pmTarjeta,
        'VISITANTE', @visitorId3, @receiptB,
        50.00, 'Recibo REC-DEMO-002', 'ACTIVO', @adminId
    );
END

/* ============================================================
   VEHÍCULO 2: Microbús BUS-0392, ayer, COMPLETADO + recibo
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM vehicle_records WHERE plate_number = 'BUS-0392')
BEGIN
    INSERT INTO vehicle_records (
        vehicle_type_id, plate_number,
        check_in_at, check_out_at,
        tariff_id, applied_rate, total_amount,
        exit_enabled, source, created_by_user_id
    ) VALUES (
        @vtMicrobus, 'BUS-0392',
        DATEADD(hour, -26, SYSDATETIME()),
        DATEADD(hour, -22, SYSDATETIME()),
        @tarMicrobus, 30.00, 30.00,
        1, 'MANUAL', @adminId
    );
    SET @vehicleId2 = SCOPE_IDENTITY();

    INSERT INTO receipts (
        receipt_number, receipt_date, origin_type, origin_id,
        payment_method_id, total, amount_received, change_amount,
        status, created_by_user_id
    ) VALUES (
        'REC-DEMO-003', DATEADD(hour, -26, SYSDATETIME()),
        'VEHICULO', @vehicleId2,
        @pmEfectivo, 30.00, 50.00, 20.00,
        'ACTIVO', @adminId
    );
    SET @receiptC = SCOPE_IDENTITY();

    INSERT INTO receipt_lines (receipt_id, description, quantity, unit_price, total)
    VALUES (@receiptC, N'Microbús — BUS-0392', 1, 30.00, 30.00);

    INSERT INTO financial_movements (
        movement_type, concept_id, payment_method_id,
        origin_type, origin_id, receipt_id,
        amount, description, status, created_by_user_id
    ) VALUES (
        'INGRESO', @fcVehiculo, @pmEfectivo,
        'VEHICULO', @vehicleId2, @receiptC,
        30.00, 'Recibo REC-DEMO-003', 'ACTIVO', @adminId
    );
END

/* ============================================================
   HOSPEDAJE 2: Dormitorio, 2 noches, 6 huéspedes, ayer + recibo
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM lodging_records WHERE observations = N'Grupo de investigación — demo')
BEGIN
    INSERT INTO lodging_records (
        lodging_type_id, record_date, nights, guests,
        tariff_id, applied_rate, total_amount,
        observations, created_by_user_id
    ) VALUES (
        @ltDormit,
        CAST(DATEADD(day, -1, SYSDATETIME()) AS DATE),
        2, 6,
        @tarDormit, 75.00, 150.00,
        N'Grupo de investigación — demo', @adminId
    );
    SET @lodgingId2 = SCOPE_IDENTITY();

    INSERT INTO receipts (
        receipt_number, receipt_date, origin_type, origin_id,
        payment_method_id, total, amount_received, change_amount,
        status, created_by_user_id
    ) VALUES (
        'REC-DEMO-004', DATEADD(day, -1, SYSDATETIME()),
        'HOSPEDAJE', @lodgingId2,
        @pmTransfer, 150.00, 150.00, 0.00,
        'ACTIVO', @adminId
    );
    SET @receiptD = SCOPE_IDENTITY();

    INSERT INTO receipt_lines (receipt_id, description, quantity, unit_price, total)
    VALUES (@receiptD, 'Dormitorio — 2 noches, 6 huéspedes', 1, 150.00, 150.00);

    INSERT INTO financial_movements (
        movement_type, concept_id, payment_method_id,
        origin_type, origin_id, receipt_id,
        amount, description, status, created_by_user_id
    ) VALUES (
        'INGRESO', @fcHospedaje, @pmTransfer,
        'HOSPEDAJE', @lodgingId2, @receiptD,
        150.00, 'Recibo REC-DEMO-004', 'ACTIVO', @adminId
    );
END

/* ============================================================
   MOVIMIENTO MANUAL: EGRESO de insumos de limpieza
   Muestra la funcionalidad de movimiento manual en Caja
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM financial_movements WHERE description = N'Compra insumos de limpieza — demo')
BEGIN
    INSERT INTO financial_movements (
        movement_type, concept_id, payment_method_id,
        origin_type,
        amount, description, status, created_by_user_id
    ) VALUES (
        'EGRESO', @fcLimpieza, @pmEfectivo,
        'MOVIMIENTO_MANUAL',
        85.00, N'Compra insumos de limpieza — demo', 'ACTIVO', @adminId
    );
END

PRINT 'Seed demo data OK.';
GO
