CREATE TABLE IF NOT EXISTS checkout_magic_links (
  id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL UNIQUE,
  student_id TEXT NOT NULL,
  class_session_id TEXT NOT NULL,
  email TEXT NOT NULL,
  created_by_person_id TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  expires_at TEXT NOT NULL,
  used_at TEXT,
  sent_at TEXT,
  last_error TEXT,
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY(class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_checkout_magic_links_student_session
  ON checkout_magic_links(student_id, class_session_id, created_at DESC);
