import SwiftUI

struct InstructorPhoneView: View {
    let config: AppConfig
    let jotform: JotFormClient
    let flexi: FlexiQuizClient

    @State private var showingScanner = false
    @State private var showingSessionPicker = false
    @State private var sessionOptions: [RegistrationOption] = []
    @State private var attendee: RosterAttendee?
    @State private var selectedQuiz: QuizInfo?
    @State private var selectedReviewQuiz: QuizInfo?
    @State private var busy = false
    @State private var notice: String?
    @StateObject private var progressStore = CKProgressStore()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Student QR", systemImage: "qrcode.viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(busy)
                }

                if let attendee {
                    Section("Student") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(attendee.fullName)
                                .font(.title3.weight(.semibold))
                            Text(cleanCourseName(attendee.courseType))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let date = attendee.courseDate, !date.isEmpty {
                                Label(date, systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !attendee.oemsId.isEmpty {
                                Label("OEMS \(attendee.oemsId)", systemImage: "number")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Progress") {
                        progressRow("Checked In", systemImage: "checkmark.circle", isDone: progressStore.progress.didCheckIn)
                        progressRow("Opened Skills", systemImage: "checklist", isDone: progressStore.progress.didOpenSkills)
                        progressRow("Opened Exam", systemImage: "doc.text.magnifyingglass", isDone: progressStore.progress.didOpenQuiz)
                        progressRow("Checked Out", systemImage: "rectangle.portrait.and.arrow.right", isDone: progressStore.progress.didCheckOut)
                    }

                    Section("Exams") {
                        let quizzes = quizzesForCourse(attendee.courseType)
                        if quizzes.isEmpty {
                            Text("No exams configured for this course.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(quizzes) { quiz in
                                let isCompleted = progressStore.progress.completedQuizIDs.contains(quiz.id)
                                Button {
                                    if isCompleted {
                                        selectedReviewQuiz = quiz
                                    } else {
                                        selectedQuiz = quiz
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: isCompleted ? "checkmark.seal.fill" : "doc.text")
                                            .foregroundStyle(isCompleted ? .green : .blue)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(quiz.title)
                                                .foregroundStyle(.primary)
                                            if let result = progressStore.progress.quizResults[quiz.id] {
                                                Text(result)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(isCompleted ? "Review" : "Open")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            processCompletion(for: attendee)
                        } label: {
                            Label("Process Course Completion", systemImage: "checkmark.seal")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .disabled(busy || progressStore.progress.didCheckOut)
                    }
                } else {
                    Section {
                        Text("Scan a student QR code to view class progress and instructor actions.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Instructor")
            .overlay {
                if busy {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .sheet(isPresented: $showingScanner) {
                QRScannerView { code in
                    showingScanner = false
                    Task { await loadStudent(from: code) }
                }
            }
            .sheet(isPresented: $showingSessionPicker) {
                SessionPickerView(
                    isPresented: $showingSessionPicker,
                    options: sessionOptions,
                    title: "Select Session",
                    subtitle: attendee?.fullName,
                    onlyShowToday: false
                ) { option in
                    apply(option)
                }
            }
            .sheet(item: $selectedQuiz) { quiz in
                if let attendee {
                    QuizWorkspaceView(
                        config: config,
                        attendee: attendee,
                        jotform: jotform,
                        flexi: flexi,
                        quiz: quiz,
                        onSSOLoaded: {
                            progressStore.markQuiz()
                        }
                    )
                }
            }
            .sheet(item: $selectedReviewQuiz) { quiz in
                if let attendee {
                    QuizReviewView(
                        config: config,
                        attendee: attendee,
                        quiz: quiz
                    )
                }
            }
            .alert(notice ?? "", isPresented: Binding(
                get: { notice != nil },
                set: { if !$0 { notice = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func progressRow(_ title: String, systemImage: String, isDone: Bool) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? .green : .secondary)
        }
    }

    private func loadStudent(from qrString: String) async {
        let submissionId = qrString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submissionId.isEmpty else { return }

        await MainActor.run {
            busy = true
            notice = nil
            selectedQuiz = nil
            selectedReviewQuiz = nil
        }
        defer { Task { @MainActor in busy = false } }

        do {
            let lookup = try await ClassManagerAPIClient.shared.lookupSession(submissionId: submissionId)
            await MainActor.run {
                attendee = lookup.attendee
                sessionOptions = lookup.options
            }

            if lookup.options.count > 1 {
                await MainActor.run { showingSessionPicker = true }
            } else {
                await loadProgress(for: lookup.attendee)
            }
        } catch {
            await MainActor.run {
                notice = "Could not load student registration."
            }
        }
    }

    private func apply(_ option: RegistrationOption) {
        guard var current = attendee else { return }
        current.courseType = option.courseType
        current.courseDate = option.dateRaw
        current.courseId = option.courseId
        current.ceuValue = option.ceuValue
        current.productCategories = option.productCategories
        current.courseImageURL = option.courseImageURL
        current.courseLocation = option.courseLocation
        attendee = current
        selectedQuiz = nil
        selectedReviewQuiz = nil
        Task { await loadProgress(for: current) }
    }

    private func loadProgress(for attendee: RosterAttendee) async {
        await progressStore.load(oemsId: attendee.oemsId, courseDate: attendee.courseDate)
        await progressStore.fetchLatestAndMerge()
    }

    private func processCompletion(for attendee: RosterAttendee) {
        let isElective = attendee.productCategories?.contains("2002") ?? false
        let formId = isElective ? electiveFormId : refresherCheckInOutFormId
        guard !formId.isEmpty else {
            notice = isElective ? "Elective form ID is not configured." : "Refresher check-out form is not configured."
            return
        }

        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                _ = try await ClassManagerAPIClient.shared.submitAttendance(
                    formId: formId,
                    inOut: "Check-Out",
                    attendee: attendee,
                    fields: isElective ? electiveFields(for: attendee) : refresherFields(for: attendee)
                )
                progressStore.markCheckOut()
                notice = "Course completion processed."
            } catch {
                notice = "Could not process completion."
            }
        }
    }

    private var electiveFormId: String {
        (Bundle.main.object(forInfoDictionaryKey: "Elective_Form_ID") as? String) ?? ""
    }

    private var refresherCheckInOutFormId: String {
        (Bundle.main.object(forInfoDictionaryKey: "Refresher_CheckInOut_Form") as? String) ?? ""
    }

    private func electiveFields(for attendee: RosterAttendee) -> [String: String] {
        var fields: [String: String] = [:]
        add("name[first]", attendee.firstName, to: &fields)
        add("name[last]", attendee.lastName, to: &fields)
        add("email", attendee.email, to: &fields)
        add("typeA", attendee.oemsId, to: &fields)
        add("courseTitle", cleanCourseName(attendee.courseType), to: &fields)
        add("status", "2", to: &fields)
        add("courseId", attendee.courseId, to: &fields)
        add("ceuValue", attendee.ceuValue, to: &fields)
        add("courseLocation", attendee.courseLocation, to: &fields)
        add("verified", "Yes", to: &fields)
        add("courseStart", attendee.courseDate, to: &fields)
        add("prefillapp", "1", to: &fields)
        return fields
    }

    private func refresherFields(for attendee: RosterAttendee) -> [String: String] {
        var fields: [String: String] = [:]
        add("firstName", attendee.firstName, to: &fields)
        add("lastName", attendee.lastName, to: &fields)
        add("njOems", attendee.oemsId, to: &fields)
        add("courseId", attendee.courseId, to: &fields)
        add("courseType", cleanCourseName(attendee.courseType), to: &fields)
        add("inout", "Check-Out", to: &fields)
        add("dob", attendee.dob, to: &fields)
        add("appform", "1", to: &fields)
        add("date", nowAttendanceString(), to: &fields)
        return fields
    }

    private func add(_ key: String, _ value: String?, to fields: inout [String: String]) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        fields[key] = value
    }

    private func quizzesForCourse(_ courseType: String) -> [QuizInfo] {
        let normalized = cleanCourseName(courseType).uppercased()
        if normalized.contains("REFRESHER A") {
            return QuizInfo.refresherAQuizzes()
        } else if normalized.contains("REFRESHER B") {
            return QuizInfo.refresherBQuizzes()
        } else if normalized.contains("REFRESHER C") {
            return QuizInfo.refresherCQuizzes()
        }
        return []
    }

    private func cleanCourseName(_ value: String) -> String {
        if let range = value.range(of: #"\s*\([^)]*\)$"#, options: .regularExpression) {
            return String(value[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return value.trimmingCharacters(in: .whitespaces)
    }

    private func nowAttendanceString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        formatter.dateFormat = "MM/dd/yyyy HH:mm"
        return formatter.string(from: Date())
    }
}
