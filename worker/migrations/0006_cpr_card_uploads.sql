CREATE TABLE IF NOT EXISTS cpr_card_uploads (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  class_session_id TEXT NOT NULL,
  file_name TEXT,
  mime_type TEXT,
  r2_key TEXT NOT NULL,
  uploaded_at TEXT NOT NULL,
  device_id TEXT,
  raw_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE(student_id, class_session_id),
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY(class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_cpr_card_uploads_session
  ON cpr_card_uploads(class_session_id, uploaded_at);
