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
      console.error("request failed", error);
      return json({ error: "internal_error" }, 500);
    }
  }
};

async function sessionLookup(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const submissionId = stringField(body, "submissionId");
  const formId = stringField(body, "formId");

  if (!submissionId) {
    return json({ error: "missing_submission_id" }, 400);
  }

  await audit(env, "session.lookup", {
    payload: { submissionId, formId: formId ?? null }
  });

  return json({
    status: "accepted",
    submissionId,
    formId,
    next: "Wire this endpoint to Jotform normalization in the next implementation slice."
  });
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
    courseDate
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
      id, course_id, course_title, course_date, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5)
    ON CONFLICT(id) DO UPDATE SET
      course_id = COALESCE(excluded.course_id, course_id),
      course_title = CASE WHEN excluded.course_title != 'Class Session' THEN excluded.course_title ELSE course_title END,
      course_date = excluded.course_date,
      updated_at = excluded.updated_at`
  ).bind(
    input.classSessionId,
    input.courseId ?? null,
    input.courseTitle,
    input.courseDate,
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

function stringField(source: JsonRecord, key: string): string | undefined {
  const value = source[key];
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;
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
