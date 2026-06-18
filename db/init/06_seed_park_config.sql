PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* 06_seed_park_config.sql — SQLite version */
BEGIN TRANSACTION;

INSERT INTO park_config (
    park_name, park_subtitle, sigap_code, department, municipality, address,
    phone, email, logo_url, system_lan_url, max_capacity, sidebar_color_hex,
    ticket_version, ruv
)
SELECT
    'El Refugio del Quetzal',
    'Parque Regional Municipal',
    'PRM-SM-001',
    'San Marcos',
    'San Rafael Pie de la Cuesta',
    'Dirección pendiente de configurar',
    '+502 0000-0000',
    'info@parque.local',
    NULL,
    'http://parque.rm.local',
    150,
    '#1A3A2A',
    'v1.0',
    'PENDIENTE'
WHERE NOT EXISTS (SELECT 1 FROM park_config);

COMMIT;
