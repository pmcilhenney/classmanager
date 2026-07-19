ALTER TABLE cpr_card_uploads ADD COLUMN expiration_date TEXT;
ALTER TABLE cpr_card_uploads ADD COLUMN validation_status TEXT;
ALTER TABLE cpr_card_uploads ADD COLUMN validation_notes TEXT;
ALTER TABLE cpr_card_uploads ADD COLUMN recognized_text TEXT;

CREATE INDEX IF NOT EXISTS idx_cpr_card_uploads_student_uploaded
  ON cpr_card_uploads(student_id, uploaded_at);
