PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   006_add_receipt_line_origin_fields.sql
   Adds per-line concept/origin metadata to receipts so a single
   ticket can close multiple operational records.

   The installer migration runner skips ALTER TABLE ADD COLUMN
   statements when the column already exists.
   ============================================================ */

ALTER TABLE receipt_lines ADD COLUMN concept_id INTEGER NULL;
ALTER TABLE receipt_lines ADD COLUMN origin_type TEXT NULL;
ALTER TABLE receipt_lines ADD COLUMN origin_id INTEGER NULL;

CREATE INDEX IF NOT EXISTS ix_receipt_lines_origin
    ON receipt_lines(origin_type, origin_id);

CREATE INDEX IF NOT EXISTS ix_receipt_lines_concept_id
    ON receipt_lines(concept_id);
