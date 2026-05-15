USE ParqueRM;
GO

/* ============================================================
   02_schema.sql
   Estructura principal ParqueRM
   SQL Server
   ============================================================ */

SET NOCOUNT ON;
GO

/* =========================
   SEGURIDAD
   ========================= */

IF OBJECT_ID('roles', 'U') IS NULL
BEGIN
    CREATE TABLE roles (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(100) NOT NULL UNIQUE,
        description NVARCHAR(255) NULL,
        is_active BIT NOT NULL DEFAULT 1,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NULL
    );
END
GO

IF OBJECT_ID('permissions', 'U') IS NULL
BEGIN
    CREATE TABLE permissions (
        id INT IDENTITY(1,1) PRIMARY KEY,
        code NVARCHAR(100) NOT NULL UNIQUE,
        name NVARCHAR(150) NOT NULL,
        module NVARCHAR(100) NOT NULL,
        description NVARCHAR(255) NULL
    );
END
GO

IF OBJECT_ID('role_permissions', 'U') IS NULL
BEGIN
    CREATE TABLE role_permissions (
        role_id INT NOT NULL,
        permission_id INT NOT NULL,

        CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, permission_id),
        CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id),
        CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id)
    );
END
GO

IF OBJECT_ID('users', 'U') IS NULL
BEGIN
    CREATE TABLE users (
        id INT IDENTITY(1,1) PRIMARY KEY,
        role_id INT NOT NULL,
        username NVARCHAR(80) NOT NULL UNIQUE,
        password_hash NVARCHAR(255) NOT NULL,
        full_name NVARCHAR(150) NOT NULL,
        email NVARCHAR(150) NULL,
        is_active BIT NOT NULL DEFAULT 1,
        last_login_at DATETIME2 NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NULL,

        CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id)
    );

    CREATE INDEX ix_users_role_id ON users(role_id);
END
GO


/* =========================
   CONFIGURACIÓN
   ========================= */

IF OBJECT_ID('park_config', 'U') IS NULL
BEGIN
    CREATE TABLE park_config (
        id INT IDENTITY(1,1) PRIMARY KEY,
        park_name NVARCHAR(150) NOT NULL,
        park_subtitle NVARCHAR(150) NULL,
        sigap_code NVARCHAR(80) NULL,
        department NVARCHAR(100) NULL,
        municipality NVARCHAR(100) NULL,
        address NVARCHAR(255) NULL,
        phone NVARCHAR(50) NULL,
        email NVARCHAR(150) NULL,
        logo_url NVARCHAR(500) NULL,
        system_lan_url NVARCHAR(255) NULL,
        max_capacity INT NOT NULL DEFAULT 150,
        sidebar_color_hex NVARCHAR(7) NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NULL,

        CONSTRAINT CK_park_config_sidebar_color_hex CHECK (
            sidebar_color_hex IS NULL OR (
                LEN(sidebar_color_hex) = 7
                AND LEFT(sidebar_color_hex, 1) = '#'
                AND SUBSTRING(sidebar_color_hex, 2, 6) NOT LIKE '%[^0-9A-Fa-f]%'
            )
        )
    );
END
GO

IF OBJECT_ID('services', 'U') IS NULL
BEGIN
    CREATE TABLE services (
        id INT IDENTITY(1,1) PRIMARY KEY,
        code NVARCHAR(80) NOT NULL UNIQUE,
        name NVARCHAR(120) NOT NULL,
        is_enabled BIT NOT NULL DEFAULT 1
    );
END
GO


/* =========================
   CATÁLOGOS
   ========================= */

IF OBJECT_ID('countries', 'U') IS NULL
BEGIN
    CREATE TABLE countries (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        nationality NVARCHAR(120) NULL,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('departments', 'U') IS NULL
BEGIN
    CREATE TABLE departments (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('municipalities', 'U') IS NULL
BEGIN
    CREATE TABLE municipalities (
        id INT IDENTITY(1,1) PRIMARY KEY,
        department_id INT NOT NULL,
        name NVARCHAR(120) NOT NULL,
        is_active BIT NOT NULL DEFAULT 1,

        CONSTRAINT fk_municipalities_department FOREIGN KEY (department_id) REFERENCES departments(id),
        CONSTRAINT uq_municipality_department UNIQUE (department_id, name)
    );

    CREATE INDEX ix_municipalities_department_id ON municipalities(department_id);
END
GO

IF OBJECT_ID('visitor_categories', 'U') IS NULL
BEGIN
    CREATE TABLE visitor_categories (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('vehicle_types', 'U') IS NULL
BEGIN
    CREATE TABLE vehicle_types (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('lodging_types', 'U') IS NULL
BEGIN
    CREATE TABLE lodging_types (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('payment_methods', 'U') IS NULL
BEGIN
    CREATE TABLE payment_methods (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('financial_concepts', 'U') IS NULL
BEGIN
    CREATE TABLE financial_concepts (
        id INT IDENTITY(1,1) PRIMARY KEY,
        type NVARCHAR(20) NOT NULL,
        name NVARCHAR(150) NOT NULL,
        is_active BIT NOT NULL DEFAULT 1,

        CONSTRAINT ck_financial_concepts_type CHECK (type IN ('INGRESO', 'EGRESO'))
    );
END
GO

IF OBJECT_ID('visit_reasons', 'U') IS NULL
BEGIN
    CREATE TABLE visit_reasons (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('visit_activities', 'U') IS NULL
BEGIN
    CREATE TABLE visit_activities (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('info_sources', 'U') IS NULL
BEGIN
    CREATE TABLE info_sources (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO

IF OBJECT_ID('travel_types', 'U') IS NULL
BEGIN
    CREATE TABLE travel_types (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(120) NOT NULL UNIQUE,
        is_active BIT NOT NULL DEFAULT 1
    );
END
GO


/* =========================
   TARIFAS
   ========================= */

IF OBJECT_ID('tariffs', 'U') IS NULL
BEGIN
    CREATE TABLE tariffs (
        id INT IDENTITY(1,1) PRIMARY KEY,
        service_id INT NOT NULL,
        visitor_category_id INT NULL,
        vehicle_type_id INT NULL,
        lodging_type_id INT NULL,
        name NVARCHAR(150) NOT NULL,
        applies_to NVARCHAR(50) NOT NULL,
        amount DECIMAL(12,2) NOT NULL,
        is_foreign BIT NULL,
        is_active BIT NOT NULL DEFAULT 1,
        valid_from DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        valid_to DATE NULL,

        CONSTRAINT fk_tariffs_service FOREIGN KEY (service_id) REFERENCES services(id),
        CONSTRAINT fk_tariffs_visitor_category FOREIGN KEY (visitor_category_id) REFERENCES visitor_categories(id),
        CONSTRAINT fk_tariffs_vehicle_type FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id),
        CONSTRAINT fk_tariffs_lodging_type FOREIGN KEY (lodging_type_id) REFERENCES lodging_types(id),
        CONSTRAINT ck_tariffs_applies_to CHECK (applies_to IN ('VISITANTE', 'VEHICULO', 'HOSPEDAJE', 'SERVICIO'))
    );

    CREATE INDEX ix_tariffs_service_id ON tariffs(service_id);
    CREATE INDEX ix_tariffs_active ON tariffs(is_active);
END
GO


/* =========================
   VISITANTES
   ========================= */

IF OBJECT_ID('visitor_records', 'U') IS NULL
BEGIN
    CREATE TABLE visitor_records (
        id INT IDENTITY(1,1) PRIMARY KEY,
        ticket_number NVARCHAR(50) NOT NULL UNIQUE,

        record_date DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        check_in_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        check_out_at DATETIME2 NULL,

        country_id INT NULL,
        department_id INT NULL,
        municipality_id INT NULL,
        info_source_id INT NULL,
        travel_type_id INT NULL,

        nationality NVARCHAR(120) NULL,
        identification_type NVARCHAR(50) NULL,
        identification_number NVARCHAR(80) NULL,
        full_name NVARCHAR(150) NULL,
        email NVARCHAR(150) NULL,

        gender NVARCHAR(20) NULL,
        age_range NVARCHAR(20) NULL,

        visitor_category_id INT NOT NULL,
        quantity INT NOT NULL DEFAULT 1,
        tariff_id INT NULL,
        applied_rate DECIMAL(12,2) NOT NULL,
        total_amount DECIMAL(12,2) NOT NULL,

        visit_type NVARCHAR(50) NULL,
        observations NVARCHAR(500) NULL,

        source NVARCHAR(50) NOT NULL DEFAULT 'MANUAL',
        external_event_id NVARCHAR(100) NULL,

        created_by_user_id INT NOT NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NULL,

        CONSTRAINT fk_visitor_country FOREIGN KEY (country_id) REFERENCES countries(id),
        CONSTRAINT fk_visitor_department FOREIGN KEY (department_id) REFERENCES departments(id),
        CONSTRAINT fk_visitor_municipality FOREIGN KEY (municipality_id) REFERENCES municipalities(id),
        CONSTRAINT fk_visitor_info_source FOREIGN KEY (info_source_id) REFERENCES info_sources(id),
        CONSTRAINT fk_visitor_travel_type FOREIGN KEY (travel_type_id) REFERENCES travel_types(id),
        CONSTRAINT fk_visitor_category FOREIGN KEY (visitor_category_id) REFERENCES visitor_categories(id),
        CONSTRAINT fk_visitor_tariff FOREIGN KEY (tariff_id) REFERENCES tariffs(id),
        CONSTRAINT fk_visitor_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id),
        CONSTRAINT ck_visitor_source CHECK (source IN ('MANUAL', 'MOLINETE', 'IMPORTADO'))
    );

    CREATE INDEX ix_visitor_records_date ON visitor_records(record_date);
    CREATE INDEX ix_visitor_records_check_out ON visitor_records(check_out_at);
    CREATE INDEX ix_visitor_records_created_by ON visitor_records(created_by_user_id);
END
GO

IF OBJECT_ID('visitor_record_reasons', 'U') IS NULL
BEGIN
    CREATE TABLE visitor_record_reasons (
        visitor_record_id INT NOT NULL,
        visit_reason_id INT NOT NULL,

        CONSTRAINT pk_visitor_record_reasons PRIMARY KEY (visitor_record_id, visit_reason_id),
        CONSTRAINT fk_vrr_record FOREIGN KEY (visitor_record_id) REFERENCES visitor_records(id),
        CONSTRAINT fk_vrr_reason FOREIGN KEY (visit_reason_id) REFERENCES visit_reasons(id)
    );
END
GO

IF OBJECT_ID('visitor_record_activities', 'U') IS NULL
BEGIN
    CREATE TABLE visitor_record_activities (
        visitor_record_id INT NOT NULL,
        visit_activity_id INT NOT NULL,

        CONSTRAINT pk_visitor_record_activities PRIMARY KEY (visitor_record_id, visit_activity_id),
        CONSTRAINT fk_vra_record FOREIGN KEY (visitor_record_id) REFERENCES visitor_records(id),
        CONSTRAINT fk_vra_activity FOREIGN KEY (visit_activity_id) REFERENCES visit_activities(id)
    );
END
GO


/* =========================
   VEHÍCULOS
   ========================= */

IF OBJECT_ID('vehicle_records', 'U') IS NULL
BEGIN
    CREATE TABLE vehicle_records (
        id INT IDENTITY(1,1) PRIMARY KEY,
        vehicle_type_id INT NOT NULL,
        visitor_record_id INT NULL,

        plate_number NVARCHAR(30) NULL,
        check_in_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        check_out_at DATETIME2 NULL,

        tariff_id INT NULL,
        applied_rate DECIMAL(12,2) NOT NULL,
        total_amount DECIMAL(12,2) NOT NULL,

        exit_enabled BIT NOT NULL DEFAULT 0,

        source NVARCHAR(50) NOT NULL DEFAULT 'MANUAL',
        external_event_id NVARCHAR(100) NULL,

        observations NVARCHAR(500) NULL,
        created_by_user_id INT NOT NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NULL,

        CONSTRAINT fk_vehicle_type FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id),
        CONSTRAINT fk_vehicle_visitor_record FOREIGN KEY (visitor_record_id) REFERENCES visitor_records(id),
        CONSTRAINT fk_vehicle_tariff FOREIGN KEY (tariff_id) REFERENCES tariffs(id),
        CONSTRAINT fk_vehicle_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id),
        CONSTRAINT ck_vehicle_source CHECK (source IN ('MANUAL', 'BARRERA', 'IMPORTADO'))
    );

    CREATE INDEX ix_vehicle_records_plate ON vehicle_records(plate_number);
    CREATE INDEX ix_vehicle_records_check_out ON vehicle_records(check_out_at);
END
GO


/* =========================
   HOSPEDAJE
   ========================= */

IF OBJECT_ID('lodging_records', 'U') IS NULL
BEGIN
    CREATE TABLE lodging_records (
        id INT IDENTITY(1,1) PRIMARY KEY,
        lodging_type_id INT NOT NULL,
        record_date DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        nights INT NOT NULL,
        guests INT NOT NULL,

        tariff_id INT NULL,
        applied_rate DECIMAL(12,2) NOT NULL,
        total_amount DECIMAL(12,2) NOT NULL,

        observations NVARCHAR(500) NULL,
        created_by_user_id INT NOT NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NULL,

        CONSTRAINT fk_lodging_type FOREIGN KEY (lodging_type_id) REFERENCES lodging_types(id),
        CONSTRAINT fk_lodging_tariff FOREIGN KEY (tariff_id) REFERENCES tariffs(id),
        CONSTRAINT fk_lodging_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id)
    );

    CREATE INDEX ix_lodging_records_date ON lodging_records(record_date);
END
GO


/* =========================
   RECIBOS
   ========================= */

IF OBJECT_ID('receipts', 'U') IS NULL
BEGIN
    CREATE TABLE receipts (
        id INT IDENTITY(1,1) PRIMARY KEY,
        receipt_number NVARCHAR(50) NOT NULL UNIQUE,
        receipt_date DATETIME2 NOT NULL DEFAULT SYSDATETIME(),

        contributor_name NVARCHAR(150) NULL,
        contributor_document NVARCHAR(80) NULL,
        contributor_address NVARCHAR(255) NULL,

        origin_type NVARCHAR(50) NOT NULL,
        origin_id INT NULL,

        payment_method_id INT NOT NULL,
        subtotal DECIMAL(12,2) NULL,
        discount_type NVARCHAR(20) NULL,
        discount_percentage DECIMAL(5,2) NULL,
        discount_amount DECIMAL(12,2) NULL DEFAULT 0,
        discount_reason NVARCHAR(500) NULL,
        total DECIMAL(12,2) NOT NULL,
        amount_received DECIMAL(12,2) NULL,
        change_amount DECIMAL(12,2) NULL,
        payment_reference NVARCHAR(150) NULL,

        status NVARCHAR(30) NOT NULL DEFAULT 'ACTIVO',

        sicoin_reference NVARCHAR(150) NULL,
        sicoin_error NVARCHAR(500) NULL,

        created_by_user_id INT NOT NULL,
        cancelled_by_user_id INT NULL,
        cancelled_at DATETIME2 NULL,
        cancel_reason NVARCHAR(500) NULL,

        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NULL,

        CONSTRAINT fk_receipts_payment_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
        CONSTRAINT fk_receipts_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id),
        CONSTRAINT fk_receipts_cancelled_by FOREIGN KEY (cancelled_by_user_id) REFERENCES users(id),

        CONSTRAINT ck_receipts_origin_type CHECK (origin_type IN ('VISITANTE', 'VEHICULO', 'HOSPEDAJE', 'SERVICIO_GENERAL', 'MOVIMIENTO_MANUAL')),
        CONSTRAINT ck_receipts_status CHECK (status IN ('ACTIVO', 'ANULADO', 'PENDIENTE_SICOIN', 'ENVIADO_SICOIN', 'ERROR_SICOIN'))
    );

    CREATE INDEX ix_receipts_date ON receipts(receipt_date);
    CREATE INDEX ix_receipts_status ON receipts(status);
END
GO

IF OBJECT_ID('receipt_lines', 'U') IS NULL
BEGIN
    CREATE TABLE receipt_lines (
        id INT IDENTITY(1,1) PRIMARY KEY,
        receipt_id INT NOT NULL,
        description NVARCHAR(255) NOT NULL,
        quantity DECIMAL(12,2) NOT NULL DEFAULT 1,
        unit_price DECIMAL(12,2) NOT NULL,
        total DECIMAL(12,2) NOT NULL,

        CONSTRAINT fk_receipt_lines_receipt FOREIGN KEY (receipt_id) REFERENCES receipts(id)
    );

    CREATE INDEX ix_receipt_lines_receipt_id ON receipt_lines(receipt_id);
END
GO


/* =========================
   CAJA
   ========================= */

IF OBJECT_ID('cash_closures', 'U') IS NULL
BEGIN
    CREATE TABLE cash_closures (
        id INT IDENTITY(1,1) PRIMARY KEY,
        closure_number NVARCHAR(50) NOT NULL UNIQUE,
        closed_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),

        total_income DECIMAL(12,2) NOT NULL DEFAULT 0,
        total_expense DECIMAL(12,2) NOT NULL DEFAULT 0,
        total_net DECIMAL(12,2) NOT NULL DEFAULT 0,

        observations NVARCHAR(500) NULL,
        closed_by_user_id INT NOT NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),

        CONSTRAINT fk_cash_closures_closed_by FOREIGN KEY (closed_by_user_id) REFERENCES users(id)
    );
END
GO

IF OBJECT_ID('financial_movements', 'U') IS NULL
BEGIN
    CREATE TABLE financial_movements (
        id INT IDENTITY(1,1) PRIMARY KEY,

        movement_type NVARCHAR(20) NOT NULL,
        concept_id INT NOT NULL,
        payment_method_id INT NOT NULL,

        origin_type NVARCHAR(50) NOT NULL,
        origin_id INT NULL,
        receipt_id INT NULL,

        movement_date DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        amount DECIMAL(12,2) NOT NULL,
        description NVARCHAR(500) NULL,

        status NVARCHAR(30) NOT NULL DEFAULT 'ACTIVO',
        cash_closure_id INT NULL,

        created_by_user_id INT NOT NULL,
        cancelled_by_user_id INT NULL,
        cancelled_at DATETIME2 NULL,
        cancel_reason NVARCHAR(500) NULL,

        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        updated_at DATETIME2 NULL,

        CONSTRAINT fk_movements_concept FOREIGN KEY (concept_id) REFERENCES financial_concepts(id),
        CONSTRAINT fk_movements_payment_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
        CONSTRAINT fk_movements_receipt FOREIGN KEY (receipt_id) REFERENCES receipts(id),
        CONSTRAINT fk_movements_cash_closure FOREIGN KEY (cash_closure_id) REFERENCES cash_closures(id),
        CONSTRAINT fk_movements_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id),
        CONSTRAINT fk_movements_cancelled_by FOREIGN KEY (cancelled_by_user_id) REFERENCES users(id),

        CONSTRAINT ck_movements_type CHECK (movement_type IN ('INGRESO', 'EGRESO')),
        CONSTRAINT ck_movements_status CHECK (status IN ('ACTIVO', 'ANULADO')),
        CONSTRAINT ck_movements_origin_type CHECK (origin_type IN ('VISITANTE', 'VEHICULO', 'HOSPEDAJE', 'SERVICIO_GENERAL', 'MOVIMIENTO_MANUAL'))
    );

    CREATE INDEX ix_financial_movements_date ON financial_movements(movement_date);
    CREATE INDEX ix_financial_movements_status ON financial_movements(status);
    CREATE INDEX ix_financial_movements_cash_closure ON financial_movements(cash_closure_id);
END
GO

IF OBJECT_ID('cash_closure_details', 'U') IS NULL
BEGIN
    CREATE TABLE cash_closure_details (
        id INT IDENTITY(1,1) PRIMARY KEY,
        cash_closure_id INT NOT NULL,
        detail_type NVARCHAR(50) NOT NULL,
        label NVARCHAR(150) NOT NULL,
        total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,

        CONSTRAINT fk_cash_closure_details_closure FOREIGN KEY (cash_closure_id) REFERENCES cash_closures(id),
        CONSTRAINT ck_cash_closure_details_type CHECK (detail_type IN ('MEDIO_PAGO', 'SERVICIO', 'CONCEPTO'))
    );
END
GO


/* =========================
   AUDITORÍA
   ========================= */

IF OBJECT_ID('audit_logs', 'U') IS NULL
BEGIN
    CREATE TABLE audit_logs (
        id INT IDENTITY(1,1) PRIMARY KEY,
        user_id INT NULL,
        action NVARCHAR(100) NOT NULL,
        entity_name NVARCHAR(100) NOT NULL,
        entity_id NVARCHAR(100) NULL,
        old_values NVARCHAR(MAX) NULL,
        new_values NVARCHAR(MAX) NULL,
        ip_address NVARCHAR(80) NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),

        CONSTRAINT fk_audit_logs_user FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE INDEX ix_audit_logs_user ON audit_logs(user_id);
    CREATE INDEX ix_audit_logs_entity ON audit_logs(entity_name, entity_id);
    CREATE INDEX ix_audit_logs_created_at ON audit_logs(created_at);
END
GO

/* ============================================================
   MIGRACIONES INCREMENTALES
   Columnas agregadas después de la creación inicial.
   Idempotentes: usan IF NOT EXISTS sobre sys.columns.
   ============================================================ */

-- receipts: columnas de descuento (agregadas en v2)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('receipts') AND name = 'subtotal')
    ALTER TABLE receipts ADD subtotal DECIMAL(12,2) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('receipts') AND name = 'discount_percentage')
    ALTER TABLE receipts ADD discount_percentage DECIMAL(5,2) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('receipts') AND name = 'discount_amount')
    ALTER TABLE receipts ADD discount_amount DECIMAL(12,2) NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('receipts') AND name = 'discount_reason')
    ALTER TABLE receipts ADD discount_reason NVARCHAR(500) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('receipts') AND name = 'discount_type')
    ALTER TABLE receipts ADD discount_type NVARCHAR(20) NULL;
GO

PRINT '02_schema.sql ejecutado correctamente.';
GO