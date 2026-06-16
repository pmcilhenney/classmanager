# Class Manager 3.0 Overhaul Plan

## Current State

Class Manager 2.x is a SwiftUI iPad app with a native shell around several embedded web workflows:

- QR scan and roster lookup use `JotFormClient` and native parsing, then route into `WelcomeView`.
- Class check-in/check-out is posted to Jotform with `JotFormClient.postTimeAttendance`.
- Quiz assignment is partly native through `FlexiQuizClient`, but the actual quiz and review flow still runs inside `WKWebView`.
- FlexiQuiz completion and review IDs are scraped from the rendered results page with JavaScript in `FlexiQuizView`.
- Skills verification and elective signatures still open prefilled Jotform URLs in webviews.
- Progress sync is stored in `CKProgressStore` with a local `UserDefaults` fallback and CloudKit public/private save attempts.

The main reliability risks are secret exposure in the app bundle, fragile DOM scraping, slow embedded pages, and CloudKit record conflict behavior that is hard to observe from outside the device.

## 3.0 Product Goals

1. Make the first screen and classroom flow fully native: scan, confirm student, pick class, show action status, and recover from mistakes without leaving the app.
2. Keep Jotform as the record system for current forms while moving data entry to native Swift forms backed by the Jotform API.
3. Move FlexiQuiz account setup, quiz assignment, JWT signing, result ingestion, and review lookup behind a Cloudflare Worker.
4. Replace CloudKit progress with a Worker-backed progression ledger in D1, with optional R2 storage for generated PDFs or signed artifacts.
5. Make student exam review a first-class workflow, not a scraped side effect.
6. Give the app a recognizable GCEMS Academy visual identity.

## Architecture Direction

### iPad App

- SwiftUI app with native workflows and a small API client layer.
- No API secrets in `Info.plist` or app bundle.
- Local device cache with retry queue for poor classroom Wi-Fi.
- App talks only to GCEMS-owned Worker endpoints plus public Jotform/FlexiQuiz URLs when absolutely required.

### Cloudflare Worker

Primary API surface:

- `POST /session/lookup` receives QR/submission ID and returns normalized student/course/session data.
- `POST /attendance/check-in` and `POST /attendance/check-out` submit Jotform records and update progression state.
- `POST /skills/verification` submits skills verification to Jotform and stores local status.
- `POST /quiz/assign` finds or creates FlexiQuiz user, assigns quiz, and returns a one-time SSO launch URL.
- `GET /quiz/review/:attemptId` returns review metadata and a secure review launch URL or normalized answer review data, depending on what FlexiQuiz exposes for the account.
- `GET /progress/:classDate/:studentId` returns current workflow state for device handoff.
- `PATCH /progress/:classDate/:studentId` records state transitions with server timestamps.
- `POST /email/send` sends instructor/student notifications through SmarterMail.

### D1 and R2

D1 tables:

- `students`: normalized student identifiers and last-known contact fields.
- `class_sessions`: course/date/session metadata and Jotform source IDs.
- `student_progress`: check-in, quiz, skills, signature, check-out state.
- `quiz_attempts`: FlexiQuiz quiz ID, response/attempt ID, score, pass/fail, review URL token, completion timestamp.
- `audit_events`: append-only event stream for classroom accountability.
- `outbox`: pending SmarterMail notifications and retry status.

R2 buckets:

- Generated attendance PDFs.
- Signature images or sealed verification packets if Jotform file storage is not enough.
- Optional cached course materials if Jotform-hosted links prove slow.

## Native Workflow Replacements

### 1. Registration Lookup

Keep:

- QR scanner.
- Jotform as source of registration truth.
- Existing parser logic for multiple registration products and refresher appointments.

Replace:

- Web registration sheet with a native upcoming-class browser and native registration confirmation where possible.
- Raw Jotform shape in views with typed `Student`, `ClassSession`, `RegistrationChoice`, and `RosterStatus` models returned by the Worker.

### 2. Attendance

Build:

- Native check-in/check-out buttons with status, timestamps, and retry state.
- Signature capture with `PencilKit` or a simple touch canvas.
- Server-side Jotform submission from Worker, so field mappings and API key stay out of the app.
- PDF generation either in Swift for local preview or Worker/R2 for canonical storage.

### 3. Skills Verification

Build:

- Native checklist-style skills verification view.
- Instructor authentication and lockout in native UI.
- Server-side submission to the current Jotform skills forms.
- Optional SmarterMail receipt to instructor/student after submission.

### 4. Daily Quizzes

Build:

- Native quiz dashboard: assigned, not started, in progress, completed, passed, failed, review available.
- Worker-owned FlexiQuiz user lookup/create/assign.
- Worker-owned JWT SSO generation. FlexiQuiz documents that JWT SSO tokens can be sent by URL parameter or POST, must expire, and are single-use.
- Short-lived in-app quiz launch using `ASWebAuthenticationSession` or a constrained `WKWebView` only for the actual FlexiQuiz test-taking surface if FlexiQuiz does not expose test-taking APIs.

Remove:

- Client-side FlexiQuiz shared secret.
- JS autofill overlay.
- DOM scraping for pass/fail and review IDs.

### 5. Exam Review

High-priority 3.0 feature:

- Capture quiz completion through FlexiQuiz API polling or webhooks into D1.
- Store quiz attempt IDs, result status, score, and response report/review URLs.
- Present a native "Review Exam" button immediately after completion and later from class history.
- Prefer native normalized review data if FlexiQuiz API exposes response details for the account.
- If FlexiQuiz only supports hosted review/report pages, launch those through a Worker-issued short-lived review URL after verifying the student/session.
- Add instructor policy controls: review available immediately, after instructor release, or after class completion.

## Sync and Device Handoff

Replace CloudKit with Worker/D1 for 3.0.

Why:

- CloudKit currently depends on iCloud account/container health on every iPad.
- Cross-device classroom state needs operational visibility and admin repair tools.
- D1 gives a queryable source of truth and audit trail.

Migration path:

1. Add Worker progress APIs while keeping `CKProgressStore` local behavior.
2. Create `ProgressStore` protocol in Swift.
3. Implement `CloudflareProgressStore`.
4. Dual-write CloudKit and Worker for one pilot class.
5. Flip read source to Worker.
6. Remove CloudKit entitlements after confidence.

## SmarterMail Use

Use SmarterMail from the Worker, not directly from the iPad.

Initial email use cases:

- Student quiz/review availability notice.
- Instructor receipt for skills verification.
- Daily class completion digest.
- Failed-sync/admin repair alert.

Expected Worker secrets:

- `SM_BASE_URL`
- `SM_AUTH`
- `SM_SEND_EMAIL`
- `SM_USERNAME`
- `SM_PASSWORD`
- `FROM_ADDRESS`
- `REPLY_TO_ADDRESS`

Open decisions before implementation:

- Exact sender and reply-to addresses.
- Whether students should receive individual receipts by default.
- Whether attachments will use existing SmarterMail `attachmentGuid` values or a separate upload-to-GUID workflow.

## GCEMS Academy Brand Kit

The app should feel like a calm classroom operations tool, not a generic web wrapper.

Palette:

- Academy Navy: `#112B46` for top bars, primary navigation, and high-trust surfaces.
- EMS Red: `#C8292F` for urgent states, destructive actions, and critical badges.
- Clinical Blue: `#1F6FEB` for primary actions and selected states.
- Responder Gold: `#F2B84B` for warnings, pending work, and highlight accents.
- Field Green: `#278A5B` for completed, passed, checked-in, and verified states.
- Slate Ink: `#1F2933` for primary text.
- Fog Gray: `#EEF2F5` for page backgrounds.
- White: `#FFFFFF` for tool panels and forms.

Usage:

- Use navy as the stable brand anchor.
- Use blue for normal forward movement.
- Reserve red for real risk or failed states.
- Use green only for successful completed states.
- Keep forms dense, readable, and touch-friendly for repeated classroom use.

## Suggested Delivery Phases

### Phase 0: Source and Secrets Hygiene

- Push a clean repo to GitHub.
- Remove API secrets from committed files.
- Add local secret configuration and document required values.
- Add a short build/run checklist.

### Phase 1: Worker Skeleton and Progress Ledger

- Build Worker with D1 migrations for progress, quiz attempts, audit events, and outbox.
- Add health endpoint and structured logs.
- Add Swift API client and `CloudflareProgressStore`.
- Keep CloudKit as fallback during pilot.

### Phase 2: Native Attendance

- Replace Jotform attendance web flow with native check-in/out.
- Add native signature capture.
- Submit to Jotform through Worker.
- Store canonical event in D1.

### Phase 3: FlexiQuiz 3.0

- Move FlexiQuiz API key and SSO secret to Worker secrets.
- Implement user lookup/create, quiz assignment, JWT SSO launch, and completion ingestion.
- Add native quiz dashboard and review availability.
- Remove JS autofill and result scraping.

### Phase 4: Native Skills Verification

- Build native skills forms from a Worker-delivered schema.
- Submit to Jotform through Worker.
- Add instructor confirmation and SmarterMail receipts.

### Phase 5: Admin and Repair Tools

- Add a small protected web admin for class-day state.
- Allow instructor/admin to release exam reviews, repair course/session mapping, resend receipts, and inspect device sync status.

## Immediate Technical Notes

- `classmanager/Info.plist` previously stored live-looking Jotform and FlexiQuiz secrets. Those should be rotated before relying on GitHub history cleanliness.
- `FlexiQuizClient` already has a JWT SSO path, but it signs in-app with the shared secret. Move that signing to Worker.
- `FlexiQuizView` and `FlexiWebView` contain the JS overlay and scraping code to retire.
- `CKProgressStore` has careful merge logic, but 3.0 should replace it with a server ledger rather than keep expanding CloudKit conflict handling.
- `SkillsWebView` and `ElectiveSignatureWorkspace` are the next obvious native-form candidates after attendance and quizzes.
