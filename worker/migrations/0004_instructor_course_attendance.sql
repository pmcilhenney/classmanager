ALTER TABLE instructor_attendance ADD COLUMN class_session_id TEXT;
ALTER TABLE instructor_attendance ADD COLUMN course_id TEXT;
ALTER TABLE instructor_attendance ADD COLUMN course_title TEXT;
ALTER TABLE instructor_attendance ADD COLUMN course_date TEXT;
ALTER TABLE instructor_attendance ADD COLUMN source TEXT;
ALTER TABLE instructor_attendance ADD COLUMN checkout_reminder_sent_at TEXT;

ALTER TABLE device_tokens ADD COLUMN instructor_person_id TEXT;
ALTER TABLE device_tokens ADD COLUMN instructor_class_session_id TEXT;

CREATE INDEX IF NOT EXISTS idx_instructor_attendance_session
  ON instructor_attendance(class_session_id, checked_out_at);

CREATE INDEX IF NOT EXISTS idx_device_tokens_instructor_session
  ON device_tokens(instructor_person_id, instructor_class_session_id);

CREATE TABLE IF NOT EXISTS scheduled_courses (
  id TEXT PRIMARY KEY,
  class_session_id TEXT NOT NULL,
  course_id TEXT,
  course_title TEXT NOT NULL,
  course_date TEXT NOT NULL,
  course_location TEXT,
  source_form_id TEXT,
  source TEXT NOT NULL DEFAULT 'jotform_registration',
  expected_count INTEGER NOT NULL DEFAULT 0,
  raw_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE(class_session_id, course_id, course_title)
);

CREATE INDEX IF NOT EXISTS idx_scheduled_courses_date
  ON scheduled_courses(course_date, course_title);

CREATE TABLE IF NOT EXISTS scheduled_course_students (
  id TEXT PRIMARY KEY,
  class_session_id TEXT NOT NULL,
  course_id TEXT,
  submission_id TEXT NOT NULL,
  student_id TEXT NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT,
  oems_id TEXT,
  course_title TEXT NOT NULL,
  course_date TEXT NOT NULL,
  course_location TEXT,
  dob TEXT,
  raw_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE(class_session_id, student_id, submission_id)
);

CREATE INDEX IF NOT EXISTS idx_scheduled_course_students_session
  ON scheduled_course_students(class_session_id, last_name, first_name);
