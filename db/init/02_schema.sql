PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   02_schema.sql
   Estructura principal ParqueRM
   SQLite version
   ============================================================ */

/* =========================
   SEGURIDAD
   ========================= */

CREATE TABLE IF NOT EXISTS roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS permissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    module TEXT NOT NULL,
    description TEXT NULL
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id INTEGER NOT NULL,
    permission_id INTEGER NOT NULL,
    CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id),
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id)
);

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    role_id INTEGER NOT NULL,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    last_login_at TEXT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
    deleted_at TEXT NULL,
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id)
);
CREATE INDEX IF NOT EXISTS ix_users_role_id ON users(role_id);

/* =========================
   CONFIGURACIÓN
   ========================= */

CREATE TABLE IF NOT EXISTS park_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    park_name TEXT NOT NULL,
    park_subtitle TEXT NULL,
    sigap_code TEXT NULL,
    department TEXT NULL,
    municipality TEXT NULL,
    address TEXT NULL,
    phone TEXT NULL,
    email TEXT NULL,
    logo_url TEXT NULL,
    system_lan_url TEXT NULL,
    max_capacity INTEGER NOT NULL DEFAULT 150,
    sidebar_color_hex TEXT NULL,
    ticket_version TEXT NULL,
    ruv TEXT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
    CONSTRAINT CK_park_config_sidebar_color_hex CHECK (
        sidebar_color_hex IS NULL OR (
            length(sidebar_color_hex) = 7 AND substr(sidebar_color_hex, 1, 1) = '#'
        )
    )
);

CREATE TABLE IF NOT EXISTS services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    is_enabled INTEGER NOT NULL DEFAULT 1
);

/* =========================
   CATÁLOGOS
   ========================= */

CREATE TABLE IF NOT EXISTS countries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    nationality TEXT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS departments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS municipalities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    department_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL,
    CONSTRAINT fk_municipalities_department FOREIGN KEY (department_id) REFERENCES departments(id),
    CONSTRAINT uq_municipality_department UNIQUE (department_id, name)
);
CREATE INDEX IF NOT EXISTS ix_municipalities_department_id ON municipalities(department_id);

CREATE TABLE IF NOT EXISTS visitor_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS vehicle_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS lodging_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS payment_methods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS financial_concepts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL,
    CONSTRAINT uq_financial_concepts_type_name UNIQUE (type, name),
    CONSTRAINT ck_financial_concepts_type CHECK (type IN ('INGRESO', 'EGRESO'))
);

CREATE TABLE IF NOT EXISTS visit_reasons (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS visit_activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS info_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

CREATE TABLE IF NOT EXISTS travel_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL
);

/* =========================
   TARIFAS
   ========================= */

CREATE TABLE IF NOT EXISTS tariffs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service_id INTEGER NOT NULL,
    visitor_category_id INTEGER NULL,
    vehicle_type_id INTEGER NULL,
    lodging_type_id INTEGER NULL,
    name TEXT NOT NULL,
    applies_to TEXT NOT NULL,
    amount_local NUMERIC NOT NULL,
    amount_foreign NUMERIC NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1,
    valid_from TEXT NOT NULL DEFAULT (date('now','-6 hours')),
    valid_to TEXT NULL,
    deleted_at TEXT NULL,
    CONSTRAINT fk_tariffs_service FOREIGN KEY (service_id) REFERENCES services(id),
    CONSTRAINT fk_tariffs_visitor_category FOREIGN KEY (visitor_category_id) REFERENCES visitor_categories(id),
    CONSTRAINT fk_tariffs_vehicle_type FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id),
    CONSTRAINT fk_tariffs_lodging_type FOREIGN KEY (lodging_type_id) REFERENCES lodging_types(id),
    CONSTRAINT ck_tariffs_applies_to CHECK (applies_to IN ('VISITANTE', 'VEHICULO', 'HOSPEDAJE', 'SERVICIO'))
);
CREATE INDEX IF NOT EXISTS ix_tariffs_service_id ON tariffs(service_id);
CREATE INDEX IF NOT EXISTS ix_tariffs_active ON tariffs(is_active);

/* =========================
   VISITANTES
   ========================= */

CREATE TABLE IF NOT EXISTS visitor_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_number TEXT NOT NULL UNIQUE,
    record_date TEXT NOT NULL DEFAULT (date('now','-6 hours')),
    check_in_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    check_out_at TEXT NULL,
    country_id INTEGER NULL,
    department_id INTEGER NULL,
    municipality_id INTEGER NULL,
    info_source_id INTEGER NULL,
    travel_type_id INTEGER NULL,
    nationality TEXT NULL,
    identification_type TEXT NULL,
    identification_number TEXT NULL,
    full_name TEXT NULL,
    email TEXT NULL,
    gender TEXT NULL,
    age_range TEXT NULL,
    visitor_category_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    tariff_id INTEGER NULL,
    applied_rate NUMERIC NOT NULL,
    total_amount NUMERIC NOT NULL,
    visit_type TEXT NULL,
    observations TEXT NULL,
    is_foreign INTEGER NOT NULL DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'MANUAL',
    external_event_id TEXT NULL,
    created_by_user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
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
CREATE INDEX IF NOT EXISTS ix_visitor_records_date ON visitor_records(record_date);
CREATE INDEX IF NOT EXISTS ix_visitor_records_check_out ON visitor_records(check_out_at);
CREATE INDEX IF NOT EXISTS ix_visitor_records_created_by ON visitor_records(created_by_user_id);

CREATE TABLE IF NOT EXISTS visitor_record_reasons (
    visitor_record_id INTEGER NOT NULL,
    visit_reason_id INTEGER NOT NULL,
    CONSTRAINT pk_visitor_record_reasons PRIMARY KEY (visitor_record_id, visit_reason_id),
    CONSTRAINT fk_vrr_record FOREIGN KEY (visitor_record_id) REFERENCES visitor_records(id),
    CONSTRAINT fk_vrr_reason FOREIGN KEY (visit_reason_id) REFERENCES visit_reasons(id)
);

CREATE TABLE IF NOT EXISTS visitor_record_activities (
    visitor_record_id INTEGER NOT NULL,
    visit_activity_id INTEGER NOT NULL,
    CONSTRAINT pk_visitor_record_activities PRIMARY KEY (visitor_record_id, visit_activity_id),
    CONSTRAINT fk_vra_record FOREIGN KEY (visitor_record_id) REFERENCES visitor_records(id),
    CONSTRAINT fk_vra_activity FOREIGN KEY (visit_activity_id) REFERENCES visit_activities(id)
);

CREATE TABLE IF NOT EXISTS visitor_record_companions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    visitor_record_id INTEGER NOT NULL,
    visitor_category_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    applied_rate NUMERIC NOT NULL,
    total_amount NUMERIC NOT NULL,
    is_foreign INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vrc_visitor_record FOREIGN KEY (visitor_record_id) REFERENCES visitor_records(id) ON DELETE CASCADE,
    CONSTRAINT fk_vrc_visitor_category FOREIGN KEY (visitor_category_id) REFERENCES visitor_categories(id)
);
CREATE INDEX IF NOT EXISTS ix_vrc_visitor_record_id ON visitor_record_companions(visitor_record_id);

/* =========================
   VEHÍCULOS
   ========================= */

CREATE TABLE IF NOT EXISTS vehicle_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_type_id INTEGER NOT NULL,
    visitor_record_id INTEGER NULL,
    plate_number TEXT NULL,
    check_in_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    check_out_at TEXT NULL,
    tariff_id INTEGER NULL,
    applied_rate NUMERIC NOT NULL,
    total_amount NUMERIC NOT NULL,
    exit_enabled INTEGER NOT NULL DEFAULT 0,
    is_foreign INTEGER NOT NULL DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'MANUAL',
    external_event_id TEXT NULL,
    observations TEXT NULL,
    created_by_user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
    CONSTRAINT fk_vehicle_type FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id),
    CONSTRAINT fk_vehicle_visitor_record FOREIGN KEY (visitor_record_id) REFERENCES visitor_records(id),
    CONSTRAINT fk_vehicle_tariff FOREIGN KEY (tariff_id) REFERENCES tariffs(id),
    CONSTRAINT fk_vehicle_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id),
    CONSTRAINT ck_vehicle_source CHECK (source IN ('MANUAL', 'BARRERA', 'IMPORTADO'))
);
CREATE INDEX IF NOT EXISTS ix_vehicle_records_plate ON vehicle_records(plate_number);
CREATE INDEX IF NOT EXISTS ix_vehicle_records_check_out ON vehicle_records(check_out_at);

/* =========================
   HOSPEDAJE
   ========================= */

CREATE TABLE IF NOT EXISTS lodging_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lodging_type_id INTEGER NOT NULL,
    record_date TEXT NOT NULL DEFAULT (date('now','-6 hours')),
    nights INTEGER NOT NULL,
    guests INTEGER NOT NULL,
    tariff_id INTEGER NULL,
    applied_rate NUMERIC NOT NULL,
    total_amount NUMERIC NOT NULL,
    is_foreign INTEGER NOT NULL DEFAULT 0,
    observations TEXT NULL,
    created_by_user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
    CONSTRAINT fk_lodging_type FOREIGN KEY (lodging_type_id) REFERENCES lodging_types(id),
    CONSTRAINT fk_lodging_tariff FOREIGN KEY (tariff_id) REFERENCES tariffs(id),
    CONSTRAINT fk_lodging_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS ix_lodging_records_date ON lodging_records(record_date);

/* =========================
   RECIBOS
   ========================= */

CREATE TABLE IF NOT EXISTS receipts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    receipt_number TEXT NOT NULL UNIQUE,
    receipt_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    contributor_name TEXT NULL,
    contributor_document TEXT NULL,
    contributor_address TEXT NULL,
    origin_type TEXT NOT NULL,
    origin_id INTEGER NULL,
    payment_method_id INTEGER NOT NULL,
    subtotal NUMERIC NULL,
    discount_type TEXT NULL,
    discount_percentage NUMERIC NULL,
    discount_amount NUMERIC NULL DEFAULT 0,
    discount_reason TEXT NULL,
    total NUMERIC NOT NULL,
    amount_received NUMERIC NULL,
    change_amount NUMERIC NULL,
    payment_reference TEXT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVO',
    sicoin_reference TEXT NULL,
    sicoin_error TEXT NULL,
    created_by_user_id INTEGER NOT NULL,
    cancelled_by_user_id INTEGER NULL,
    cancelled_at TEXT NULL,
    cancel_reason TEXT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
    CONSTRAINT fk_receipts_payment_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
    CONSTRAINT fk_receipts_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id),
    CONSTRAINT fk_receipts_cancelled_by FOREIGN KEY (cancelled_by_user_id) REFERENCES users(id),
    CONSTRAINT ck_receipts_origin_type CHECK (origin_type IN ('VISITANTE', 'VEHICULO', 'HOSPEDAJE', 'SERVICIO_GENERAL', 'MOVIMIENTO_MANUAL')),
    CONSTRAINT ck_receipts_status CHECK (status IN ('ACTIVO', 'ANULADO', 'PENDIENTE_SICOIN', 'ENVIADO_SICOIN', 'ERROR_SICOIN'))
);
CREATE INDEX IF NOT EXISTS ix_receipts_date ON receipts(receipt_date);
CREATE INDEX IF NOT EXISTS ix_receipts_status ON receipts(status);

CREATE TABLE IF NOT EXISTS receipt_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    receipt_id INTEGER NOT NULL,
    concept_id INTEGER NULL,
    origin_type TEXT NULL,
    origin_id INTEGER NULL,
    description TEXT NOT NULL,
    quantity NUMERIC NOT NULL DEFAULT 1,
    unit_price NUMERIC NOT NULL,
    total NUMERIC NOT NULL,
    CONSTRAINT fk_receipt_lines_receipt FOREIGN KEY (receipt_id) REFERENCES receipts(id),
    CONSTRAINT fk_receipt_lines_concept FOREIGN KEY (concept_id) REFERENCES financial_concepts(id)
);
CREATE INDEX IF NOT EXISTS ix_receipt_lines_receipt_id ON receipt_lines(receipt_id);
CREATE INDEX IF NOT EXISTS ix_receipt_lines_origin ON receipt_lines(origin_type, origin_id);
CREATE INDEX IF NOT EXISTS ix_receipt_lines_concept_id ON receipt_lines(concept_id);

/* =========================
   CAJA
   ========================= */

CREATE TABLE IF NOT EXISTS cash_closures (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    closure_number TEXT NOT NULL UNIQUE,
    closed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_income NUMERIC NOT NULL DEFAULT 0,
    total_expense NUMERIC NOT NULL DEFAULT 0,
    total_net NUMERIC NOT NULL DEFAULT 0,
    observations TEXT NULL,
    closed_by_user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cash_closures_closed_by FOREIGN KEY (closed_by_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS financial_movements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    movement_type TEXT NOT NULL,
    concept_id INTEGER NOT NULL,
    payment_method_id INTEGER NOT NULL,
    origin_type TEXT NOT NULL,
    origin_id INTEGER NULL,
    receipt_id INTEGER NULL,
    movement_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount NUMERIC NOT NULL,
    description TEXT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVO',
    cash_closure_id INTEGER NULL,
    created_by_user_id INTEGER NOT NULL,
    cancelled_by_user_id INTEGER NULL,
    cancelled_at TEXT NULL,
    cancel_reason TEXT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
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
CREATE INDEX IF NOT EXISTS ix_financial_movements_date ON financial_movements(movement_date);
CREATE INDEX IF NOT EXISTS ix_financial_movements_status ON financial_movements(status);
CREATE INDEX IF NOT EXISTS ix_financial_movements_cash_closure ON financial_movements(cash_closure_id);

CREATE TABLE IF NOT EXISTS cash_closure_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cash_closure_id INTEGER NOT NULL,
    detail_type TEXT NOT NULL,
    label TEXT NOT NULL,
    total_amount NUMERIC NOT NULL DEFAULT 0,
    CONSTRAINT fk_cash_closure_details_closure FOREIGN KEY (cash_closure_id) REFERENCES cash_closures(id),
    CONSTRAINT ck_cash_closure_details_type CHECK (detail_type IN ('MEDIO_PAGO', 'SERVICIO', 'CONCEPTO'))
);

/* =========================
   ENCUESTAS DE SATISFACCIÓN
   ========================= */

CREATE TABLE IF NOT EXISTS survey_questions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    text TEXT NOT NULL,
    answer_type TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NULL,
    CONSTRAINT ck_survey_questions_answer_type CHECK (answer_type IN ('SCALE_1_5', 'SCALE_1_10', 'EMOJI'))
);
CREATE INDEX IF NOT EXISTS ix_survey_questions_active ON survey_questions(is_active, display_order);

/* Encuesta anónima: no guarda nombre, DPI, visitante ni ningún dato personal. */
CREATE TABLE IF NOT EXISTS survey_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    submitted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    general_comment TEXT NULL
);
CREATE INDEX IF NOT EXISTS ix_survey_responses_submitted_at ON survey_responses(submitted_at);

CREATE TABLE IF NOT EXISTS survey_answers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    survey_response_id INTEGER NOT NULL,
    survey_question_id INTEGER NOT NULL,
    value INTEGER NOT NULL,
    CONSTRAINT fk_survey_answers_response FOREIGN KEY (survey_response_id) REFERENCES survey_responses(id),
    CONSTRAINT fk_survey_answers_question FOREIGN KEY (survey_question_id) REFERENCES survey_questions(id)
);
CREATE INDEX IF NOT EXISTS ix_survey_answers_response ON survey_answers(survey_response_id);
CREATE INDEX IF NOT EXISTS ix_survey_answers_question ON survey_answers(survey_question_id);

/* =========================
   AUDITORÍA
   ========================= */

CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NULL,
    action TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    entity_id TEXT NULL,
    old_values TEXT NULL,
    new_values TEXT NULL,
    ip_address TEXT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS ix_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS ix_audit_logs_entity ON audit_logs(entity_name, entity_id);
CREATE INDEX IF NOT EXISTS ix_audit_logs_created_at ON audit_logs(created_at);
