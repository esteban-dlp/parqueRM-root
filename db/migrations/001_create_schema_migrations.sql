PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   001_create_schema_migrations.sql
   SQLite version — creates migration tracking table.
   Safe to run multiple times (idempotent).
   ============================================================ */

CREATE TABLE IF NOT EXISTS schema_migrations (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    migration_name TEXT NOT NULL UNIQUE,
    checksum       TEXT NULL,
    applied_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
