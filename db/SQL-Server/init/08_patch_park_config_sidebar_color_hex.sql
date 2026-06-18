USE ParqueRM;
GO

/* ============================================================
   08_patch_park_config_sidebar_color_hex.sql
   Patch idempotente: agrega sidebar_color_hex a park_config
   si no existe. Se puede ejecutar sobre DB nueva o existente.
   ============================================================ */

SET NOCOUNT ON;
GO

-- 1. Agregar la columna si no existe
IF COL_LENGTH('dbo.park_config', 'sidebar_color_hex') IS NULL
BEGIN
    ALTER TABLE dbo.park_config
        ADD sidebar_color_hex NVARCHAR(7) NOT NULL
            CONSTRAINT DF_park_config_sidebar_color_hex DEFAULT '#1A3A2A';
    PRINT 'Columna sidebar_color_hex agregada.';
END
ELSE
BEGIN
    PRINT 'Columna sidebar_color_hex ya existe — omitiendo ADD.';
END
GO

-- 2. Si la columna existe pero es nullable, rellenar NULLs y cambiarla a NOT NULL
IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.park_config')
      AND name = 'sidebar_color_hex'
      AND is_nullable = 1
)
BEGIN
    UPDATE dbo.park_config
    SET sidebar_color_hex = '#1A3A2A'
    WHERE sidebar_color_hex IS NULL;

    ALTER TABLE dbo.park_config
        ALTER COLUMN sidebar_color_hex NVARCHAR(7) NOT NULL;
    PRINT 'Columna sidebar_color_hex convertida a NOT NULL.';
END
GO

-- 3. Agregar CHECK constraint si no existe
IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_park_config_sidebar_color_hex'
      AND parent_object_id = OBJECT_ID('dbo.park_config')
)
BEGIN
    ALTER TABLE dbo.park_config
        ADD CONSTRAINT CK_park_config_sidebar_color_hex CHECK (
            LEN(sidebar_color_hex) = 7
            AND LEFT(sidebar_color_hex, 1) = '#'
            AND SUBSTRING(sidebar_color_hex, 2, 6) NOT LIKE '%[^0-9A-Fa-f]%'
        );
    PRINT 'Constraint CK_park_config_sidebar_color_hex agregada.';
END
ELSE
BEGIN
    PRINT 'Constraint CK_park_config_sidebar_color_hex ya existe — omitiendo.';
END
GO

PRINT '08_patch_park_config_sidebar_color_hex.sql ejecutado correctamente.';
GO
