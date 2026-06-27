CREATE TABLE IF NOT EXISTS instructors (
  person_id TEXT PRIMARY KEY,
  full_name TEXT,
  email TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS instructor_attendance (
  id TEXT PRIMARY KEY,
  person_id TEXT NOT NULL,
  device_id TEXT,
  checked_in_at TEXT NOT NULL,
  checked_out_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  FOREIGN KEY(person_id) REFERENCES instructors(person_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_instructor_attendance_person_created
  ON instructor_attendance(person_id, created_at DESC);

CREATE TABLE IF NOT EXISTS skills_verifications (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  class_session_id TEXT NOT NULL,
  instructor_person_id TEXT,
  opened_at TEXT NOT NULL,
  completed_at TEXT,
  source TEXT NOT NULL DEFAULT 'instructor_dashboard',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY(class_session_id) REFERENCES class_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_skills_verifications_student_session
  ON skills_verifications(student_id, class_session_id);
