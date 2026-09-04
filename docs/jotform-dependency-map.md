# Jotform Dependency Map

ClassManager 3.x still treats Jotform as a transition system. RMS and the ClassManager Worker should become the authoritative path for 2027 registration, payment, attendance, evaluations, CPR records, and skills documentation.

## Current Dependencies

### Registration

- Form: `251265925097060`
- Current use: student QR submission IDs, roster lookup, expected roster hydration, course date/title/OEMS approval parsing, launch screen events, instructor course dropdown.
- 2027 replacement: RMS registration/payment portal creates the class registration record directly and issues the student QR payload. Keep old Jotform submission IDs as compatibility aliases only.

### Time And Attendance

- Form: `243577669883075`
- Current use: backup mirror for student check-in/check-out records. Native app signatures, timestamps, device location, and R2 signature images are stored through the Worker/RMS path.
- 2027 replacement: RMS/ClassManager attendance table becomes the only write target, with PDF audit exports generated from RMS data.

### Course Evaluations

- Form: `240184388762060`
- Current use: checkout survey in a WebView, now opened as a Jotform edit submission after Worker prefill. Hidden course fields link anonymous evaluations to class records.
- 2027 replacement: native or RMS-hosted anonymous evaluation form tied to `class_session_id` and NJ OEMS course ID.

### Skills Verification

- Forms: Refresher A/B/C validator forms configured in `Info.plist`.
- Current use: instructor-gated Jotform WebView with hidden fields for class/session/student linkage, then Worker/RMS webhook ingestion.
- 2027 replacement: native instructor skills checklist with RMS write-through and instructor signature reuse from attendance.

### Instructor Identity

- Form: `242266064536154`
- Current use: legacy instructor ID authentication fallback.
- 2027 replacement: RMS People records, instructor role flags, and badge QR scan.

### Course Catalog And Upcoming Events

- Current use: direct app-side and Worker-side registration form queries parse product/course records from Jotform.
- 2027 replacement: RMS class schedule endpoint shared by the launch chip, instructor dropdown, roster preloading, and reporting.

### Webhooks

- Current use: Jotform submissions are upserted into RMS/Worker when configured on the form.
- 2027 replacement: keep webhooks only during migration. Native/RMS forms should write directly to RMS and emit ClassManager APNs from the Worker.

## Migration Priorities

1. Build RMS registration/payment as the source of truth for class sessions, student registrations, and QR payloads.
2. Replace Jotform evaluation and skills WebViews with RMS-native forms so submit completion is not dependent on embedded browser behavior.
3. Retire direct app-side Jotform API access. The Swift app should call only the ClassManager Worker/RMS API.
4. Keep Jotform read/write compatibility endpoints until historical classes and exports are fully backfilled.
