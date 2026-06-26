PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   004_add_visitor_health_fields.sql
   Agrega 7 campos de salud a la tabla visitor_records
   para registrar condiciones médicas relevantes del visitante.

   IMPORTANTE: No ejecutar si la migración ya está registrada
   en schema_migrations. El script de docker-compose y el
   instalador verifican eso antes de correr este archivo.

   Manual usage on an existing deployment:
     sqlite3 /path/to/parquerm.db < 004_add_visitor_health_fields.sql
   ============================================================ */

ALTER TABLE visitor_records ADD COLUMN has_medication_allergy INTEGER NOT NULL DEFAULT 0;
ALTER TABLE visitor_records ADD COLUMN medication_allergy_detail TEXT NULL;
ALTER TABLE visitor_records ADD COLUMN has_diabetes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE visitor_records ADD COLUMN has_hypertension INTEGER NOT NULL DEFAULT 0;
ALTER TABLE visitor_records ADD COLUMN has_respiratory_disease INTEGER NOT NULL DEFAULT 0;
ALTER TABLE visitor_records ADD COLUMN has_animal_bite_allergy INTEGER NOT NULL DEFAULT 0;
ALTER TABLE visitor_records ADD COLUMN animal_bite_allergy_detail TEXT NULL;
