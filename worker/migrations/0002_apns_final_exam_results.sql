CREATE TABLE IF NOT EXISTS device_tokens (
  token TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  apns_environment TEXT NOT NULL DEFAULT 'prod',
  platform TEXT NOT NULL DEFAULT 'ios',
  student_id TEXT,
  class_session_id TEXT,
  email TEXT,
  flexiquiz_user_id TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  last_push_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_student_session
  ON device_tokens(student_id, class_session_id);

CREATE INDEX IF NOT EXISTS idx_device_tokens_email
  ON device_tokens(email);

CREATE INDEX IF NOT EXISTS idx_device_tokens_flexiquiz_user
  ON device_tokens(flexiquiz_user_id);

CREATE TABLE IF NOT EXISTS final_exam_results (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  class_session_id TEXT NOT NULL,
  quiz_id TEXT NOT NULL,
  quiz_name TEXT,
  response_id TEXT,
  flexiquiz_user_id TEXT,
  email TEXT,
  score_text TEXT,
  result_text TEXT,
  passed INTEGER,
  percentage_score REAL,
  points REAL,
  available_points REAL,
  report_url TEXT,
  completed_at TEXT,
  raw_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE(student_id, class_session_id, quiz_id, response_id)
);

CREATE INDEX IF NOT EXISTS idx_final_exam_results_student_session
  ON final_exam_results(student_id, class_session_id, completed_at DESC);

CREATE INDEX IF NOT EXISTS idx_final_exam_results_response
  ON final_exam_results(response_id);
