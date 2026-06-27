ALTER TABLE instructors ADD COLUMN oems_id TEXT;
ALTER TABLE instructors ADD COLUMN first_name TEXT;
ALTER TABLE instructors ADD COLUMN last_name TEXT;

CREATE INDEX IF NOT EXISTS idx_instructors_oems_id
  ON instructors(oems_id);
