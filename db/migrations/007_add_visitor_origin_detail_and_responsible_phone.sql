PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   007_add_visitor_origin_detail_and_responsible_phone.sql
   Agrega 2 campos a la tabla visitor_records:
   - origin_detail: detalle de procedencia (estado, ciudad,
     provincia u otra referencia) cuando el país del visitante
     es distinto de Guatemala.
   - responsible_phone: teléfono del visitante responsable.

   IMPORTANTE: No ejecutar si la migración ya está registrada
   en schema_migrations. El script de docker-compose y el
   instalador verifican eso antes de correr este archivo.

   Manual usage on an existing deployment:
     sqlite3 /path/to/parquerm.db < 007_add_visitor_origin_detail_and_responsible_phone.sql
   ============================================================ */

ALTER TABLE visitor_records ADD COLUMN origin_detail TEXT NULL;
ALTER TABLE visitor_records ADD COLUMN responsible_phone TEXT NULL;
