-- A real FlexiQuiz response belongs to one student, including concurrent writes.
CREATE INDEX IF NOT EXISTS quiz_attempts_response_owner ON quiz_attempts(response_id, student_id);
CREATE INDEX IF NOT EXISTS final_exam_results_response_owner ON final_exam_results(response_id, student_id);

CREATE TRIGGER IF NOT EXISTS quiz_attempts_owner_insert
BEFORE INSERT ON quiz_attempts
WHEN length(NEW.response_id) = 36 AND (
  EXISTS (SELECT 1 FROM quiz_attempts WHERE response_id = NEW.response_id AND student_id != NEW.student_id)
  OR EXISTS (SELECT 1 FROM final_exam_results WHERE response_id = NEW.response_id AND student_id != NEW.student_id)
)
BEGIN
  SELECT RAISE(ABORT, 'quiz_response_owner_conflict');
END;

CREATE TRIGGER IF NOT EXISTS final_exam_results_owner_insert
BEFORE INSERT ON final_exam_results
WHEN length(NEW.response_id) = 36 AND (
  EXISTS (SELECT 1 FROM quiz_attempts WHERE response_id = NEW.response_id AND student_id != NEW.student_id)
  OR EXISTS (SELECT 1 FROM final_exam_results WHERE response_id = NEW.response_id AND student_id != NEW.student_id)
)
BEGIN
  SELECT RAISE(ABORT, 'quiz_response_owner_conflict');
END;

CREATE TRIGGER IF NOT EXISTS quiz_attempts_owner_update
BEFORE UPDATE OF student_id, response_id ON quiz_attempts
WHEN NEW.student_id != OLD.student_id OR (
  NEW.response_id IS NOT OLD.response_id AND length(NEW.response_id) = 36 AND (
    EXISTS (SELECT 1 FROM quiz_attempts WHERE response_id = NEW.response_id AND student_id != NEW.student_id)
    OR EXISTS (SELECT 1 FROM final_exam_results WHERE response_id = NEW.response_id AND student_id != NEW.student_id)
  )
)
BEGIN
  SELECT RAISE(ABORT, 'quiz_response_owner_conflict');
END;

CREATE TRIGGER IF NOT EXISTS final_exam_results_owner_update
BEFORE UPDATE OF student_id, response_id ON final_exam_results
WHEN NEW.student_id != OLD.student_id OR (
  NEW.response_id IS NOT OLD.response_id AND length(NEW.response_id) = 36 AND (
    EXISTS (SELECT 1 FROM quiz_attempts WHERE response_id = NEW.response_id AND student_id != NEW.student_id)
    OR EXISTS (SELECT 1 FROM final_exam_results WHERE response_id = NEW.response_id AND student_id != NEW.student_id)
  )
)
BEGIN
  SELECT RAISE(ABORT, 'quiz_response_owner_conflict');
END;
