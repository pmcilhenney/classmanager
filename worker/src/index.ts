export interface Env {
  DB: D1Database;
  ARTIFACTS: R2Bucket;
  ASSETS: Fetcher;
  AI?: Ai;
  ENVIRONMENT: string;
  JOTFORM_BASE_URL: string;
  JOTFORM_API_KEY?: string;
  FLEXIQUIZ_API_BASE: string;
  FLEXIQUIZ_AUTH_URL: string;
  FLEXIQUIZ_API_KEY?: string;
  FLEXIQUIZ_SSO_SHARED_SECRET?: string;
  SM_BASE_URL: string;
  SM_AUTH: string;
  SM_SEND_EMAIL: string;
  SM_USERNAME?: string;
  SM_PASSWORD?: string;
  FROM_ADDRESS?: string;
  REPLY_TO_ADDRESS?: string;
  ACADEMY_RMS_BASE_URL?: string;
  ACADEMY_RMS_ATTENDANCE_SECRET?: string;
}

type JsonRecord = Record<string, unknown>;

type NormalizedAttendee = {
  submissionId: string;
  firstName: string;
  lastName: string;
  email: string;
  oemsId: string;
  courseType: string;
  courseDate?: string;
  courseId?: string;
  ceuValue?: string;
  productCategories?: string[];
  dob?: string;
  courseImageURL?: string;
  courseLocation?: string;
};

type SessionOption = {
  courseType: string;
  datePretty: string;
  dateRaw: string;
  courseId?: string;
  ceuValue?: string;
  productCategories?: string[];
  courseImageURL?: string;
  courseLocation?: string;
};

type QuizReviewQuestion = {
  id?: string;
  number: number;
  prompt: string;
  choices?: string[];
  studentAnswer?: string;
  correctAnswer?: string;
  isCorrect?: boolean;
  feedback?: string;
  points?: string;
};

type QuizReviewPayload = {
  ok: true;
  quizId: string;
  responseId?: string;
  resultText?: string;
  scoreText?: string;
  passed?: boolean;
  completedAt?: string;
  reportUrl?: string;
  questions: QuizReviewQuestion[];
  warnings: string[];
};

type StudentCommentAnalytics = {
  averageScore?: number;
  completedQuizCount: number;
  passedQuizCount: number;
  strongestTopics: string[];
  growthTopics: string[];
  quizSummaries: string[];
};

type FlexiUserProfile = {
  userId: string;
  userName: string;
  email?: string;
  quizzes: JsonRecord[];
};

const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store"
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders(request) });
    }

    try {
      if (request.method === "GET" && url.pathname === "/health") {
        const db = await env.DB.prepare("SELECT 1 AS ok").first();
        return json({
          ok: true,
          service: "classmanager-api",
          environment: env.ENVIRONMENT,
          bindings: {
            d1: db?.ok === 1,
            r2: true,
            assets: true
          }
        });
      }

      if (request.method === "POST" && url.pathname === "/session/lookup") {
        return await sessionLookup(request, env);
      }

      if (request.method === "POST" && url.pathname === "/instructor/auth") {
        return await instructorAuth(request, env);
      }

      if (request.method === "GET" && url.pathname.startsWith("/progress/")) {
        return await getProgress(url, env);
      }

      if (request.method === "PATCH" && url.pathname.startsWith("/progress/")) {
        return await patchProgress(request, url, env);
      }

      if (request.method === "POST" && url.pathname === "/attendance/submit") {
        return await submitAttendance(request, env);
      }

      if (request.method === "POST" && url.pathname === "/quiz/assign") {
        return await assignQuiz(request, env);
      }

      if (request.method === "GET" && url.pathname.startsWith("/quiz/review/")) {
        return await quizReview(url, env);
      }

      if (request.method === "POST" && url.pathname === "/email/send") {
        return await sendEmailEndpoint(request, env);
      }

      if (request.method === "POST" && url.pathname === "/aicomments") {
        return await aiCommentsEndpoint(request, env);
      }

      return json({ error: "not_found" }, 404);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: error.message }, error.status);
      }
      console.error("request failed", error);
      return json({ error: "internal_error" }, 500);
    }
  }
};

async function sessionLookup(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const submissionId = stringField(body, "submissionId");

  if (!submissionId) {
    return json({ error: "missing_submission_id" }, 400);
  }

  if (!env.JOTFORM_API_KEY) {
    return json({ error: "jotform_not_configured" }, 503);
  }

  const source = await fetchJotformSubmission(env, submissionId);
  const normalized = normalizeSessionLookup(source, submissionId);
  const selected = normalized.options[0];
  const attendee = selected ? attendeeWithOption(normalized.attendee, selected) : normalized.attendee;

  await ensureProgressParents(env, {
    studentId: attendee.oemsId || attendee.submissionId,
    classSessionId: sessionIdFor(attendee.courseDate ?? selected?.dateRaw ?? attendee.submissionId),
    oemsId: attendee.oemsId || undefined,
    firstName: attendee.firstName || "Unknown",
    lastName: attendee.lastName || "Student",
    email: attendee.email || undefined,
    courseId: attendee.courseId,
    courseTitle: attendee.courseType || "Class Session",
    courseDate: attendee.courseDate ?? selected?.dateRaw ?? "undated",
    sourceSubmissionId: attendee.submissionId,
    sourceFormId: normalized.formId
  });

  await audit(env, "session.lookup", {
    studentId: attendee.oemsId || attendee.submissionId,
    classSessionId: sessionIdFor(attendee.courseDate ?? selected?.dateRaw ?? attendee.submissionId),
    payload: {
      submissionId,
      formId: normalized.formId,
      formType: normalized.formType,
      optionCount: normalized.options.length
    }
  });

  return json({
    ok: true,
    submissionId,
    formId: normalized.formId,
    formType: normalized.formType,
    attendee,
    options: normalized.options
  });
}

async function instructorAuth(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const instructorId = stringField(body, "instructorId");

  if (!instructorId) {
    return json({ error: "missing_instructor_id" }, 400);
  }

  if (!env.JOTFORM_API_KEY) {
    return json({ error: "jotform_not_configured" }, 503);
  }

  const url = new URL(joinUrl(env.JOTFORM_BASE_URL, "/form/242266064536154/submissions"));
  url.searchParams.set("apiKey", env.JOTFORM_API_KEY);
  url.searchParams.set("limit", "1000");

  const response = await fetch(url, {
    headers: { accept: "application/json" }
  });

  if (!response.ok) {
    return json({ error: "instructor_lookup_failed" }, 502);
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  const submissions = arrayField(data, "content").filter(isJsonRecord);
  const normalizedId = instructorId.trim();

  for (const submission of submissions) {
    const answers = recordField(submission, "answers");
    if (!answers) {
      continue;
    }

    const oemsId = answerString(answers, "15").trim();
    if (oemsId !== normalizedId) {
      continue;
    }

    return json({
      ok: true,
      instructor: {
        fullName: answerString(answers, "3"),
        email: answerString(answers, "5"),
        oemsId
      }
    });
  }

  return json({ error: "instructor_not_authorized" }, 404);
}

async function fetchJotformSubmission(env: Env, submissionId: string): Promise<JsonRecord> {
  const url = new URL(joinUrl(env.JOTFORM_BASE_URL, `/submission/${encodeURIComponent(submissionId)}`));
  url.searchParams.set("apiKey", env.JOTFORM_API_KEY ?? "");

  const response = await fetch(url, {
    headers: { accept: "application/json" }
  });

  if (response.status === 404) {
    throw new HttpError(404, "submission_not_found");
  }

  if (!response.ok) {
    throw new HttpError(502, "jotform_lookup_failed");
  }

  return await response.json<JsonRecord>();
}

function normalizeSessionLookup(source: JsonRecord, requestedSubmissionId: string): {
  formId: string;
  formType: "registration" | "refresher";
  attendee: NormalizedAttendee;
  options: SessionOption[];
} {
  const content = recordField(source, "content");
  const answers = recordField(content, "answers");
  if (!content || !answers) {
    throw new HttpError(502, "malformed_jotform_submission");
  }

  const submissionId = stringField(content, "id") ?? requestedSubmissionId;
  const formId = stringField(content, "form_id") ?? "";
  const isRegistration = Boolean(answer(answers, "39"));

  if (isRegistration) {
    return normalizeRegistrationSubmission(answers, submissionId, formId);
  }

  return normalizeRefresherSubmission(answers, submissionId, formId);
}

function normalizeRegistrationSubmission(
  answers: JsonRecord,
  submissionId: string,
  formId: string
): {
  formId: string;
  formType: "registration";
  attendee: NormalizedAttendee;
  options: SessionOption[];
} {
  const name = answerObject(answers, "4");
  const dobAnswer = answerObject(answers, "7");
  const dobValue = stringField(answer(answers, "7") ?? {}, "prettyFormat") ??
    normalizeDateToMMDDYYYY(stringField(dobAnswer, "datetime") ?? "");
  const location = answerString(answers, "46");
  const products = registrationProducts(answers);
  const firstProduct = products[0];
  const firstOption = firstProduct ? productToOption(firstProduct, location) : undefined;

  const attendee: NormalizedAttendee = {
    submissionId,
    firstName: stringField(name, "first") ?? "",
    lastName: stringField(name, "last") ?? "",
    email: answerString(answers, "5"),
    oemsId: answerString(answers, "6"),
    courseType: firstOption?.courseType ?? "",
    courseDate: firstOption?.dateRaw,
    courseId: firstOption?.courseId,
    ceuValue: firstOption?.ceuValue,
    productCategories: firstOption?.productCategories,
    dob: dobValue || undefined,
    courseImageURL: firstOption?.courseImageURL,
    courseLocation: location || undefined
  };

  return {
    formId,
    formType: "registration",
    attendee,
    options: products.map((product) => productToOption(product, location))
  };
}

function normalizeRefresherSubmission(
  answers: JsonRecord,
  submissionId: string,
  formId: string
): {
  formId: string;
  formType: "refresher";
  attendee: NormalizedAttendee;
  options: SessionOption[];
} {
  const options = [
    ["60", "Refresher A"],
    ["74", "Refresher B"],
    ["77", "Refresher C"]
  ].flatMap(([qid, label]) => {
    const rawDate = answerString(answers, qid);
    if (!rawDate) {
      return [];
    }
    return [{
      courseType: label,
      datePretty: rawDate,
      dateRaw: extractDatePart(rawDate) ?? rawDate
    }];
  });

  const firstOption = options[0];
  const attendee: NormalizedAttendee = {
    submissionId,
    firstName: answerString(answers, "32"),
    lastName: answerString(answers, "33"),
    email: answerString(answers, "4"),
    oemsId: answerString(answers, "6"),
    courseType: firstOption?.courseType ?? answerString(answers, "96"),
    courseDate: firstOption?.dateRaw
  };

  return {
    formId,
    formType: "refresher",
    attendee,
    options
  };
}

function registrationProducts(answers: JsonRecord): JsonRecord[] {
  const courseField = answer(answers, "39");
  if (!courseField) {
    return [];
  }

  const answerPayload = recordField(courseField, "answer");
  const selectedJson = answerPayload ? stringField(answerPayload, "1") : undefined;
  const selectedProduct = selectedJson ? parseJsonRecord(selectedJson) : undefined;
  const products = arrayField(courseField, "products").filter(isJsonRecord);

  if (selectedProduct) {
    return [selectedProduct, ...products.filter((product) => stringField(product, "name") !== stringField(selectedProduct, "name"))];
  }

  return products;
}

function productToOption(product: JsonRecord, courseLocation?: string): SessionOption {
  const name = firstNonEmpty(
    stringField(product, "name"),
    stringField(product, "title"),
    stringField(product, "label"),
    stringField(product, "text"),
    "Unnamed Course"
  );
  const description = stringField(product, "description") ?? "";
  const fields = parseDescriptionFields(description);
  return {
    courseType: cleanCourseName(name),
    datePretty: description || fields.date || "",
    dateRaw: fields.date ?? "",
    courseId: fields.courseId,
    ceuValue: fields.ceuValue,
    productCategories: productCategories(product),
    courseImageURL: firstImage(product),
    courseLocation: courseLocation || undefined
  };
}

function attendeeWithOption(attendee: NormalizedAttendee, option: SessionOption): NormalizedAttendee {
  return {
    ...attendee,
    courseType: option.courseType,
    courseDate: option.dateRaw || attendee.courseDate,
    courseId: option.courseId ?? attendee.courseId,
    ceuValue: option.ceuValue ?? attendee.ceuValue,
    productCategories: option.productCategories ?? attendee.productCategories,
    courseImageURL: option.courseImageURL ?? attendee.courseImageURL,
    courseLocation: option.courseLocation ?? attendee.courseLocation
  };
}

async function getProgress(url: URL, env: Env): Promise<Response> {
  const { classSessionId, studentId } = progressPath(url);
  if (!classSessionId || !studentId) {
    return json({ error: "bad_progress_path" }, 400);
  }

  const row = await env.DB.prepare(
    `SELECT * FROM student_progress WHERE class_session_id = ?1 AND student_id = ?2`
  ).bind(classSessionId, studentId).first<JsonRecord>();

  const attempts = await env.DB.prepare(
    `SELECT quiz_id, result_text, score_text, passed, completed_at, updated_at
     FROM quiz_attempts
     WHERE class_session_id = ?1 AND student_id = ?2
     ORDER BY COALESCE(completed_at, updated_at) DESC`
  ).bind(classSessionId, studentId).all<JsonRecord>();

  const quizResults: Record<string, string> = {};
  const completedQuizIds: string[] = [];
  for (const attempt of attempts.results ?? []) {
    const quizId = stringField(attempt, "quiz_id");
    if (!quizId || quizResults[quizId]) {
      continue;
    }
    completedQuizIds.push(quizId);
    quizResults[quizId] = quizResultSummary(attempt);
  }

  const progress = row ? { ...row } : null;
  if (progress || completedQuizIds.length > 0) {
    return json({
      classSessionId,
      studentId,
      progress: {
        ...(progress ?? {
          did_check_in: 0,
          did_check_out: 0,
          did_open_skills: 0,
          did_open_quiz: completedQuizIds.length > 0 ? 1 : 0,
          check_in_at: null,
          updated_at: null
        }),
        completed_quiz_ids: completedQuizIds,
        quiz_results: quizResults
      }
    });
  }

  return json({ classSessionId, studentId, progress: null });
}

async function patchProgress(request: Request, url: URL, env: Env): Promise<Response> {
  const { classSessionId, studentId } = progressPath(url);
  if (!classSessionId || !studentId) {
    return json({ error: "bad_progress_path" }, 400);
  }

  const body = await readJson(request);
  const now = new Date().toISOString();
  const id = `${classSessionId}:${studentId}`;
  const courseDate = stringField(body, "courseDate") ?? classSessionId;

  await ensureProgressParents(env, {
    studentId,
    classSessionId,
    oemsId: stringField(body, "oemsId") ?? studentId,
    firstName: stringField(body, "firstName") ?? "Unknown",
    lastName: stringField(body, "lastName") ?? "Student",
    email: stringField(body, "email"),
    courseId: stringField(body, "courseId"),
    courseTitle: stringField(body, "courseTitle") ?? "Class Session",
    courseDate,
    sourceSubmissionId: stringField(body, "sourceSubmissionId"),
    sourceFormId: stringField(body, "sourceFormId")
  });

  await env.DB.prepare(
    `INSERT INTO student_progress (
      id, student_id, class_session_id, did_check_in, did_check_out,
      did_open_skills, did_open_quiz, check_in_at, check_out_at,
      last_device_id, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
    ON CONFLICT(student_id, class_session_id) DO UPDATE SET
      did_check_in = max(did_check_in, excluded.did_check_in),
      did_check_out = max(did_check_out, excluded.did_check_out),
      did_open_skills = max(did_open_skills, excluded.did_open_skills),
      did_open_quiz = max(did_open_quiz, excluded.did_open_quiz),
      check_in_at = COALESCE(excluded.check_in_at, check_in_at),
      check_out_at = COALESCE(excluded.check_out_at, check_out_at),
      last_device_id = COALESCE(excluded.last_device_id, last_device_id),
      updated_at = excluded.updated_at`
  ).bind(
    id,
    studentId,
    classSessionId,
    boolInt(body.didCheckIn),
    boolInt(body.didCheckOut),
    boolInt(body.didOpenSkills),
    boolInt(body.didOpenQuiz),
    stringField(body, "checkInAt") ?? null,
    stringField(body, "checkOutAt") ?? null,
    stringField(body, "deviceId") ?? null,
    now
  ).run();

  await audit(env, "progress.patch", {
    studentId,
    classSessionId,
    deviceId: stringField(body, "deviceId"),
    payload: body
  });

  return json({ ok: true, id, updatedAt: now });
}

async function submitAttendance(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const formId = stringField(body, "formId");
  const inOut = stringField(body, "inOut");
  const studentId = stringField(body, "studentId");
  const classSessionId = stringField(body, "classSessionId");
  const attendee = recordField(body, "attendee");
  const fields = recordField(body, "fields");
  const attestation = recordField(body, "attestation");
  const deviceId = stringField(body, "deviceId");

  if (!formId || !inOut || !studentId || !classSessionId || !attendee || !fields) {
    return json({ error: "missing_attendance_fields" }, 400);
  }

  if (!env.JOTFORM_API_KEY && !env.ACADEMY_RMS_BASE_URL) {
    return json({ error: "attendance_destinations_not_configured" }, 503);
  }

  const now = new Date().toISOString();
  const didCheckIn = inOut === "Check-In";
  const didCheckOut = inOut === "Check-Out";
  const warnings: string[] = [];
  let rms: { ok: boolean; attestationId?: string } | undefined;
  let jotform: { submissionId?: string } = {};

  if (env.ACADEMY_RMS_BASE_URL && env.ACADEMY_RMS_ATTENDANCE_SECRET && attestation) {
    try {
      rms = await postAcademyRmsAttendance(env, {
        formId,
        inOut,
        studentId,
        classSessionId,
        attendee,
        fields,
        attestation,
        deviceId,
        submittedAt: now
      });
    } catch (error) {
      console.error("rms attendance submit failed", error);
      warnings.push("rms_submit_failed");
    }
  } else {
    warnings.push("rms_attendance_not_configured");
  }

  if (env.JOTFORM_API_KEY) {
    try {
      jotform = await postJotformSubmission(env, formId, fields);
    } catch (error) {
      console.error("jotform attendance submit failed", error);
      warnings.push("jotform_submit_failed");
    }
  } else {
    warnings.push("jotform_not_configured");
  }

  if (!rms?.ok && !jotform.submissionId) {
    return json({ error: "attendance_submit_failed", warnings }, 502);
  }

  await ensureProgressParents(env, {
    studentId,
    classSessionId,
    oemsId: stringField(attendee, "oemsId") ?? studentId,
    firstName: stringField(attendee, "firstName") ?? "Unknown",
    lastName: stringField(attendee, "lastName") ?? "Student",
    email: stringField(attendee, "email"),
    courseId: stringField(attendee, "courseId"),
    courseTitle: stringField(attendee, "courseType") ?? "Class Session",
    courseDate: stringField(attendee, "courseDate") ?? classSessionId,
    sourceSubmissionId: stringField(attendee, "submissionId"),
    sourceFormId: formId
  });

  await writeProgress(env, {
    studentId,
    classSessionId,
    didCheckIn,
    didCheckOut,
    checkInAt: didCheckIn ? now : undefined,
    checkOutAt: didCheckOut ? now : undefined,
    deviceId
  });

  await audit(env, "attendance.submit", {
    studentId,
    classSessionId,
    deviceId,
    payload: {
      formId,
      inOut,
      jotformSubmissionId: jotform.submissionId ?? null,
      rmsAttestationId: rms?.attestationId ?? null,
      warnings
    }
  });

  return json({
    ok: true,
    formId,
    inOut,
    submissionId: jotform.submissionId,
    rmsAttestationId: rms?.attestationId,
    warnings,
    updatedAt: now
  });
}

async function postAcademyRmsAttendance(
  env: Env,
  payload: JsonRecord
): Promise<{ ok: boolean; attestationId?: string }> {
  const url = joinUrl(env.ACADEMY_RMS_BASE_URL ?? "", "/api/webhooks/classmanager-attendance");
  const response = await fetch(url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "x-classmanager-secret": env.ACADEMY_RMS_ATTENDANCE_SECRET ?? ""
    },
    body: JSON.stringify(payload)
  });
  const parsed: JsonRecord = await response.json<JsonRecord>().catch(() => ({}));
  if (!response.ok || parsed.ok === false) {
    throw new HttpError(response.status || 502, stringField(parsed, "error") ?? "rms_submit_failed");
  }
  return {
    ok: true,
    attestationId: stringField(parsed, "attestation_id") ?? stringField(parsed, "attestationId")
  };
}

async function postJotformSubmission(
  env: Env,
  formId: string,
  fields: JsonRecord
): Promise<{ submissionId?: string }> {
  const url = new URL(joinUrl(env.JOTFORM_BASE_URL, `/form/${encodeURIComponent(formId)}/submissions`));
  url.searchParams.set("apiKey", env.JOTFORM_API_KEY ?? "");
  const body = new URLSearchParams();

  for (const [key, value] of Object.entries(fields)) {
    if (typeof value === "string" && value.trim().length > 0) {
      body.set(jotformSubmissionFieldName(key), value.trim());
    }
  }

  const response = await fetch(url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/x-www-form-urlencoded; charset=utf-8"
    },
    body
  });

  if (!response.ok) {
    throw new HttpError(502, "jotform_submit_failed");
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  const content = recordField(data, "content");
  return {
    submissionId: content ? stringField(content, "submissionID") : undefined
  };
}

function jotformSubmissionFieldName(key: string): string {
  const clean = key.trim();
  const firstBracket = clean.indexOf("[");
  if (firstBracket === -1) {
    return `submission[${clean}]`;
  }

  const root = clean.slice(0, firstBracket);
  const suffix = clean.slice(firstBracket);
  return `submission[${root}]${suffix}`;
}

async function writeProgress(
  env: Env,
  input: {
    studentId: string;
    classSessionId: string;
    didCheckIn?: boolean;
    didCheckOut?: boolean;
    didOpenSkills?: boolean;
    didOpenQuiz?: boolean;
    checkInAt?: string;
    checkOutAt?: string;
    deviceId?: string;
  }
): Promise<void> {
  const now = new Date().toISOString();
  const id = `${input.classSessionId}:${input.studentId}`;

  await env.DB.prepare(
    `INSERT INTO student_progress (
      id, student_id, class_session_id, did_check_in, did_check_out,
      did_open_skills, did_open_quiz, check_in_at, check_out_at,
      last_device_id, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
    ON CONFLICT(student_id, class_session_id) DO UPDATE SET
      did_check_in = max(did_check_in, excluded.did_check_in),
      did_check_out = max(did_check_out, excluded.did_check_out),
      did_open_skills = max(did_open_skills, excluded.did_open_skills),
      did_open_quiz = max(did_open_quiz, excluded.did_open_quiz),
      check_in_at = COALESCE(excluded.check_in_at, check_in_at),
      check_out_at = COALESCE(excluded.check_out_at, check_out_at),
      last_device_id = COALESCE(excluded.last_device_id, last_device_id),
      updated_at = excluded.updated_at`
  ).bind(
    id,
    input.studentId,
    input.classSessionId,
    input.didCheckIn ? 1 : 0,
    input.didCheckOut ? 1 : 0,
    input.didOpenSkills ? 1 : 0,
    input.didOpenQuiz ? 1 : 0,
    input.checkInAt ?? null,
    input.checkOutAt ?? null,
    input.deviceId ?? null,
    now
  ).run();
}

async function ensureProgressParents(
  env: Env,
  input: {
    studentId: string;
    classSessionId: string;
    oemsId?: string;
    firstName: string;
    lastName: string;
    email?: string;
    courseId?: string;
    courseTitle: string;
    courseDate: string;
    sourceSubmissionId?: string;
    sourceFormId?: string;
  }
): Promise<void> {
  const now = new Date().toISOString();

  await env.DB.prepare(
    `INSERT INTO students (id, oems_id, first_name, last_name, email, updated_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6)
     ON CONFLICT(id) DO UPDATE SET
       oems_id = COALESCE(excluded.oems_id, oems_id),
       first_name = CASE WHEN excluded.first_name != 'Unknown' THEN excluded.first_name ELSE first_name END,
       last_name = CASE WHEN excluded.last_name != 'Student' THEN excluded.last_name ELSE last_name END,
       email = COALESCE(excluded.email, email),
       updated_at = excluded.updated_at`
  ).bind(
    input.studentId,
    input.oemsId ?? null,
    input.firstName,
    input.lastName,
    input.email ?? null,
    now
  ).run();

  await env.DB.prepare(
    `INSERT INTO class_sessions (
      id, course_id, course_title, course_date, source_submission_id, source_form_id, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
    ON CONFLICT(id) DO UPDATE SET
      course_id = COALESCE(excluded.course_id, course_id),
      course_title = CASE WHEN excluded.course_title != 'Class Session' THEN excluded.course_title ELSE course_title END,
      course_date = excluded.course_date,
      source_submission_id = COALESCE(excluded.source_submission_id, source_submission_id),
      source_form_id = COALESCE(excluded.source_form_id, source_form_id),
      updated_at = excluded.updated_at`
  ).bind(
    input.classSessionId,
    input.courseId ?? null,
    input.courseTitle,
    input.courseDate,
    input.sourceSubmissionId ?? null,
    input.sourceFormId ?? null,
    now
  ).run();
}

async function assignQuiz(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const email = stringField(body, "email");
  const quizId = stringField(body, "quizId");
  const firstName = stringField(body, "firstName") ?? "";
  const lastName = stringField(body, "lastName") ?? "";
  const oemsId = stringField(body, "oemsId") ?? "";
  const studentId = stringField(body, "studentId");
  const classSessionId = stringField(body, "classSessionId");
  const courseTitle = stringField(body, "courseTitle") ?? "Class Session";
  const courseDate = stringField(body, "courseDate") ?? classSessionId ?? "undated";
  const deviceId = stringField(body, "deviceId");

  if (!email || !quizId) {
    return json({ error: "missing_email_or_quiz_id" }, 400);
  }

  if (!env.FLEXIQUIZ_API_KEY || !env.FLEXIQUIZ_SSO_SHARED_SECRET) {
    return json({ error: "flexiquiz_not_configured" }, 503);
  }

  const warnings: string[] = [];
  const quizCheck = await flexiQuizStatus(env, quizId);
  if (!quizCheck.ok) {
    await audit(env, "quiz.preflight.failed", {
      studentId,
      classSessionId,
      deviceId,
      payload: { email, quizId, status: quizCheck.status, body: quizCheck.body }
    });
    return json({ error: "flexiquiz_quiz_unavailable", status: quizCheck.status, warnings }, 502);
  }

  let flexiquizUserId = await flexiFindUserId(env, email);
  let flexiUserProfile: FlexiUserProfile | undefined;

  if (!flexiquizUserId) {
    flexiquizUserId = await flexiCreateUser(env, {
      userName: email,
      email,
      firstName,
      lastName,
      password: `${lastName}${oemsId}`
    }).catch((error) => {
      console.warn("flexiquiz create failed", error);
      warnings.push("flexiquiz_create_failed");
      return undefined;
    });
  }

  if (flexiquizUserId) {
    flexiUserProfile = await flexiGetUserProfile(env, flexiquizUserId);
    if (!flexiUserProfile) {
      warnings.push("flexiquiz_user_profile_unavailable");
    }
    const alreadyAssigned = flexiUserProfile
      ? flexiUserHasQuiz(flexiUserProfile, quizId)
      : await flexiUserHasQuizByEndpoint(env, flexiquizUserId, quizId);
    if (!alreadyAssigned) {
      const assigned = await flexiAssignQuiz(env, flexiquizUserId, quizId);
      if (!assigned.ok) {
        warnings.push("flexiquiz_assign_failed");
        await audit(env, "quiz.assign.failed", {
          studentId,
          classSessionId,
          deviceId,
          payload: { email, quizId, flexiquizUserId, status: assigned.status, body: assigned.body }
        });
      }
      flexiUserProfile = await flexiGetUserProfile(env, flexiquizUserId) ?? flexiUserProfile;
    }
  } else {
    return json({ error: "flexiquiz_user_not_confirmed", warnings }, 502);
  }

  const flexiquizUserName = flexiUserProfile?.userName || email;
  const launchUrl = await buildFlexiQuizSsoUrl(env, flexiquizUserName, quizId);

  if (studentId && classSessionId) {
    await ensureProgressParents(env, {
      studentId,
      classSessionId,
      oemsId: oemsId || studentId,
      firstName: firstName || "Unknown",
      lastName: lastName || "Student",
      email,
      courseTitle,
      courseDate
    });
    await writeProgress(env, {
      studentId,
      classSessionId,
      didOpenQuiz: true,
      deviceId
    });
  }

  await audit(env, "quiz.assign.requested", {
    studentId,
    classSessionId,
    deviceId,
    payload: { email, quizId, flexiquizUserId: flexiquizUserId ?? null, flexiquizUserName, warnings }
  });

  return json({
    ok: true,
    email,
    quizId,
    launchUrl,
    flexiquizUserId,
    flexiquizUserName,
    warnings
  });
}

async function flexiFindUserId(env: Env, userName: string): Promise<string | undefined> {
  const response = await flexiPost(env, "/v1/users/find", {
    user_name: userName
  });

  if (!response.ok) {
    return undefined;
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  return stringField(data, "user_id");
}

async function flexiQuizStatus(env: Env, quizId: string): Promise<{ ok: boolean; status: number; body?: string }> {
  const response = await flexiGet(env, `/v1/quizzes/${encodeURIComponent(quizId)}`);
  const text = await response.text().catch(() => "");
  if (!response.ok) {
    return { ok: false, status: response.status, body: text };
  }

  const data = text ? parseJsonRecord(text) ?? {} : {};
  const status = stringField(data, "status")?.toLowerCase();
  if (status && status !== "open") {
    return { ok: false, status: 409, body: text };
  }

  return { ok: true, status: response.status };
}

async function flexiCreateUser(
  env: Env,
  input: {
    userName: string;
    email: string;
    firstName: string;
    lastName: string;
    password: string;
  }
): Promise<string | undefined> {
  const response = await flexiPost(env, "/v1/users", {
    user_name: input.userName,
    password: input.password,
    user_type: "respondent",
    email_address: input.email,
    first_name: input.firstName,
    last_name: input.lastName,
    suspended: "false",
    manage_users: "false",
    manage_groups: "false",
    edit_quizzes: "false",
    send_welcome_email: "true"
  });

  if (!response.ok) {
    return undefined;
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  return stringField(data, "user_id");
}

async function flexiGetUserProfile(env: Env, userId: string): Promise<FlexiUserProfile | undefined> {
  const response = await flexiGet(env, `/v1/users/${encodeURIComponent(userId)}`);
  if (!response.ok) {
    return undefined;
  }
  const payload = await response.json<unknown>().catch(() => undefined);
  const record = recordFromPayload(payload);
  if (!record) {
    return undefined;
  }
  const userName = stringField(record, "user_name");
  const resolvedUserId = stringField(record, "user_id") ?? userId;
  if (!userName) {
    return undefined;
  }
  return {
    userId: resolvedUserId,
    userName,
    email: stringField(record, "email_address"),
    quizzes: arrayField(record, "quizzes").filter(isJsonRecord)
  };
}

function flexiUserHasQuiz(profile: FlexiUserProfile, quizId: string): boolean {
  return profile.quizzes.some((record) =>
    stringField(record, "quiz_id") === quizId ||
    stringField(record, "quizId") === quizId
  );
}

async function flexiUserHasQuizByEndpoint(env: Env, userId: string, quizId: string): Promise<boolean> {
  const response = await flexiGet(env, `/v1/users/${encodeURIComponent(userId)}/quizzes`);
  if (!response.ok) {
    return false;
  }
  const payload = await response.json<unknown>().catch(() => undefined);
  return recordsFromPayload(payload).some((record) => stringField(record, "quiz_id") === quizId || stringField(record, "quizId") === quizId);
}

async function flexiAssignQuiz(env: Env, userId: string, quizId: string): Promise<{ ok: boolean; status: number; body?: string }> {
  const response = await flexiPost(env, `/v1/users/${encodeURIComponent(userId)}/quizzes`, {
    quiz_id: quizId
  });
  return {
    ok: response.ok,
    status: response.status,
    body: response.ok ? undefined : await response.text().catch(() => undefined)
  };
}

async function flexiPost(env: Env, path: string, fields: Record<string, string>): Promise<Response> {
  const url = new URL(joinUrl(env.FLEXIQUIZ_API_BASE, path));
  const body = new URLSearchParams();
  for (const [key, value] of Object.entries(fields)) {
    body.set(key, value);
  }

  return await fetch(url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/x-www-form-urlencoded; charset=utf-8",
      "x-api-key": env.FLEXIQUIZ_API_KEY ?? ""
    },
    body
  });
}

async function quizReview(url: URL, env: Env): Promise<Response> {
  const quizId = decodeURIComponent(url.pathname.split("/").pop() ?? "");
  const email = url.searchParams.get("email")?.trim();
  const studentId = url.searchParams.get("studentId")?.trim();
  const classSessionId = url.searchParams.get("classSessionId")?.trim();
  const deviceId = url.searchParams.get("deviceId")?.trim();

  if (!quizId) {
    return json({ error: "missing_quiz_id" }, 400);
  }

  if (!env.FLEXIQUIZ_API_KEY) {
    return json({ error: "flexiquiz_not_configured" }, 503);
  }

  if (!email) {
    const cached = await cachedQuizReview(env, quizId);
    if (cached) {
      return json(cached);
    }
    return json({ error: "missing_email" }, 400);
  }

  const flexiquizUserId = await flexiFindUserId(env, email);
  if (!flexiquizUserId) {
    return json({ error: "flexiquiz_user_not_found" }, 404);
  }

  const responses = await flexiListResponses(env, flexiquizUserId, quizId);
  const latest = responses.find((item) => responseLooksCompleted(item)) ?? responses[0];
  if (!latest) {
    return json({ error: "review_not_found" }, 404);
  }

  const responseId = responseIdFrom(latest);
  const warnings: string[] = [];
  let detail: JsonRecord | undefined;

  if (responseId) {
    detail = await flexiResponseDetail(env, flexiquizUserId, quizId, responseId);
    if (!detail) {
      warnings.push("response_detail_unavailable");
    }
  } else {
    warnings.push("response_id_unavailable");
  }

  const reportUrl = firstText([detail, latest], [
    "response_report_url",
    "responseReportUrl",
    "report_url",
    "review_url",
    "reviewUrl"
  ]);
  let reportHtml: string | undefined;
  if (reportUrl) {
    reportHtml = await fetchTextLimited(reportUrl, 250_000).catch(() => undefined);
    if (!reportHtml) {
      warnings.push("response_report_unavailable");
    }
  }

  const review = normalizeQuizReview({
    quizId,
    latest,
    detail,
    reportHtml,
    fallbackResponseId: responseId,
    fallbackReportUrl: reportUrl,
    warnings
  });

  if (studentId && classSessionId) {
    await audit(env, "quiz.review.requested", {
      studentId,
      classSessionId,
      deviceId,
      payload: {
        quizId,
        responseId: review.responseId ?? null,
        scoreText: review.scoreText ?? null,
        passed: review.passed ?? null,
        questionCount: review.questions.length,
        questions: review.questions.slice(0, 100).map((question) => ({
          prompt: question.prompt,
          isCorrect: question.isCorrect ?? null,
          feedback: question.feedback ?? null
        })),
        warnings: review.warnings
      }
    });
    await saveQuizAttempt(env, {
      studentId,
      classSessionId,
      flexiquizUserId,
      review
    }).catch((error) => console.warn("quiz attempt save failed", error));
  }

  return json(review);
}

async function saveQuizAttempt(
  env: Env,
  input: {
    studentId: string;
    classSessionId: string;
    flexiquizUserId?: string;
    review: QuizReviewPayload;
  }
): Promise<void> {
  const now = new Date().toISOString();
  const attemptId = input.review.responseId ?? crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO quiz_attempts (
      id, student_id, class_session_id, flexiquiz_user_id, quiz_id, response_id,
      result_text, score_text, passed, review_url, review_released, completed_at,
      created_at, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, 1, ?11, ?12, ?12)
    ON CONFLICT(id) DO UPDATE SET
      flexiquiz_user_id = excluded.flexiquiz_user_id,
      quiz_id = excluded.quiz_id,
      response_id = excluded.response_id,
      result_text = excluded.result_text,
      score_text = excluded.score_text,
      passed = excluded.passed,
      review_url = excluded.review_url,
      review_released = 1,
      completed_at = excluded.completed_at,
      updated_at = excluded.updated_at`
  ).bind(
    attemptId,
    input.studentId,
    input.classSessionId,
    input.flexiquizUserId ?? null,
    input.review.quizId,
    input.review.responseId ?? null,
    input.review.resultText ?? null,
    input.review.scoreText ?? null,
    input.review.passed === undefined ? null : boolInt(input.review.passed),
    input.review.reportUrl ?? null,
    input.review.completedAt ?? now,
    now
  ).run();
}

async function cachedQuizReview(env: Env, attemptId: string): Promise<QuizReviewPayload | undefined> {
  const row = await env.DB.prepare(
    `SELECT id, quiz_id, response_id, result_text, score_text, passed, review_url, review_released, completed_at
     FROM quiz_attempts WHERE id = ?1 OR response_id = ?1`
  ).bind(attemptId).first<JsonRecord>();

  if (!row || row.review_released !== 1) {
    return undefined;
  }

  return {
    ok: true,
    quizId: stringField(row, "quiz_id") ?? attemptId,
    responseId: stringField(row, "response_id") ?? stringField(row, "id"),
    resultText: stringField(row, "result_text"),
    scoreText: stringField(row, "score_text"),
    passed: boolFromUnknown(row.passed),
    completedAt: stringField(row, "completed_at"),
    reportUrl: stringField(row, "review_url"),
    questions: [],
    warnings: ["cached_attempt_has_no_question_detail"]
  };
}

async function flexiListResponses(env: Env, userId: string, quizId: string): Promise<JsonRecord[]> {
  const response = await flexiPost(env, `/v1/users/${encodeURIComponent(userId)}/responses`, {
    quiz_id: quizId,
    limit: "10",
    order: "desc"
  });

  if (!response.ok) {
    throw new HttpError(502, "flexiquiz_responses_failed");
  }

  const payload = await response.json<unknown>().catch(() => undefined);
  return recordsFromPayload(payload);
}

async function flexiResponseDetail(
  env: Env,
  userId: string,
  quizId: string,
  responseId: string
): Promise<JsonRecord | undefined> {
  const paths = [
    `/v1/users/${encodeURIComponent(userId)}/responses/${encodeURIComponent(responseId)}`,
    `/v1/quizzes/${encodeURIComponent(quizId)}/responses/${encodeURIComponent(responseId)}`,
    `/v1/responses/${encodeURIComponent(responseId)}`
  ];

  for (const path of paths) {
    const response = await flexiGet(env, path);
    if (!response.ok) {
      continue;
    }
    const payload = await response.json<unknown>().catch(() => undefined);
    const record = recordFromPayload(payload);
    if (record) {
      return record;
    }
  }

  return undefined;
}

async function flexiGet(env: Env, path: string): Promise<Response> {
  const url = new URL(joinUrl(env.FLEXIQUIZ_API_BASE, path));
  return await fetch(url, {
    method: "GET",
    headers: {
      accept: "application/json",
      "x-api-key": env.FLEXIQUIZ_API_KEY ?? ""
    }
  });
}

function normalizeQuizReview(input: {
  quizId: string;
  latest: JsonRecord;
  detail?: JsonRecord;
  reportHtml?: string;
  fallbackResponseId?: string;
  fallbackReportUrl?: string;
  warnings: string[];
}): QuizReviewPayload {
  const sources = [input.detail, recordField(input.detail, "content"), recordField(input.detail, "response"), input.latest, recordField(input.latest, "content")]
    .filter(isJsonRecord);
  const questions = normalizeQuestionRecords(questionRecordsFromSources(sources));
  const htmlQuestions = questions.length > 0 ? [] : parseQuestionsFromReportHtml(input.reportHtml);

  if (questions.length === 0 && htmlQuestions.length === 0) {
    input.warnings.push("question_detail_unavailable");
  }

  const resultText = firstText(sources, ["result_text", "resultText", "result", "status", "pass_fail", "outcome"]);
  const scoreText = firstText(sources, ["score_text", "scoreText", "score", "percentage", "percent", "grade"]);
  const passed = boolFromUnknown(firstValue(sources, ["passed", "pass", "is_passed", "isPassed", "success"])) ??
    passStatusFromText(resultText ?? scoreText) ??
    passStatusFromScore(scoreText);

  return {
    ok: true,
    quizId: input.quizId,
    responseId: firstText(sources, ["response_id", "responseId", "id", "response_guid", "responseGuid"]) ?? input.fallbackResponseId,
    resultText,
    scoreText,
    passed,
    completedAt: firstText(sources, ["completed_at", "completedAt", "date_completed", "submitted_at", "submit_date", "finished_at"]),
    reportUrl: input.fallbackReportUrl,
    questions: questions.length > 0 ? questions : htmlQuestions,
    warnings: input.warnings
  };
}

function responseLooksCompleted(response: JsonRecord): boolean {
  const status = firstText([response], ["status", "state", "result", "result_text"])?.toLowerCase() ?? "";
  if (/(complete|completed|submitted|finished|pass|fail)/.test(status)) {
    return true;
  }
  return Boolean(firstText([response], ["completed_at", "completedAt", "date_completed", "submitted_at", "submit_date"]));
}

function responseIdFrom(response: JsonRecord): string | undefined {
  return firstText([response], ["response_id", "responseId", "id", "response_guid", "responseGuid"]);
}

function recordsFromPayload(payload: unknown): JsonRecord[] {
  if (Array.isArray(payload)) {
    return payload.filter(isJsonRecord);
  }
  if (!isJsonRecord(payload)) {
    return [];
  }
  const arrays = [
    payload.content,
    payload.responses,
    payload.data,
    payload.items,
    recordField(payload, "content")?.responses,
    recordField(payload, "content")?.items
  ];
  for (const value of arrays) {
    if (Array.isArray(value)) {
      return value.filter(isJsonRecord);
    }
  }
  return [payload];
}

function recordFromPayload(payload: unknown): JsonRecord | undefined {
  if (isJsonRecord(payload)) {
    return recordField(payload, "content") ?? recordField(payload, "data") ?? recordField(payload, "response") ?? payload;
  }
  if (Array.isArray(payload)) {
    return payload.find(isJsonRecord);
  }
  return undefined;
}

function questionRecordsFromSources(sources: JsonRecord[]): JsonRecord[] {
  for (const source of sources) {
    const direct = [
      source.questions,
      source.answers,
      source.question_answers,
      source.questionAnswers,
      source.responses,
      source.items,
      source.results
    ];
    for (const value of direct) {
      if (Array.isArray(value)) {
        const records = value.filter(isJsonRecord);
        if (records.some(looksLikeQuestionRecord)) {
          return records;
        }
      }
    }

    const deep = deepQuestionRecords(source, 0);
    if (deep.length > 0) {
      return deep;
    }
  }
  return [];
}

function deepQuestionRecords(value: unknown, depth: number): JsonRecord[] {
  if (depth > 4) {
    return [];
  }
  if (Array.isArray(value)) {
    const records = value.filter(isJsonRecord);
    if (records.length > 0 && records.some(looksLikeQuestionRecord)) {
      return records;
    }
    for (const item of value) {
      const nested = deepQuestionRecords(item, depth + 1);
      if (nested.length > 0) {
        return nested;
      }
    }
    return [];
  }
  if (!isJsonRecord(value)) {
    return [];
  }
  for (const item of Object.values(value)) {
    const nested = deepQuestionRecords(item, depth + 1);
    if (nested.length > 0) {
      return nested;
    }
  }
  return [];
}

function looksLikeQuestionRecord(record: JsonRecord): boolean {
  return Boolean(firstText([record], ["question", "question_text", "questionText", "prompt", "title", "text", "name"])) &&
    Boolean(firstValue([record], ["answer", "user_answer", "userAnswer", "student_answer", "selected_answer", "correct_answer", "correctAnswer", "is_correct", "isCorrect"]));
}

function normalizeQuestionRecords(records: JsonRecord[]): QuizReviewQuestion[] {
  return records.map((record, index) => {
    const prompt = firstText([record], ["question_text", "questionText", "question", "prompt", "title", "text", "name"]) ?? `Question ${index + 1}`;
    const studentAnswer = answerText(firstValue([record], ["user_answer", "userAnswer", "student_answer", "studentAnswer", "selected_answer", "selectedAnswer", "response", "answer"]));
    const correctAnswer = answerText(firstValue([record], ["correct_answer", "correctAnswer", "right_answer", "rightAnswer", "expected_answer", "expectedAnswer"]));
    const isCorrect = boolFromUnknown(firstValue([record], ["is_correct", "isCorrect", "correct", "was_correct", "wasCorrect", "passed", "result"])) ??
      correctnessFromText(firstText([record], ["result", "status"]));
    return {
      id: firstText([record], ["id", "question_id", "questionId"]),
      number: intFromUnknown(firstValue([record], ["number", "question_number", "questionNumber", "order", "position"])) ?? index + 1,
      prompt: cleanText(prompt),
      choices: stringArrayFromUnknown(firstValue([record], ["choices", "options", "possible_answers", "possibleAnswers", "answers"])),
      studentAnswer,
      correctAnswer,
      isCorrect,
      feedback: firstText([record], ["feedback", "feedback_text", "feedbackText", "comment", "comments", "explanation", "rationale"])?.trim(),
      points: firstText([record], ["points", "score", "mark", "marks"])
    };
  });
}

function parseQuestionsFromReportHtml(html?: string): QuizReviewQuestion[] {
  if (!html) {
    return [];
  }
  const plain = cleanText(stripTags(html));
  if (!plain.toLowerCase().includes("question")) {
    return [];
  }
  const chunks = plain.split(/\bQuestion\s+\d+[:.)-]?\s*/i).slice(1);
  return chunks.slice(0, 100).map((chunk, index) => {
    const isCorrect = correctnessFromText(chunk);
    const feedback = regexValue(chunk, /Feedback\s*[:\-]\s*([^]+?)(?=\s*(?:Question\s+\d+|Correct Answer|Your Answer|$))/i);
    return {
      number: index + 1,
      prompt: cleanText(chunk.split(/Your Answer|Correct Answer|Feedback/i)[0] ?? `Question ${index + 1}`),
      studentAnswer: regexValue(chunk, /Your Answer\s*[:\-]\s*([^]+?)(?=\s*(?:Correct Answer|Feedback|Question\s+\d+|$))/i),
      correctAnswer: regexValue(chunk, /Correct Answer\s*[:\-]\s*([^]+?)(?=\s*(?:Feedback|Question\s+\d+|$))/i),
      isCorrect,
      feedback
    };
  }).filter((question) => question.prompt.length > 0);
}

async function fetchTextLimited(url: string, limit: number): Promise<string | undefined> {
  const response = await fetch(url, { headers: { accept: "text/html, text/plain;q=0.9" } });
  if (!response.ok || !response.body) {
    return undefined;
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let received = 0;
  let text = "";

  while (received < limit) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    received += value.byteLength;
    text += decoder.decode(value, { stream: true });
  }
  text += decoder.decode();
  await reader.cancel().catch(() => undefined);
  return text;
}

async function sendEmailEndpoint(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const to = stringField(body, "to");
  const subject = stringField(body, "subject");
  const messagePlainText = stringField(body, "messagePlainText");
  const messageHTML = stringField(body, "messageHTML");
  const attachmentGuid = stringField(body, "attachmentGuid");

  if (!to || !subject || !messagePlainText) {
    return json({ error: "missing_email_fields" }, 400);
  }

  const result = await sendSmarterMail(env, {
    to,
    subject,
    messagePlainText,
    messageHTML,
    attachmentGuid
  });

  return json(result);
}

async function aiCommentsEndpoint(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const studentName = stringField(body, "studentName") ?? "The student";
  const courseTitle = stringField(body, "courseTitle") ?? "the course";
  const context = stringField(body, "context") ?? "course completion";
  const studentId = stringField(body, "studentId");
  const classSessionId = stringField(body, "classSessionId");

  const analytics = studentId && classSessionId
    ? await buildStudentCommentAnalytics(env, studentId, classSessionId)
    : emptyCommentAnalytics();

  const fallback = studentCommentFallback(studentName, courseTitle, analytics);
  if (!env.AI) {
    return json({
      success: true,
      comment: fallback,
      usedFallback: true,
      reason: "workers_ai_not_configured",
      analytics
    });
  }

  try {
    const response = await env.AI.run("@cf/meta/llama-3.1-8b-instruct-fp8", {
      messages: [
        {
          role: "system",
          content: [
            "You write concise EMS academy instructor comments for skills validation and course completion records.",
            "Write one polished paragraph, 55 to 85 words.",
            "Return only the paragraph text. Do not introduce it or explain it.",
            "Use the student's first name naturally and avoid gendered pronouns unless provided.",
            "Be specific, positive, and professional.",
            "If analytics include growth topics, frame them as continued review or reinforcement, not failure.",
            "Do not invent exam scores, certifications, attendance, or clinical facts not provided.",
            "Do not mention AI, analytics, payloads, quizzes, or raw data."
          ].join(" ")
        },
        {
          role: "user",
          content: JSON.stringify({
            studentName,
            courseTitle,
            context,
            analytics,
            fallbackToneExamples: [
              `${studentName} demonstrated steady engagement throughout ${courseTitle}, contributed appropriately during class activities, and showed a professional approach to continued EMS development.`,
              `${studentName} completed ${courseTitle} with a positive attitude and consistent participation. Continued review of targeted course topics will help reinforce the material covered today.`
            ]
          })
        }
      ],
      max_tokens: 180,
      temperature: 0.55
    });

    const comment = cleanGeneratedComment(textFromUnknown(response.response));
    if (comment && comment.includes(studentName.split(/\s+/)[0] ?? studentName) && comment.length >= 50) {
      return json({
        success: true,
        comment,
        usedFallback: false,
        analytics
      });
    }

    return json({
      success: true,
      comment: fallback,
      usedFallback: true,
      reason: "ai_response_failed_validation",
      analytics
    });
  } catch (error) {
    console.warn("aicomments failed", error);
    return json({
      success: true,
      comment: fallback,
      usedFallback: true,
      reason: "ai_generation_failed",
      analytics
    });
  }
}

async function buildStudentCommentAnalytics(
  env: Env,
  studentId: string,
  classSessionId: string
): Promise<StudentCommentAnalytics> {
  const attemptsResult = await env.DB.prepare(
    `SELECT quiz_id, result_text, score_text, passed, completed_at, updated_at
     FROM quiz_attempts
     WHERE student_id = ?1 AND class_session_id = ?2
     ORDER BY COALESCE(completed_at, updated_at) ASC`
  ).bind(studentId, classSessionId).all<JsonRecord>();

  const attempts = attemptsResult.results ?? [];
  const scores = attempts.map((attempt) => numericScore(stringField(attempt, "score_text"))).filter((score): score is number => score !== undefined);
  const averageScore = scores.length > 0
    ? Math.round((scores.reduce((sum, score) => sum + score, 0) / scores.length) * 10) / 10
    : undefined;
  const passedQuizCount = attempts.filter((attempt) => boolFromUnknown(attempt.passed) === true).length;
  const quizSummaries = attempts.slice(0, 8).map((attempt, index) => {
    const score = stringField(attempt, "score_text");
    const result = quizResultSummary(attempt);
    return `Quiz ${index + 1}: ${[result, score && !result.includes(score) ? score : undefined].filter(Boolean).join(" ")}`;
  });

  const reviewEvents = await env.DB.prepare(
    `SELECT payload_json
     FROM audit_events
     WHERE student_id = ?1
       AND class_session_id = ?2
       AND event_type = 'quiz.review.requested'
     ORDER BY created_at DESC
     LIMIT 25`
  ).bind(studentId, classSessionId).all<JsonRecord>();

  const strengths = new Map<string, number>();
  const growth = new Map<string, number>();
  for (const row of reviewEvents.results ?? []) {
    const payload = parseJsonRecord(stringField(row, "payload_json") ?? "");
    const questions = Array.isArray(payload?.questions) ? payload.questions.filter(isJsonRecord) : [];
    for (const question of questions) {
      const topic = topicFromQuestion(question);
      if (!topic) {
        continue;
      }
      const correct = boolFromUnknown(question.isCorrect);
      if (correct === true) {
        strengths.set(topic, (strengths.get(topic) ?? 0) + 1);
      } else if (correct === false) {
        growth.set(topic, (growth.get(topic) ?? 0) + 1);
      }
    }
  }

  return {
    averageScore,
    completedQuizCount: attempts.length,
    passedQuizCount,
    strongestTopics: topMapKeys(strengths, 3),
    growthTopics: topMapKeys(growth, 3),
    quizSummaries
  };
}

function emptyCommentAnalytics(): StudentCommentAnalytics {
  return {
    completedQuizCount: 0,
    passedQuizCount: 0,
    strongestTopics: [],
    growthTopics: [],
    quizSummaries: []
  };
}

function studentCommentFallback(studentName: string, courseTitle: string, analytics: StudentCommentAnalytics): string {
  const firstName = studentName.split(/\s+/)[0] || studentName;
  if (analytics.strongestTopics.length > 0 || analytics.growthTopics.length > 0) {
    const strength = analytics.strongestTopics[0] ?? "core EMS concepts";
    const growth = analytics.growthTopics[0] ?? "continued review of course material";
    return `${firstName} completed ${courseTitle} with engaged participation and a professional approach to the training day. Their exam review showed solid performance in ${strength}, and continued reinforcement of ${growth} will help strengthen retention moving forward. ${firstName} remained attentive, receptive to feedback, and focused on improving throughout the course.`;
  }
  if (analytics.averageScore !== undefined && analytics.completedQuizCount > 0) {
    const performance = analytics.averageScore >= 85 ? "strong" : analytics.averageScore >= 70 ? "satisfactory" : "developing";
    return `${firstName} completed ${courseTitle} with ${performance} progress across the day's assessments and consistent participation in class activities. They remained professional, attentive, and receptive to feedback throughout the session. Continued review of the course objectives will help reinforce the material and support confident application in the field.`;
  }
  return `${firstName} completed ${courseTitle} with consistent participation, a positive attitude, and a professional approach to the learning environment. They remained engaged with the course material and receptive to instructor feedback throughout the session. Continued review of the day's key objectives will help reinforce understanding and support future EMS practice.`;
}

function cleanGeneratedComment(value?: string): string | undefined {
  if (!value) {
    return undefined;
  }
  return value
    .replace(/^["'\s]+|["'\s]+$/g, "")
    .replace(/^here(?:'s| is)\s+(?:a|the)?\s*(?:polished\s+)?(?:paragraph|comment)[^:]*:\s*/i, "")
    .replace(/^comment:\s*/i, "")
    .trim();
}

function numericScore(value?: string): number | undefined {
  if (!value) {
    return undefined;
  }
  const match = value.match(/(\d+(?:\.\d+)?)/);
  if (!match) {
    return undefined;
  }
  const score = Number.parseFloat(match[1]);
  return Number.isFinite(score) ? score : undefined;
}

function topicFromQuestion(question: JsonRecord): string | undefined {
  const source = [
    firstText([question], ["topic", "category", "objective", "tag"]),
    firstText([question], ["prompt", "question", "questionText", "question_text"]),
    firstText([question], ["feedback", "feedbackText", "feedback_text"])
  ].filter(Boolean).join(" ");
  const normalized = source.toLowerCase();
  const topicPatterns: Array<[string, RegExp]> = [
    ["airway management", /\bairway|ventilat|oxygen|breath|respirat|bag.?valve|bvm\b/],
    ["cardiology", /\bcardiac|heart|chest pain|ecg|ekg|stroke|shock|aed\b/],
    ["trauma assessment", /\btrauma|bleed|hemorrhage|fracture|spinal|burn|head injury\b/],
    ["medical assessment", /\bdiabetes|seizure|allerg|overdose|poison|medical assessment|altered mental\b/],
    ["communication skills", /\bcommunicat|handoff|report|radio|documentation|consent|scene size.?up\b/],
    ["operations and safety", /\bsafety|hazmat|incident command|triage|lifting|ppe|scene\b/],
    ["pediatric care", /\bpediatric|child|infant|newborn|pepp\b/],
    ["obstetrics", /\bobstetric|pregnan|delivery|newborn\b/]
  ];
  return topicPatterns.find(([, pattern]) => pattern.test(normalized))?.[0];
}

function topMapKeys(map: Map<string, number>, count: number): string[] {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, count)
    .map(([key]) => key);
}

async function buildFlexiQuizSsoUrl(env: Env, userName: string, quizId: string): Promise<string> {
  const jwt = await signHs256(
    { alg: "HS256", typ: "JWT" },
    {
      user_name: userName,
      exp: Math.floor(Date.now() / 1000) + 5 * 60
    },
    env.FLEXIQUIZ_SSO_SHARED_SECRET ?? ""
  );
  const url = new URL(env.FLEXIQUIZ_AUTH_URL);
  url.searchParams.set("cla", "t");
  url.searchParams.set("jwt", jwt);
  url.searchParams.set("quiz_id", quizId);
  return url.toString();
}

async function signHs256(header: JsonRecord, payload: JsonRecord, secret: string): Promise<string> {
  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signingInput));
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

async function sendSmarterMail(
  env: Env,
  message: {
    to: string;
    subject: string;
    messagePlainText: string;
    messageHTML?: string;
    attachmentGuid?: string;
  }
): Promise<JsonRecord> {
  const missing = [
    ["SM_USERNAME", env.SM_USERNAME],
    ["SM_PASSWORD", env.SM_PASSWORD],
    ["FROM_ADDRESS", env.FROM_ADDRESS],
    ["REPLY_TO_ADDRESS", env.REPLY_TO_ADDRESS]
  ].filter(([, value]) => !value).map(([name]) => name);

  if (missing.length > 0) {
    return { ok: false, error: "smartermail_not_configured", missing };
  }

  const authResponse = await fetch(joinUrl(env.SM_BASE_URL, env.SM_AUTH), {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      username: env.SM_USERNAME,
      password: env.SM_PASSWORD
    })
  });

  if (!authResponse.ok) {
    return { ok: false, error: "smartermail_auth_failed", status: authResponse.status };
  }

  const authJson = await authResponse.json<JsonRecord>().catch(() => ({}));
  const token = stringField(authJson, "accessToken") ??
    stringField(authJson, "token") ??
    stringField(authJson, "jwt");

  const payload: JsonRecord = {
    from: env.FROM_ADDRESS,
    replyTo: env.REPLY_TO_ADDRESS,
    to: message.to,
    subject: message.subject,
    messagePlainText: message.messagePlainText,
    messageHTML: message.messageHTML ?? message.messagePlainText
  };

  if (message.attachmentGuid) {
    payload.attachmentGuid = message.attachmentGuid;
  }

  const sendResponse = await fetch(joinUrl(env.SM_BASE_URL, env.SM_SEND_EMAIL), {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {})
    },
    body: JSON.stringify(payload)
  });

  return { ok: sendResponse.ok, status: sendResponse.status };
}

async function audit(
  env: Env,
  eventType: string,
  fields: {
    studentId?: string | null;
    classSessionId?: string | null;
    actorId?: string | null;
    deviceId?: string | null;
    payload?: JsonRecord;
  } = {}
): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO audit_events (
      id, event_type, student_id, class_session_id, actor_id, device_id, payload_json
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`
  ).bind(
    crypto.randomUUID(),
    eventType,
    fields.studentId ?? null,
    fields.classSessionId ?? null,
    fields.actorId ?? null,
    fields.deviceId ?? null,
    JSON.stringify(fields.payload ?? {})
  ).run();
}

class HttpError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
  }
}

function progressPath(url: URL): { classSessionId?: string; studentId?: string } {
  const parts = url.pathname.split("/").filter(Boolean);
  return {
    classSessionId: parts[1] ? decodeURIComponent(parts[1]) : undefined,
    studentId: parts[2] ? decodeURIComponent(parts[2]) : undefined
  };
}

async function readJson(request: Request): Promise<JsonRecord> {
  return await request.json<JsonRecord>().catch(() => ({}));
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders
  });
}

function corsHeaders(request: Request): HeadersInit {
  const origin = request.headers.get("origin") ?? "*";
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET,POST,PATCH,OPTIONS",
    "access-control-allow-headers": "content-type,authorization",
    "access-control-max-age": "86400"
  };
}

function boolInt(value: unknown): number {
  return value === true || value === 1 ? 1 : 0;
}

function sessionIdFor(value: string): string {
  const clean = value.trim();
  return clean ? clean.replace(/\//g, "-") : "undated";
}

function stringField(source: JsonRecord, key: string): string | undefined {
  const value = source[key];
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;
}

function recordField(source: JsonRecord | undefined, key: string): JsonRecord | undefined {
  if (!source) {
    return undefined;
  }
  const value = source[key];
  return isJsonRecord(value) ? value : undefined;
}

function arrayField(source: JsonRecord, key: string): unknown[] {
  const value = source[key];
  return Array.isArray(value) ? value : [];
}

function isJsonRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseJsonRecord(value: string): JsonRecord | undefined {
  try {
    const parsed: unknown = JSON.parse(value);
    return isJsonRecord(parsed) ? parsed : undefined;
  } catch {
    return undefined;
  }
}

function answer(answers: JsonRecord, qid: string): JsonRecord | undefined {
  return recordField(answers, qid);
}

function answerObject(answers: JsonRecord, qid: string): JsonRecord {
  return recordField(answer(answers, qid), "answer") ?? {};
}

function answerString(answers: JsonRecord, qid: string): string {
  const field = answer(answers, qid);
  if (!field) {
    return "";
  }

  const raw = field.answer;
  if (typeof raw === "string") {
    return raw.trim();
  }
  if (Array.isArray(raw)) {
    return raw.map(String).join(", ").trim();
  }
  if (isJsonRecord(raw)) {
    return firstNonEmpty(
      stringField(raw, "full"),
      stringField(raw, "datetime"),
      stringField(raw, "date"),
      [stringField(raw, "first"), stringField(raw, "last")].filter(Boolean).join(" ")
    );
  }

  return stringField(field, "text") ?? "";
}

function firstNonEmpty(...values: Array<string | undefined>): string {
  return values.find((value) => value !== undefined && value.trim().length > 0)?.trim() ?? "";
}

function firstValue(sources: JsonRecord[], keys: string[]): unknown {
  for (const source of sources) {
    for (const key of keys) {
      if (source[key] !== undefined && source[key] !== null && source[key] !== "") {
        return source[key];
      }
    }
  }
  return undefined;
}

function firstText(sources: Array<JsonRecord | undefined>, keys: string[]): string | undefined {
  return textFromUnknown(firstValue(sources.filter(isJsonRecord), keys));
}

function textFromUnknown(value: unknown): string | undefined {
  if (typeof value === "string") {
    const clean = cleanText(value);
    return clean.length > 0 ? clean : undefined;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (Array.isArray(value)) {
    const joined = value.map(textFromUnknown).filter(Boolean).join(", ");
    return joined || undefined;
  }
  if (isJsonRecord(value)) {
    return firstText([value], ["text", "label", "name", "value", "answer", "title", "full"]);
  }
  return undefined;
}

function answerText(value: unknown): string | undefined {
  if (isJsonRecord(value)) {
    const direct = firstText([value], ["text", "label", "name", "value", "answer", "title", "full"]);
    if (direct) {
      return direct;
    }
    const joined = Object.values(value).map(textFromUnknown).filter(Boolean).join(", ");
    return joined || undefined;
  }
  return textFromUnknown(value);
}

function stringArrayFromUnknown(value: unknown): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined;
  }
  const values = value.map(answerText).filter((item): item is string => Boolean(item && item.trim().length > 0));
  return values.length > 0 ? values : undefined;
}

function boolFromUnknown(value: unknown): boolean | undefined {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value === 1 ? true : value === 0 ? false : undefined;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "yes", "y", "1", "pass", "passed", "correct"].includes(normalized)) {
      return true;
    }
    if (["false", "no", "n", "0", "fail", "failed", "incorrect"].includes(normalized)) {
      return false;
    }
  }
  return undefined;
}

function intFromUnknown(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function passStatusFromText(text?: string): boolean | undefined {
  if (!text) {
    return undefined;
  }
  const normalized = text.toLowerCase();
  if (/\bpass(?:ed)?\b/.test(normalized)) {
    return true;
  }
  if (/\bfail(?:ed)?\b/.test(normalized)) {
    return false;
  }
  return undefined;
}

function passStatusFromScore(text?: string): boolean | undefined {
  if (!text) {
    return undefined;
  }
  const match = text.match(/(\d+(?:\.\d+)?)\s*%?/);
  if (!match) {
    return undefined;
  }
  const score = Number.parseFloat(match[1]);
  return Number.isFinite(score) ? score >= 70 : undefined;
}

function quizResultSummary(attempt: JsonRecord): string {
  const score = stringField(attempt, "score_text");
  const result = stringField(attempt, "result_text");
  const passed = boolFromUnknown(attempt.passed) ?? passStatusFromText(result ?? score) ?? passStatusFromScore(score);
  const status = passed === true ? "Passed" : passed === false ? "Failed" : result;
  return [status, score].filter(Boolean).join(" ").trim() || "Completed";
}

function correctnessFromText(text?: string): boolean | undefined {
  if (!text) {
    return undefined;
  }
  const normalized = text.toLowerCase();
  if (/\bincorrect\b|\bwrong\b/.test(normalized)) {
    return false;
  }
  if (/\bcorrect\b|\bright\b/.test(normalized)) {
    return true;
  }
  return undefined;
}

function cleanText(value: string): string {
  return htmlDecode(value)
    .replace(/\s+/g, " ")
    .trim();
}

function stripTags(value: string): string {
  return value
    .replace(/<script\b[^>]*>[^]*?<\/script>/gi, " ")
    .replace(/<style\b[^>]*>[^]*?<\/style>/gi, " ")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|tr|li|h[1-6])>/gi, "\n")
    .replace(/<[^>]+>/g, " ");
}

function htmlDecode(value: string): string {
  return value
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/gi, "'");
}

function parseDescriptionFields(description: string): { date?: string; time?: string; courseId?: string; ceuValue?: string } {
  const date = regexValue(description, /Date:\s*([^]+?)(?=\s+Time:|\n|$)/i);
  const time = regexValue(description, /Time:\s*([^]+?)(?=\s+Course ID:|\n|$)/i);
  const courseId = regexValue(description, /Course ID:\s*([A-Za-z0-9-]+)/i);
  const ceuValue = regexValue(description, /CEUs?:\s*([\d.]+)/i);
  return {
    date: date ? normalizeDateToMMDDYYYY(date) : undefined,
    time,
    courseId,
    ceuValue
  };
}

function regexValue(source: string, pattern: RegExp): string | undefined {
  const match = source.match(pattern);
  const value = match?.[1]?.trim();
  return value || undefined;
}

function normalizeDateToMMDDYYYY(raw: string): string {
  const value = raw.trim();
  const slash = value.match(/\b(\d{1,2})\/(\d{1,2})\/(\d{4})\b/);
  if (slash) {
    return `${slash[1].padStart(2, "0")}/${slash[2].padStart(2, "0")}/${slash[3]}`;
  }

  const iso = value.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
  if (iso) {
    return `${iso[2]}/${iso[3]}/${iso[1]}`;
  }

  const longDate = value
    .replace(/&/g, ",")
    .replace(/\([^)]*\)/g, "")
    .trim()
    .match(/\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+((?:19|20)\d{2})\b/i);
  if (longDate) {
    const month = monthNumber(longDate[1]);
    return `${month}/${longDate[2].padStart(2, "0")}/${longDate[3]}`;
  }

  return value;
}

function extractDatePart(raw: string): string | undefined {
  const normalized = normalizeDateToMMDDYYYY(raw);
  return normalized || undefined;
}

function monthNumber(month: string): string {
  const months = [
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december"
  ];
  const index = months.indexOf(month.toLowerCase());
  return index >= 0 ? String(index + 1).padStart(2, "0") : "01";
}

function cleanCourseName(value: string): string {
  const trimmed = value.trim();
  const match = trimmed.match(/\s*\([^)]*\)\s*$/);
  if (!match || match.index === undefined) {
    return trimmed;
  }
  const before = trimmed.slice(0, match.index).trim();
  return before || trimmed;
}

function productCategories(product: JsonRecord): string[] | undefined {
  const cid = stringField(product, "cid");
  if (cid) {
    return [cid];
  }

  const raw = product.connectedCategories;
  if (Array.isArray(raw)) {
    return raw.map(String).map((value) => value.trim()).filter(Boolean);
  }
  if (typeof raw === "string") {
    try {
      const parsed: unknown = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed.map(String).map((value) => value.trim()).filter(Boolean);
      }
    } catch {
      return raw
        .replace(/[\[\]'"]/g, "")
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean);
    }
  }

  return undefined;
}

function firstImage(product: JsonRecord): string | undefined {
  const raw = product.images;
  if (Array.isArray(raw)) {
    return raw.map(String).find((value) => value.trim().length > 0)?.trim();
  }
  if (typeof raw === "string") {
    try {
      const parsed: unknown = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed.map(String).find((value) => value.trim().length > 0)?.trim();
      }
    } catch {
      return raw.trim() || undefined;
    }
  }
  return undefined;
}

function base64UrlJson(value: JsonRecord): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function joinUrl(base: string, path: string): string {
  return `${base.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;
}
