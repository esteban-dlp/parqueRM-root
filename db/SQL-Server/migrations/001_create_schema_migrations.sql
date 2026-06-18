/* ============================================================
   001_create_schema_migrations.sql
   Creates the migration tracking table.
   Safe to run multiple times (idempotent).
   ============================================================ */
USE ParqueRM;
GO

IF OBJECT_ID('schema_migrations', 'U') IS NULL
BEGIN
    CREATE TABLE schema_migrations (
        id             INT IDENTITY(1,1) PRIMARY KEY,
        migration_name NVARCHAR(255) NOT NULL UNIQUE,
        checksum       NVARCHAR(128) NULL,
        applied_at     DATETIME2    NOT NULL DEFAULT SYSDATETIME()
    );
    PRINT 'Created schema_migrations table.';
END
ELSE
BEGIN
    PRINT 'schema_migrations already exists — skipped.';
END
GO
