import SwiftUI

struct InstructorDashboardView: View {
    let config: AppConfig
    let jotform: JotFormClient
    let flexi: FlexiQuizClient
    let instructor: ClassManagerAPIClient.InstructorDashboardInstructor
    let attendance: ClassManagerAPIClient.InstructorAttendance

    @State private var dashboard: ClassManagerAPIClient.InstructorDashboardResponse?
    @State private var selectedStudent: ClassManagerAPIClient.DashboardStudent?
    @State private var skillsURL: URL?
    @State private var resetCandidate: ClassManagerAPIClient.DashboardStudent?
    @State private var resetConfirmationText = ""
    @State private var showingResetText = false
    @State private var busy = false
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            List {
                instructorSection
                checkInSection
                quizSection
                finalExamSection
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
                if busy && dashboard == nil {
                    LoadingSpinnerView()
                }
            }
            .task {
                await refresh()
                await poll()
            }
            .sheet(item: $selectedStudent) { student in
                studentDetail(student)
            }
            .sheet(item: Binding(
                get: { skillsURL.map { SkillsURLBox(url: $0) } },
                set: { if $0 == nil { skillsURL = nil } }
            )) { box in
                SkillsWebView(url: box.url)
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

    private var instructorSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(instructor.fullName)
                    .font(.headline)
                Label("Instructor check-in \(formatEasternTime(attendance.checkedInAt))", systemImage: "person.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var checkInSection: some View {
        Section("Student Check-In") {
            let students = dashboard?.students ?? []
            if students.isEmpty {
                Text("No student activity yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(students) { student in
                    Button {
                        selectedStudent = student
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: student.didCheckIn ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(student.didCheckIn ? .green : .secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(student.fullName.isEmpty ? student.studentId : student.fullName)
                                    .foregroundStyle(.primary)
                                Text(student.courseTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(student.checkInAt.map(formatEasternTime) ?? "Not checked in")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(student.didCheckIn ? .green : .secondary)
                        }
                    }
                }
            }
        }
    }

    private var quizSection: some View {
        Section("Quiz Results") {
            let rows = (dashboard?.quizResults ?? []).prefix(30)
            if rows.isEmpty {
                Text("Quiz results will appear here as students complete sections.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows)) { result in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(commonQuizName(result.quizId))
                            Text(studentName(result.studentId, result.classSessionId))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(scoreText(result.scoreText, result.resultText))
                                .font(.subheadline.weight(.semibold))
                            if let completedAt = result.completedAt ?? result.updatedAt {
                                Text(formatEasternTime(completedAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var finalExamSection: some View {
        Section("Overall Exam Grades") {
            let rows = dashboard?.finalResults ?? []
            if rows.isEmpty {
                Text("Overall grades will appear after FlexiQuiz submits the final exam.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { result in
                    HStack(spacing: 12) {
                        Image(systemName: result.passed == false ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(result.passed == false ? .red : .green)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(studentName(result.studentId, result.classSessionId))
                            Text(result.quizName ?? commonQuizName(result.quizId))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(scoreText(result.scoreText, result.resultText))
                                .font(.headline)
                                .foregroundStyle(result.passed == false ? .red : .green)
                            if let completedAt = result.completedAt ?? result.updatedAt {
                                Text(formatEasternTime(completedAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
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

                Section("Instructor Actions") {
                    Button {
                        Task { await openSkills(for: student) }
                    } label: {
                        Label("Verify Skills", systemImage: "checklist.checked")
                    }

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
            let loaded = try await ClassManagerAPIClient.shared.fetchInstructorDashboard(limit: 120)
            await MainActor.run { dashboard = loaded }
        } catch {
            await MainActor.run { notice = "Could not load instructor dashboard." }
        }
    }

    private func poll() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await refresh()
        }
    }

    private func openSkills(for student: ClassManagerAPIClient.DashboardStudent) async {
        guard !config.skillsFormId.isEmpty else {
            await MainActor.run { notice = "Skills validation form is not configured." }
            return
        }

        do {
            _ = try await ClassManagerAPIClient.shared.markSkillsOpened(
                studentId: student.studentId,
                classSessionId: student.classSessionId,
                instructorPersonId: instructor.personId
            )
        } catch {
            await MainActor.run { notice = "Could not log skills verification." }
        }

        await MainActor.run {
            skillsURL = buildSkillsURL(for: student)
            selectedStudent = nil
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

    private func buildSkillsURL(for student: ClassManagerAPIClient.DashboardStudent) -> URL? {
        guard var comps = URLComponents(string: "https://form.jotform.com/\(config.skillsFormId)") else { return nil }
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            items.append(URLQueryItem(name: name, value: value))
        }
        add("studentFirst", student.firstName)
        add("studentLast", student.lastName)
        add("njOems", student.oemsId ?? student.studentId)
        add("courseId", student.courseId)
        add("studentEmail", student.email)
        add("instructorFirst", instructor.fullName)
        add("instructor6digit", instructor.personId)
        add("theseComments", "Instructor skills verification opened from the ClassManager dashboard.")
        addDateQueryItems(student.courseDate, to: &items)
        comps.queryItems = items
        return comps.url
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

    private func scoreText(_ score: String?, _ result: String?) -> String {
        [score, result]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func commonQuizName(_ quizId: String?) -> String {
        switch quizId {
        case "refresher-a-quiz-1", "66564166-9de9-4b17-9c2d-6f76bc186970": return "Refresher A Quiz 1"
        case "refresher-a-quiz-2": return "Refresher A Quiz 2"
        case "refresher-a-quiz-3": return "Refresher A Quiz 3"
        case "refresher-a-quiz-4": return "Refresher A Quiz 4"
        case QuizInfo.refresherACombinedQuizId: return "Refresher A Version A"
        case QuizInfo.refresherAVersionBQuizId: return "Refresher A Version B"
        default: return quizId ?? "Quiz"
        }
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

private struct SkillsURLBox: Identifiable {
    let id = UUID()
    let url: URL
}
