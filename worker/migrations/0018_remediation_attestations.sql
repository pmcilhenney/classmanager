CREATE TABLE IF NOT EXISTS remediation_attestations (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  class_session_id TEXT NOT NULL,
  quiz_id TEXT NOT NULL,
  version_b_quiz_id TEXT,
  action TEXT NOT NULL,
  score_text TEXT,
  course_title TEXT,
  course_date TEXT,
  attestation_text TEXT,
  signature_data_url TEXT,
  signed_at TEXT,
  device_id TEXT,
  raw_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY(class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_remediation_attestations_session_student
  ON remediation_attestations(class_session_id, student_id, created_at DESC);
