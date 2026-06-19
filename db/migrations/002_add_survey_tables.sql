PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* ============================================================
   002_add_survey_tables.sql
   Adds the anonymous satisfaction survey module to an already
   initialized database. Safe to run multiple times (idempotent).
   For a brand-new install this is unnecessary — db/init/02_schema.sql
   already includes these tables.

   Manual usage on an existing deployment:
     sqlite3 /path/to/parquerm.db < 002_add_survey_tables.sql
   ============================================================ */

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
