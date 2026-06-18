PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* 08_patch_park_config_sidebar_color_hex.sql — SQLite version
   Column already exists in 02_schema.sql. This remains as idempotent cleanup. */
BEGIN TRANSACTION;
UPDATE park_config
SET sidebar_color_hex = COALESCE(sidebar_color_hex, '#1A3A2A'),
    updated_at = COALESCE(updated_at, CURRENT_TIMESTAMP)
WHERE sidebar_color_hex IS NULL;
COMMIT;
