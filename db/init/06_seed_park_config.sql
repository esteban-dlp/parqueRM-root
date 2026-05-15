USE ParqueRM;
GO

/* ============================================================
   06_seed_park_config.sql
   Configuración inicial del parque
   SQL Server
   ============================================================ */

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM park_config)
BEGIN
    INSERT INTO park_config (
        park_name,
        park_subtitle,
        sigap_code,
        department,
        municipality,
        address,
        phone,
        email,
        logo_url,
        system_lan_url,
        max_capacity,
        sidebar_color_hex
    )
    VALUES (
        'El Refugio del Quetzal',
        'Parque Regional Municipal',
        'PRM-SM-001',
        'San Marcos',
        'San Rafael Pie de la Cuesta',
        'Dirección pendiente de configurar',
        '+502 0000-0000',
        'info@parque.local',
        NULL,
        'http://192.168.1.10',
        150,
        '#1A3A2A'
    );
END
GO

PRINT '06_seed_park_config.sql ejecutado correctamente.';
GO