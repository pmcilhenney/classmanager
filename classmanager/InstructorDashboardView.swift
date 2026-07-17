import PencilKit
import SwiftUI

struct InstructorDashboardView: View {
    let config: AppConfig
    let jotform: JotFormClient
    let flexi: FlexiQuizClient
    let instructor: ClassManagerAPIClient.InstructorDashboardInstructor
    let initialCourse: ClassManagerAPIClient.InstructorCourse?
    let courses: [ClassManagerAPIClient.InstructorCourse]
    let initialAttendance: ClassManagerAPIClient.InstructorAttendance?

    @State private var dashboard: ClassManagerAPIClient.InstructorDashboardResponse?
    @State private var selectedCourse: ClassManagerAPIClient.InstructorCourse?
    @State private var attendance: ClassManagerAPIClient.InstructorAttendance?
    @State private var selectedStudent: ClassManagerAPIClient.DashboardStudent?
    @State private var skillsURL: URL?
    @State private var isPreparingSkillsForm = false
    @State private var resetCandidate: ClassManagerAPIClient.DashboardStudent?
    @State private var resetConfirmationText = ""
    @State private var showingResetText = false
    @State private var attendanceAction: InstructorAttendanceAction?
    @State private var busy = false
    @State private var notice: String?

    private var availableCourses: [ClassManagerAPIClient.InstructorCourse] {
        let remote = dashboard?.courses ?? []
        return courses.isEmpty ? remote : courses
    }

    private var activeCourse: ClassManagerAPIClient.InstructorCourse? {
        selectedCourse ?? initialCourse
    }

    init(
        config: AppConfig,
        jotform: JotFormClient,
        flexi: FlexiQuizClient,
        instructor: ClassManagerAPIClient.InstructorDashboardInstructor,
        initialCourse: ClassManagerAPIClient.InstructorCourse?,
        courses: [ClassManagerAPIClient.InstructorCourse],
        initialAttendance: ClassManagerAPIClient.InstructorAttendance? = nil
    ) {
        self.config = config
        self.jotform = jotform
        self.flexi = flexi
        self.instructor = instructor
        self.initialCourse = initialCourse
        self.courses = courses
        self.initialAttendance = initialAttendance
        _attendance = State(initialValue: initialAttendance)
    }

    var body: some View {
        NavigationStack {
            Group {
                if attendance == nil {
                    checkInGate
                } else {
                    dashboardList
                }
            }
            .navigationTitle("Instructor Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(busy)
                }
            }
            .overlay {
                if busy {
                    LoadingSpinnerView()
                }
            }
            .task {
                if selectedCourse == nil {
                    selectedCourse = initialCourse
                }
                await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .ckRemoteNotificationReceived)) { notification in
                Task { await handleRemoteDashboardUpdate(notification.userInfo) }
            }
            .sheet(item: $selectedStudent) { student in
                studentDetail(student)
            }
            .sheet(isPresented: Binding(
                get: { isPreparingSkillsForm || skillsURL != nil },
                set: { isPresented in
                    if !isPresented {
                        skillsURL = nil
                        isPreparingSkillsForm = false
                        Task { await refresh() }
                    }
                }
            )) {
                NavigationStack {
                    ZStack {
                        if let skillsURL {
                            SkillsWebView(url: skillsURL)
                        } else {
                            LoadingSpinnerView()
                        }
                    }
                    .navigationTitle("Skills Verification")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                skillsURL = nil
                                isPreparingSkillsForm = false
                                Task { await refresh() }
                            }
                        }
                    }
                }
            }
            .sheet(item: $attendanceAction) { action in
                if let course = activeCourse {
                    InstructorAttendanceCaptureSheet(
                        instructorName: instructor.fullName,
                        course: course,
                        inOut: action.inOut,
                        onCancel: { attendanceAction = nil },
                        onSubmit: { attestation in
                            attendanceAction = nil
                            Task { await submitAttendance(inOut: action.inOut, attestation: attestation) }
                        }
                    )
                }
            }
            .confirmationDialog(
                "Reset this student's ClassManager progress?",
                isPresented: Binding(
                    get: { resetCandidate != nil && !showingResetText },
                    set: { if !$0 && !showingResetText { resetCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Continue to Reset", role: .destructive) {
                    resetConfirmationText = ""
                    showingResetText = true
                }
                Button("Cancel", role: .cancel) {
                    resetCandidate = nil
                }
            } message: {
                Text("This removes ClassManager check-in, quiz, final exam, and skills progress for this student in this session.")
            }
            .alert("Type RESET STUDENT", isPresented: $showingResetText) {
                TextField("RESET STUDENT", text: $resetConfirmationText)
                    .textInputAutocapitalization(.characters)
                Button("Reset", role: .destructive) {
                    Task { await resetSelectedStudent() }
                }
                .disabled(resetConfirmationText != "RESET STUDENT")
                Button("Cancel", role: .cancel) {
                    resetCandidate = nil
                    resetConfirmationText = ""
                }
            } message: {
                Text("Final confirmation required. This does not delete the student's FlexiQuiz account.")
            }
            .alert(notice ?? "", isPresented: Binding(
                get: { notice != nil },
                set: { if !$0 { notice = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var checkInGate: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "person.badge.clock")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(instructor.fullName)
                    .font(.title2.weight(.semibold))
                Text(activeCourse?.title ?? "Select a course")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if let date = activeCourse?.date, !date.isEmpty {
                    Label(date, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !availableCourses.isEmpty {
                Picker("Course", selection: Binding(
                    get: { activeCourse?.id ?? "" },
                    set: { id in
                        selectedCourse = id.isEmpty ? nil : availableCourses.first { $0.id == id }
                        attendance = nil
                        Task { await refresh() }
                    }
                )) {
                    Text("Choose a course").tag("")
                    ForEach(availableCourses) { course in
                        Text(coursePickerLabel(course)).tag(course.id)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.bordered)
            }

            Button {
                attendanceAction = InstructorAttendanceAction(inOut: "Check-In")
            } label: {
                Label("CHECK IN", systemImage: "signature")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: 420)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(activeCourse == nil || busy)

            if busy {
                LoadingSpinnerView()
            }

            Spacer()
        }
        .padding(32)
    }

    private var dashboardList: some View {
        List {
            instructorSection
            rosterSection
        }
    }

    private var instructorSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(instructor.fullName)
                    .font(.headline)
                if !availableCourses.isEmpty {
                    Picker("Course", selection: Binding(
                        get: { activeCourse?.id ?? "" },
                        set: { id in
                            selectedCourse = id.isEmpty ? nil : availableCourses.first { $0.id == id }
                            attendance = nil
                            Task { await refresh() }
                        }
                    )) {
                        Text("Choose a course").tag("")
                        ForEach(availableCourses) { course in
                            Text(coursePickerLabel(course)).tag(course.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if let attendance {
                    Label("Checked in \(formatEasternTime(attendance.checkedInAt))", systemImage: "person.badge.clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let checkedOut = attendance.checkedOutAt {
                        Label("Checked out \(formatEasternTime(checkedOut))", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            attendanceAction = InstructorAttendanceAction(inOut: "Check-Out")
                        } label: {
                            Label("Check Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var rosterSection: some View {
        Section("Expected Roster") {
            let students = dashboard?.students ?? []
            if students.isEmpty {
                Text("No expected students found for this course yet.")
                    .foregroundStyle(.secondary)
            } else {
                let arrived = students.filter(\.didCheckIn).count
                HStack {
                    Label("\(arrived)/\(students.count) arrived", systemImage: "person.2")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                ForEach(students) { student in
                    Button {
                        selectedStudent = student
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: studentStatusIcon(student))
                                .foregroundStyle(studentStatusColor(student))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(student.fullName.isEmpty ? student.studentId : student.fullName)
                                    .foregroundStyle(.primary)
                                Text(student.didCheckIn ? "Checked in \(student.checkInAt.map(formatEasternTime) ?? "")" : "Expected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                studentQuickStatus(student)
                            }
                            Spacer()
                            if student.didCheckOut {
                                Text("Out")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            } else if student.didCheckIn {
                                Text("Here")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func studentQuickStatus(_ student: ClassManagerAPIClient.DashboardStudent) -> some View {
        let quizSummary = quizCompletionSummary(for: student)
        let final = currentFinalResult(for: student)
        let versionB = versionBStatus(for: student)
        let passedExam = hasPassedFinalExam(student)
        HStack(spacing: 6) {
            if quizSummary.total > 0 {
                statusChip(
                    "\(quizSummary.completed)/\(quizSummary.total) quizzes",
                    color: quizSummary.completed == quizSummary.total ? .green : .blue
                )
            }
            if passedExam {
                statusChip("Passed", color: .green, systemImage: "checkmark.circle.fill")
                if skillsComplete(for: student) {
                    statusChip("Skills complete", color: .green, systemImage: "checkmark.seal.fill")
                } else {
                    statusChip("Skills pending", color: .orange, systemImage: "clock.badge.exclamationmark")
                }
            }
            if let score = finalScoreText(final) {
                statusChip(
                    score,
                    color: final?.passed == false ? .red : (final?.passed == true ? .green : .secondary)
                )
            }
            if let versionB {
                statusChip(versionB.text, color: versionB.color)
            }
        }
    }

    private func statusChip(_ text: String, color: Color, systemImage: String? = nil) -> some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func studentDetail(_ student: ClassManagerAPIClient.DashboardStudent) -> some View {
        NavigationStack {
            List {
                Section("Student") {
                    Text(student.fullName.isEmpty ? student.studentId : student.fullName)
                        .font(.headline)
                    Text(student.courseTitle)
                    if let checkIn = student.checkInAt {
                        Label("Checked in \(formatEasternTime(checkIn))", systemImage: "checkmark.circle")
                    }
                    if let checkOut = student.checkOutAt {
                        Label("Checked out \(formatEasternTime(checkOut))", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("Submitted Quiz Attempts") {
                    let attempts = quizResults(for: student)
                    if attempts.isEmpty {
                        Text("No submitted quiz attempts yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attempts) { result in
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(commonQuizName(result.quizId))
                                    if let completedAt = result.completedAt ?? result.updatedAt {
                                        Text(formatEasternTime(completedAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(scoreText(result.scoreText, result.resultText))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }

                Section("Exam Results") {
                    let results = finalResults(for: student)
                    if results.isEmpty {
                        Text("No overall exam result yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(results) { result in
                            HStack(spacing: 12) {
                                Image(systemName: result.passed == false ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                    .foregroundStyle(result.passed == false ? .red : .green)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.quizName ?? commonQuizName(result.quizId))
                                    if let completedAt = result.completedAt ?? result.updatedAt {
                                        Text(formatEasternTime(completedAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(scoreText(result.scoreText, result.resultText))
                                    .font(.headline)
                                    .foregroundStyle(result.passed == false ? .red : .green)
                            }
                        }
                    }
                }

                Section("Instructor Actions") {
                    let skillsLockedForFailedExams = failedVersionAAndB(student)
                    Button {
                        if skillsLockedForFailedExams {
                            notice = "Skills verification is locked because exams A and B were unsuccessful."
                        } else {
                            Task { await openSkills(for: student) }
                        }
                    } label: {
                        HStack {
                            Label("Verify Skills", systemImage: skillsLockedForFailedExams ? "lock.fill" : "checklist.checked")
                            Spacer()
                            if skillsLockedForFailedExams {
                                Text("failed exams A & B")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .disabled(skillsLockedForFailedExams)

                    Button(role: .destructive) {
                        resetCandidate = student
                    } label: {
                        Label("Reset ClassManager Progress", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedStudent = nil }
                }
            }
        }
    }

    private func refresh() async {
        await MainActor.run { busy = true }
        defer { Task { @MainActor in busy = false } }

        do {
            let course = await MainActor.run { activeCourse }
            let loaded = try await ClassManagerAPIClient.shared.fetchInstructorDashboard(
                limit: 120,
                classSessionId: course?.classSessionId,
                courseId: course?.courseId,
                instructorPersonId: instructor.personId
            )
            await MainActor.run {
                dashboard = loaded
                if selectedCourse == nil {
                    selectedCourse = initialCourse ?? (loaded.course?.isToday == true ? loaded.course : nil)
                }
                attendance = loaded.attendance
            }
        } catch {
            await MainActor.run { notice = "Could not load instructor dashboard." }
        }
    }

    private func handleRemoteDashboardUpdate(_ userInfo: [AnyHashable: Any]?) async {
        guard let userInfo,
              (userInfo["type"] as? String) == "classmanager.instructor_dashboard_update" else {
            return
        }

        let pushedSessionId = userInfo["classSessionId"] as? String
        let currentSessionId = await MainActor.run { activeCourse?.classSessionId }
        guard pushedSessionId == nil || currentSessionId == nil || pushedSessionId == currentSessionId else {
            return
        }

        await refresh()
    }

    private func submitAttendance(inOut: String, attestation: ClassManagerAPIClient.AttendanceAttestation) async {
        guard let course = activeCourse else {
            await MainActor.run { notice = "Select a course before checking in." }
            return
        }

        await MainActor.run { busy = true }
        defer { Task { @MainActor in busy = false } }

        do {
            let response = try await ClassManagerAPIClient.shared.submitInstructorAttendance(
                personId: instructor.personId,
                inOut: inOut,
                course: course,
                attestation: attestation
            )
            await MainActor.run {
                attendance = response.attendance
                notice = inOut == "Check-Out" ? "Instructor checkout complete." : nil
            }
            await refresh()
        } catch {
            await MainActor.run { notice = "Could not submit instructor attendance." }
        }
    }

    private func openSkills(for student: ClassManagerAPIClient.DashboardStudent) async {
        guard let formURL = skillsFormURL(for: student) else {
            await MainActor.run { notice = "Skills validation form is not configured." }
            return
        }

        await MainActor.run {
            selectedStudent = nil
            skillsURL = nil
            isPreparingSkillsForm = true
        }
        defer { Task { @MainActor in isPreparingSkillsForm = false } }

        do {
            _ = try await ClassManagerAPIClient.shared.markSkillsOpened(
                studentId: student.studentId,
                classSessionId: student.classSessionId,
                instructorPersonId: instructor.personId
            )
        } catch {
            await MainActor.run { notice = "Could not log skills verification." }
        }

        let aiComment = await CFAICommentGenerator.generateCommentWithRetry(
            studentName: student.fullName.isEmpty ? student.studentId : student.fullName,
            courseTitle: student.courseTitle,
            context: "skills validation",
            studentId: student.studentId,
            classSessionId: student.classSessionId
        )

        await MainActor.run {
            skillsURL = buildSkillsURL(for: student, formURL: formURL, aiComment: aiComment)
        }
        await refresh()
    }

    private func resetSelectedStudent() async {
        guard let resetCandidate else { return }
        do {
            _ = try await ClassManagerAPIClient.shared.resetStudentProgress(
                personId: instructor.personId,
                studentId: resetCandidate.studentId,
                classSessionId: resetCandidate.classSessionId,
                confirmation: resetConfirmationText
            )
            await MainActor.run {
                notice = "Student progress reset."
                self.resetCandidate = nil
                resetConfirmationText = ""
                selectedStudent = nil
            }
            await refresh()
        } catch {
            await MainActor.run {
                notice = "Could not reset student progress."
                self.resetCandidate = nil
                resetConfirmationText = ""
            }
        }
    }

    private func buildSkillsURL(for student: ClassManagerAPIClient.DashboardStudent, formURL: URL, aiComment: String) -> URL? {
        guard var comps = URLComponents(url: formURL, resolvingAgainstBaseURL: false) else { return nil }
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            items.append(URLQueryItem(name: name, value: value))
        }
        add("studentFirst", student.firstName)
        add("studentLast", student.lastName)
        add("njOems", student.oemsId ?? student.studentId)
        add("courseId", student.courseId)
        add("njCourse", student.courseId)
        add("classSessionId", student.classSessionId)
        add("classManagerStudentId", student.studentId)
        add("typeA90", student.courseId)
        add("q90_typeA90", student.courseId)
        add("q91_classsessionid", student.classSessionId)
        add("classsessionid", student.classSessionId)
        add("q92_classManagerStudentId", student.studentId)
        add("classManagerInstructorPersonId", instructor.personId)
        add("studentEmail", student.email)
        add("instructorFirst", instructor.fullName)
        add("instructor6digit", instructor.oemsId ?? instructor.personId)
        add("instructorEmail", instructor.email)
        add("theseComments", aiComment)
        addDateQueryItems(student.courseDate, to: &items)
        comps.queryItems = items
        return comps.url
    }

    private func skillsFormURL(for student: ClassManagerAPIClient.DashboardStudent) -> URL? {
        let courseType = student.courseTitle.lowercased()
        let key: String
        if courseType.contains("refresher a") || courseType.contains("a refresher") {
            key = "SKILLS_A_VALIDATOR_FORM"
        } else if courseType.contains("refresher b") || courseType.contains("b refresher") {
            key = "SKILLS_B_VALIDATOR_FORM"
        } else if courseType.contains("refresher c") || courseType.contains("c refresher") {
            key = "SKILLS_C_VALIDATOR_FORM"
        } else {
            key = "SKILLS_VALIDATOR_FORM_ID"
        }

        let raw = firstNonEmptyPlistValue(key, "SKILLS_VALIDATOR_FORM_ID", config.skillsFormId)
        guard !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "https://form.jotform.com/\(raw)")
    }

    private func firstNonEmptyPlistValue(_ keysOrValues: String...) -> String {
        for item in keysOrValues {
            let value: String
            if item.contains("_") || item.uppercased() == item {
                value = (Bundle.main.object(forInfoDictionaryKey: item) as? String) ?? ""
            } else {
                value = item
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return ""
    }

    private func addDateQueryItems(_ rawDate: String?, to items: inout [URLQueryItem]) {
        guard let rawDate, !rawDate.isEmpty else { return }
        let formatters = ["MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd"].map { pattern -> DateFormatter in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "America/New_York")
            formatter.dateFormat = pattern
            return formatter
        }
        guard let date = formatters.compactMap({ $0.date(from: rawDate) }).first else { return }
        let parts = Calendar(identifier: .gregorian).dateComponents([.month, .day, .year], from: date)
        if let month = parts.month, let day = parts.day, let year = parts.year {
            items.append(URLQueryItem(name: "date42[month]", value: String(format: "%02d", month)))
            items.append(URLQueryItem(name: "date42[day]", value: String(format: "%02d", day)))
            items.append(URLQueryItem(name: "date42[year]", value: String(format: "%04d", year)))
        }
    }

    private func studentName(_ studentId: String?, _ classSessionId: String?) -> String {
        guard let studentId else { return "Unknown student" }
        let match = dashboard?.students.first {
            $0.studentId == studentId && (classSessionId == nil || $0.classSessionId == classSessionId)
        }
        return match?.fullName.isEmpty == false ? match!.fullName : studentId
    }

    private func quizResults(for student: ClassManagerAPIClient.DashboardStudent) -> [ClassManagerAPIClient.DashboardQuizResult] {
        (dashboard?.quizResults ?? []).filter {
            $0.studentId == student.studentId && $0.classSessionId == student.classSessionId
        }
    }

    private func finalResults(for student: ClassManagerAPIClient.DashboardStudent) -> [ClassManagerAPIClient.DashboardFinalResult] {
        (dashboard?.finalResults ?? []).filter {
            $0.studentId == student.studentId && $0.classSessionId == student.classSessionId
        }
    }

    private func skillsVerification(for student: ClassManagerAPIClient.DashboardStudent) -> ClassManagerAPIClient.DashboardSkillsVerification? {
        (dashboard?.skillsVerifications ?? []).first {
            $0.studentId == student.studentId && $0.classSessionId == student.classSessionId
        }
    }

    private func skillsComplete(for student: ClassManagerAPIClient.DashboardStudent) -> Bool {
        guard let completedAt = skillsVerification(for: student)?.completedAt else { return false }
        return !completedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func currentFinalResult(for student: ClassManagerAPIClient.DashboardStudent) -> ClassManagerAPIClient.DashboardFinalResult? {
        finalResults(for: student).first
    }

    private func hasPassedFinalExam(_ student: ClassManagerAPIClient.DashboardStudent) -> Bool {
        finalResults(for: student).contains { result in
            guard result.passed == true, let quizId = result.quizId else { return false }
            return QuizInfo.isCombinedVersionAQuizId(quizId) || QuizInfo.isVersionBQuizId(quizId)
        }
    }

    private func quizCompletionSummary(for student: ClassManagerAPIClient.DashboardStudent) -> (completed: Int, total: Int) {
        let courseTitle = student.courseTitle.lowercased()
        let expectedTotal: Int
        if courseTitle.contains("refresher a") || courseTitle.contains("refresher b") || courseTitle.contains("refresher c") {
            expectedTotal = 4
        } else {
            expectedTotal = 0
        }

        var completed = Set(quizResults(for: student).compactMap { result -> String? in
            guard let quizId = result.quizId,
                  quizId.contains("-page-") else { return nil }
            return quizId
        }).count

        if expectedTotal == 4,
           finalResults(for: student).contains(where: { result in
               guard let quizId = result.quizId else { return false }
               return QuizInfo.isCombinedVersionAQuizId(quizId)
           }) {
            completed = expectedTotal
        }

        return (min(completed, expectedTotal), expectedTotal)
    }

    private func finalScoreText(_ result: ClassManagerAPIClient.DashboardFinalResult?) -> String? {
        guard let result else { return nil }
        if let points = result.points,
           let available = result.availablePoints,
           available > 0 {
            return "\(Int(points.rounded()))/\(Int(available.rounded()))"
        }
        if let percentage = result.percentageScore {
            return "\(Int(percentage.rounded()))%"
        }
        return scoreText(result.scoreText, result.resultText).isEmpty ? nil : scoreText(result.scoreText, result.resultText)
    }

    private func versionBStatus(for student: ClassManagerAPIClient.DashboardStudent) -> (text: String, color: Color)? {
        let results = finalResults(for: student)
        if let versionBResult = results.first(where: { result in
            guard let quizId = result.quizId else { return false }
            return QuizInfo.isVersionBQuizId(quizId)
        }) {
            if versionBResult.passed == true {
                return ("B passed", .green)
            }
            if versionBResult.passed == false {
                return ("B failed", .red)
            }
            return ("B submitted", .blue)
        }

        let failedVersionA = results.contains { result in
            guard result.passed == false, let quizId = result.quizId else { return false }
            return QuizInfo.isCombinedVersionAQuizId(quizId)
        }
        guard failedVersionA else { return nil }

        let versionBStarted = quizResults(for: student).contains { result in
            guard let quizId = result.quizId else { return false }
            return QuizInfo.isVersionBQuizId(quizId) || quizId.contains("version-b-started")
        }
        return versionBStarted ? ("B in progress", .orange) : ("B required", .orange)
    }

    private func failedVersionAAndB(_ student: ClassManagerAPIClient.DashboardStudent) -> Bool {
        let results = finalResults(for: student)
        let failedVersionA = results.contains { result in
            guard result.passed == false, let quizId = result.quizId else { return false }
            return QuizInfo.isCombinedVersionAQuizId(quizId)
        }
        let failedVersionB = results.contains { result in
            guard result.passed == false, let quizId = result.quizId else { return false }
            return QuizInfo.isVersionBQuizId(quizId)
        }
        return failedVersionA && failedVersionB
    }

    private func scoreText(_ score: String?, _ result: String?) -> String {
        [score, result]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func commonQuizName(_ quizId: String?) -> String {
        switch quizId {
        case "refresher-a-page-1", "refresher-a-quiz-1", "66564166-9de9-4b17-9c2d-6f76bc186970": return "Refresher A Quiz 1"
        case "refresher-a-page-2", "refresher-a-quiz-2", "78df99bd-d81a-4f24-a855-81ea0a3a71ec": return "Refresher A Quiz 2"
        case "refresher-a-page-3", "refresher-a-quiz-3", "772e07cf-d20b-4c8e-a6a5-d2917f5aa5c7": return "Refresher A Quiz 3"
        case "refresher-a-page-4", "refresher-a-quiz-4", "16ca7d9a-d3a4-4a24-85fe-ccb49def519d": return "Refresher A Quiz 4"
        case QuizInfo.refresherACombinedQuizId: return "Refresher A Version A"
        case QuizInfo.refresherAVersionBQuizId: return "Refresher A Version B"
        case "refresher-b-page-1", "3eff7d7c-74d4-44d8-bb4f-b8561c0c62b8": return "Refresher B Quiz 1"
        case "refresher-b-page-2", "67ca0a1e-7c79-4ae7-aa55-418d10e9f3b5": return "Refresher B Quiz 2"
        case "refresher-b-page-3", "e5fdb765-119b-4f5e-905b-c9b7d27ed2bb": return "Refresher B Quiz 3"
        case "refresher-b-page-4", "757c48dc-6ab2-4aad-a262-30ed854157c9": return "Refresher B Quiz 4"
        case QuizInfo.refresherBCombinedQuizId: return "Refresher B Version A"
        case QuizInfo.refresherBVersionBQuizId: return "Refresher B Version B"
        case "refresher-c-page-1", "ab8a5c9d-9e06-42c2-a866-e5759d8b2209": return "Refresher C Quiz 1"
        case "refresher-c-page-2", "d76f4483-d8cc-4029-aea6-a2bebbb3d086": return "Refresher C Quiz 2"
        case "refresher-c-page-3", "b7adaf94-a911-4dad-8152-a5853cb02e35": return "Refresher C Quiz 3"
        case "refresher-c-page-4", "b938cd8b-913c-41bf-b247-1406b11115f2": return "Refresher C Quiz 4"
        case QuizInfo.refresherCCombinedQuizId: return "Refresher C Version A"
        case QuizInfo.refresherCVersionBQuizId: return "Refresher C Version B"
        default: return quizId ?? "Quiz"
        }
    }

    private func coursePickerLabel(_ course: ClassManagerAPIClient.InstructorCourse) -> String {
        let date = course.displayDate ?? (course.date.isEmpty ? "No date" : course.date)
        let timing = course.isToday ? "Today" : (isPastCourse(course) ? "Recent" : "Upcoming")
        return "\(timing): \(date) - \(course.title) (\(course.expectedCount))"
    }

    private func isPastCourse(_ course: ClassManagerAPIClient.InstructorCourse) -> Bool {
        guard let courseDate = dateFromCourseString(course.date) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let today = calendar.startOfDay(for: Date())
        return courseDate < today && !course.isToday
    }

    private func dateFromCourseString(_ rawValue: String) -> Date? {
        let formatters = ["MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd"].map { pattern -> DateFormatter in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "America/New_York")
            formatter.dateFormat = pattern
            return formatter
        }
        return formatters.compactMap { $0.date(from: rawValue) }.first
    }

    private func studentStatusIcon(_ student: ClassManagerAPIClient.DashboardStudent) -> String {
        if student.didCheckOut { return "checkmark.circle.fill" }
        if student.didCheckIn { return "person.crop.circle.badge.checkmark" }
        return "circle"
    }

    private func studentStatusColor(_ student: ClassManagerAPIClient.DashboardStudent) -> Color {
        if student.didCheckOut { return .green }
        if student.didCheckIn { return .blue }
        return .secondary
    }

    private func formatEasternTime(_ rawValue: String) -> String {
        let isoWithFractionalSeconds = ISO8601DateFormatter()
        isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()
        let date = isoWithFractionalSeconds.date(from: rawValue) ?? iso.date(from: rawValue)

        guard let date else { return rawValue }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "MMM d h:mm a"
        return formatter.string(from: date)
    }
}

private struct InstructorAttendanceAction: Identifiable {
    let id = UUID()
    let inOut: String
}

private struct InstructorAttendanceCaptureSheet: View {
    let instructorName: String
    let course: ClassManagerAPIClient.InstructorCourse
    let inOut: String
    let onCancel: () -> Void
    let onSubmit: (ClassManagerAPIClient.AttendanceAttestation) -> Void

    @State private var drawing = PKDrawing()
    @State private var location: AttendanceLocationSnapshot?
    @State private var locationStatus = "Getting location..."
    @State private var isLocating = true
    @State private var locationProvider = LocationAddressProvider()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(inOut)
                        .font(.title2.weight(.semibold))
                    Text(instructorName)
                        .font(.headline)
                    Text(course.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !course.date.isEmpty {
                        Label(course.date, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Label(locationStatus, systemImage: location == nil ? "location" : "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(location == nil ? Color.secondary : Color.green)

                Text("Signature")
                    .font(.headline)

                InstructorSignatureCanvas(drawing: $drawing)
                    .frame(minHeight: 260)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    )

                HStack {
                    Button("Clear") {
                        drawing = PKDrawing()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        submit()
                    } label: {
                        Label("Submit", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(drawing.bounds.isEmpty)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Instructor Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear(perform: loadLocation)
        }
    }

    private func loadLocation() {
        guard isLocating else { return }
        isLocating = true
        locationProvider.getCurrentLocation { snapshot in
            DispatchQueue.main.async {
                self.location = snapshot
                self.isLocating = false
                if let snapshot {
                    if let address = snapshot.address, !address.isEmpty {
                        self.locationStatus = address
                    } else {
                        self.locationStatus = String(format: "%.5f, %.5f", snapshot.latitude, snapshot.longitude)
                    }
                } else {
                    self.locationStatus = "Location unavailable"
                }
            }
        }
    }

    private func submit() {
        let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
        let image = drawing.image(from: bounds, scale: UIScreen.main.scale)
        guard let png = image.pngData() else { return }
        let signedAt = ISO8601DateFormatter().string(from: Date())
        let locationPayload = location.map {
            ClassManagerAPIClient.AttendanceLocation(
                latitude: $0.latitude,
                longitude: $0.longitude,
                horizontalAccuracy: $0.horizontalAccuracy,
                address: $0.address
            )
        }
        let actionText = inOut == "Check-In" ? "checked in to" : "checked out of"
        let attestationText = "I certify that \(instructorName) \(actionText) \(course.title) on \(signedAt)."
        onSubmit(
            ClassManagerAPIClient.AttendanceAttestation(
                signatureDataUrl: "data:image/png;base64,\(png.base64EncodedString())",
                signedAt: signedAt,
                attestationText: attestationText,
                location: locationPayload
            )
        )
    }
}

private struct InstructorSignatureCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.backgroundColor = .clear
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}
