PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS students (
  id TEXT PRIMARY KEY,
  oems_id TEXT,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_students_oems_id
  ON students(oems_id)
  WHERE oems_id IS NOT NULL AND oems_id != '';

CREATE TABLE IF NOT EXISTS class_sessions (
  id TEXT PRIMARY KEY,
  course_id TEXT,
  course_title TEXT NOT NULL,
  course_date TEXT NOT NULL,
  source_submission_id TEXT,
  source_form_id TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS student_progress (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  class_session_id TEXT NOT NULL,
  did_check_in INTEGER NOT NULL DEFAULT 0,
  did_check_out INTEGER NOT NULL DEFAULT 0,
  did_open_skills INTEGER NOT NULL DEFAULT 0,
  did_open_quiz INTEGER NOT NULL DEFAULT 0,
  check_in_at TEXT,
  check_out_at TEXT,
  last_device_id TEXT,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE(student_id, class_session_id),
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY(class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS quiz_attempts (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  class_session_id TEXT NOT NULL,
  flexiquiz_user_id TEXT,
  quiz_id TEXT NOT NULL,
  response_id TEXT,
  result_text TEXT,
  score_text TEXT,
  passed INTEGER,
  review_url TEXT,
  review_released INTEGER NOT NULL DEFAULT 1,
  completed_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY(class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_student_session
  ON quiz_attempts(student_id, class_session_id);

CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  student_id TEXT,
  class_session_id TEXT,
  actor_id TEXT,
  device_id TEXT,
  payload_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_events_session_created
  ON audit_events(class_session_id, created_at);

CREATE TABLE IF NOT EXISTS outbox (
  id TEXT PRIMARY KEY,
  message_type TEXT NOT NULL,
  recipient TEXT NOT NULL,
  subject TEXT NOT NULL,
  message_plain_text TEXT NOT NULL,
  message_html TEXT,
  attachment_guid TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  sent_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_outbox_status_created
  ON outbox(status, created_at);
