export interface Env {
  DB: D1Database;
  ARTIFACTS: R2Bucket;
  ASSETS: Fetcher;
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

      if (request.method === "GET" && url.pathname.startsWith("/progress/")) {
        return await getProgress(url, env);
      }

      if (request.method === "PATCH" && url.pathname.startsWith("/progress/")) {
        return await patchProgress(request, url, env);
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
  ).bind(classSessionId, studentId).first();

  return json({ classSessionId, studentId, progress: row ?? null });
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
    stringField(body, "checkInAt"),
    stringField(body, "checkOutAt"),
    stringField(body, "deviceId"),
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

  if (!email || !quizId) {
    return json({ error: "missing_email_or_quiz_id" }, 400);
  }

  if (!env.FLEXIQUIZ_API_KEY || !env.FLEXIQUIZ_SSO_SHARED_SECRET) {
    return json({ error: "flexiquiz_not_configured" }, 503);
  }

  const launchUrl = await buildFlexiQuizSsoUrl(env, email, quizId);

  await audit(env, "quiz.assign.requested", {
    studentId: stringField(body, "studentId"),
    classSessionId: stringField(body, "classSessionId"),
    payload: { email, quizId }
  });

  return json({
    ok: true,
    email,
    quizId,
    launchUrl,
    note: "FlexiQuiz user lookup/create/assign will be filled in after API field mapping is finalized."
  });
}

async function quizReview(url: URL, env: Env): Promise<Response> {
  const attemptId = decodeURIComponent(url.pathname.split("/").pop() ?? "");
  if (!attemptId) {
    return json({ error: "missing_attempt_id" }, 400);
  }

  const row = await env.DB.prepare(
    `SELECT id, quiz_id, result_text, score_text, passed, review_url, review_released, completed_at
     FROM quiz_attempts WHERE id = ?1`
  ).bind(attemptId).first();

  if (!row) {
    return json({ error: "review_not_found" }, 404);
  }

  if (row.review_released !== 1) {
    return json({ error: "review_not_released" }, 403);
  }

  return json({ attempt: row });
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
  url.searchParams.set("cb", Math.floor(Date.now() / 1000).toString());
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
