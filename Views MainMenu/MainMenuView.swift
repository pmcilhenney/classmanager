import SwiftUI
import Foundation
import PDFKit
import Combine
import WebKit
import CloudKit
import PencilKit

struct MainMenuView: View {
    let config: AppConfig
    @State private var attendee: RosterAttendee
    let jotform: JotFormClient
    let flexi: FlexiQuizClient
    let onRequestScanNew: (() -> Void)? = nil

    @StateObject var materialsManager: CourseMaterialsManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSkills = false
    @State private var skillsURL: URL?
    @State private var showQuizWorkspace = false
    @State private var showingQRScanner = false

    // UI state
    @State private var busy = false
    @State private var toast: String?
    @State private var generatingComment = false  // AI comment generation

    // Elective/Refresher check-in/out form state
    @State private var showingElectiveForm = false
    @State private var electiveFormURL: URL? = nil
    @State private var electiveFormTitle: String = ""
    // Elective quiz/skills links discovered from materials form
    @State private var electiveQuizLinks: [URL] = []
    @State private var electiveSkillsLink: URL? = nil
    @State private var showingElectiveQuiz = false
    @State private var electiveQuizURL: URL? = nil

    // Course Materials state
    @State private var showingMaterials = false
    @State private var showingCheckoutSurvey = false
    @State private var checkoutSurveyURL: URL? = URL(string: "https://form.jotform.com/240184388762060")
    @State private var attendanceCaptureAction: String?

    //FlexiQuiz State
    @State private var showingQuizzes = false
    @State private var selectedQuiz: QuizInfo? = nil
    @State private var selectedReviewQuiz: QuizInfo? = nil
    @State private var completedQuizzes: Set<String> = []
    @State private var quizTracker = QuizCompletionTracker()

    // Currently selected PDF
    @State private var selectedMaterialURL: URL? = nil
    @State private var showingPDF = false

    // CloudKit state
    @State private var courseId: String = ""
    @State private var didCheckIn = false
    @State private var didCheckOut = false
    @State private var didOpenSkills = false
    @State private var didOpenQuiz = false

    // Instructor gate state
    @State private var showingInstructorGate = false

    // Called when the checkout survey flow completes (thank-you page detected).
    private func checkoutSurveyCompleted() {
        showingCheckoutSurvey = false
        beginAttendanceCapture(inOut: "Check-Out")
    }
    @State private var instructorIdInput: String = ""
    @State private var authenticatedInstructor: InstructorAuthService.Instructor?
    @State private var instructorAuthError: String?

    @StateObject private var progressStore = CKProgressStore()
    // Toast for quiz result with optional review id
    private struct QuizResultToast: Identifiable {
        let id = UUID()
        let quizId: String
        let result: String
        let reviewId: String?
    }
    @State private var quizResultToast: QuizResultToast? = nil
    // When set, this token will be forwarded into the quiz webview to auto-open the review UI
    @State private var pendingReviewId: String? = nil

    // Form IDs from Info.plist
    private var electiveFormId: String {
        (Bundle.main.object(forInfoDictionaryKey: "Elective_Form_ID") as? String) ?? ""
    }

    private var refresherCheckInOutFormId: String {
        (Bundle.main.object(forInfoDictionaryKey: "Refresher_CheckInOut_Form") as? String) ?? ""
    }

    private var skillsFormId: String {
        let courseType = attendee.courseType.lowercased()
        if courseType.contains("refresher a") || courseType.contains("a refresher") {
            return (Bundle.main.object(forInfoDictionaryKey: "SKILLS_A_VALIDATOR_FORM") as? String) ?? ""
        } else if courseType.contains("refresher b") || courseType.contains("b refresher") {
            return (Bundle.main.object(forInfoDictionaryKey: "SKILLS_B_VALIDATOR_FORM") as? String) ?? ""
        } else if courseType.contains("refresher c") || courseType.contains("c refresher") {
            return (Bundle.main.object(forInfoDictionaryKey: "SKILLS_C_VALIDATOR_FORM") as? String) ?? ""
        }
        return ""
    }

    private var materialsFormId: String {
        (Bundle.main.object(forInfoDictionaryKey: "COURSE_MATERIALS_ID") as? String) ?? ""
    }

    init(config: AppConfig, attendee: RosterAttendee, jotform: JotFormClient, flexi: FlexiQuizClient) {
        self.config = config
        self.jotform = jotform
        self.flexi = flexi
        _attendee = State(initialValue: attendee)
        _materialsManager = StateObject(wrappedValue: CourseMaterialsManager(jotformApiKey: config.jotformApiKey, materialsFormId: (Bundle.main.object(forInfoDictionaryKey: "COURSE_MATERIALS_ID") as? String) ?? ""))
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                leftSidebar
                    .frame(width: max(geo.size.width * 0.33, 280))
                Divider()
                rightContent
                    .frame(width: geo.size.width - max(geo.size.width * 0.33, 280))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .overlay(busyOverlay)
        .onAppear(perform: onAppearLoad)
        .onReceive(progressStore.$progress) { _ in
            Task { @MainActor in
                // Merge any CK-synced completions into the visible set for the current course
                let courseQuizIDs = Set(getQuizzesForCourse().map { $0.id })
                let ckIDs = Set(progressStore.progress.completedQuizIDs).intersection(courseQuizIDs)
                completedQuizzes.formUnion(ckIDs)
            }
        }
        .alert(item: Binding(
            get: { toast.map { ToastMessage(id: UUID(), message: $0) } },
            set: { _ in toast = nil }
        )) { (toastItem: ToastMessage) in
            Alert(title: Text("Notice"), message: Text(toastItem.message), dismissButton: .default(Text("OK")))
        }
        .alert(item: $quizResultToast) { toastItem in
            let lower = toastItem.result.lowercased()
            let title = lower.contains("pass") ? "Quiz Passed" : (lower.contains("fail") ? "Quiz Failed" : "Quiz Result")
            let message = lower.contains("pass") ? "\(toastItem.result) Congratulations!" : "\(toastItem.result) Quiz failed. Please review your answers then tap the 'Retake' button to try again."
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text("OK"), action: {
                    // Dismiss behavior: on pass, return to quiz list. On fail, keep the quiz webview open
                    if lower.contains("pass") {
                        selectedQuiz = nil
                    } else {
                        // Keep the current quiz webview open so the user can review their answers.
                        // The toast instructs them to tap the in-page 'Retake' button when ready.
                        // Do not auto-toggle or auto-open review here to avoid unwanted reloads.
                    }
                })
            )
        }
        .sheet(isPresented: $showingInstructorGate) { instructorGateSheet }
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView(onCode: { code in
                showingQRScanner = false
                Task { await handleNewScan(code) }
            })
        }
        .sheet(isPresented: $showingCheckoutSurvey) {
            if let url = checkoutSurveyURL {
                CheckoutSurveyContainer(url: url, onComplete: { checkoutSurveyCompleted() }, onCancel: { showingCheckoutSurvey = false })
            } else {
                Text("Invalid survey URL")
            }
        }
        .sheet(item: Binding(
            get: { attendanceCaptureAction.map { AttendanceCaptureAction(id: $0) } },
            set: { if $0 == nil { attendanceCaptureAction = nil } }
        )) { action in
            AttendanceCaptureSheet(
                attendee: attendee,
                inOut: action.id,
                onCancel: { attendanceCaptureAction = nil },
                onSubmit: { attestation in
                    attendanceCaptureAction = nil
                    submitNativeAttendance(inOut: action.id, attestation: attestation)
                }
            )
        }
    }

    // MARK: - Left Sidebar
    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            attendeeHeader
            Divider().padding(.vertical, 8)
            actionsList
     
            .padding(.top, 6)
            if let imageURLString = attendee.courseImageURL,
               let imageURL = URL(string: imageURLString) {
                Spacer().frame(height: 20)
                CourseImageView(url: imageURL)
            }
            Spacer()
        }
    }

    private var attendeeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.accentColor)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(attendee.firstName) \(attendee.lastName)")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        if !attendee.oemsId.isEmpty { Chip(text: "OEMSID: \(attendee.oemsId)") }
                        if let date = attendee.courseDate { Chip(text: "Date: \(date)") }
                    }
                }
            }
        }
        .padding(.top)
    }

    private var actionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Course Functions")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            VStack(spacing: 10) {
                actionButton(title: "Check In", systemImage: "checkmark.circle", done: progressStore.progress.didCheckIn) {
                    check(inOut: "Check-In")
                }
                checkOutButton()
                
                // CONDITIONAL SKILLS BUTTON
                // Show for Refresher courses (always) OR Elective courses WITH a skills URL
                if shouldShowSkillsButton() {
                    actionButton(title: "Validate Skills", systemImage: "person.crop.circle.badge.checkmark", done: progressStore.progress.didOpenSkills) {
                        // If an elective skills URL was detected for this student, open it
                        // directly. Otherwise fall back to the normal instructor-gated flow.
                        if let skills = electiveSkillsLink {
                            skillsURL = skills
                            showSkills = true
                        } else {
                            showingInstructorGate = true
                        }
                    }
                }
                
                // CONDITIONAL QUIZZES BUTTON
                // Show for Refresher courses (always) OR Elective courses WITH quiz URLs
                if shouldShowQuizzesButton() {
                    Button(action: {
                        if !electiveQuizLinks.isEmpty {
                            // Open the first elective quiz URL in the right pane
                            electiveQuizURL = electiveQuizLinks.first
                            showingElectiveQuiz = true
                            // Ensure quizzes pane isn't shown (we're showing the URL)
                            showingQuizzes = false
                        } else {
                            openQuizzes()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.clipboard").font(.system(size: 20))
                            Text("Quizzes").font(.headline)
                            Spacer()
                            if !completedQuizzes.isEmpty {
                                Text("\(completedQuizzes.count)/4")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                    }
                }
                
                Button { loadCourseMaterials() } label: {
                    HStack {
                        Image(systemName: "books.vertical")
                        Text("Course Materials")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .foregroundColor(.white)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Button Visibility Helpers
    
    /// Determine if Skills button should be shown
    /// - For Elective courses (category 2002): only show if electiveSkillsLink is populated
    /// - For Refresher courses: always show
    private func shouldShowSkillsButton() -> Bool {
        let isElective = attendee.productCategories?.contains("2002") ?? false
        
        if isElective {
            // Elective: only show if we have a skills URL from the materials form
            return electiveSkillsLink != nil
        } else {
            // Refresher: always show
            return true
        }
    }
    
    /// Determine if Quizzes button should be shown
    /// - For Elective courses (category 2002): only show if electiveQuizLinks is not empty
    /// - For Refresher courses: always show
    private func shouldShowQuizzesButton() -> Bool {
        let isElective = attendee.productCategories?.contains("2002") ?? false
        
        if isElective {
            // Elective: only show if we have quiz URLs from the materials form
            return !electiveQuizLinks.isEmpty
        } else {
            // Refresher: always show (hard-coded quiz URLs exist)
            return true
        }
    }

    private func checkOutButton() -> some View {
        let isDone = progressStore.progress.didCheckOut
        let isBlocked = !canCheckOut()
        return Button(action: { check(inOut: "Check-Out") }) {
            HStack {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 18))
                Text("Check Out")
                Spacer(minLength: 8)
                if isDone {
                    ZStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .accessibilityLabel("Completed")
                } else if isBlocked {
                    ZStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .accessibilityLabel("Not Available")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(isDone ? 0.2 : 1.0))
            )
            .foregroundColor(isDone ? .accentColor : .white)
        }
    }

    // MARK: - Right Content
    private var rightContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if !attendee.courseType.isEmpty {
                    CourseChip(courseName: cleanCourseName(attendee.courseType))
                        .frame(maxWidth: .infinity)
                }
                Menu {
                    Button(action: {
                        resetForNewScan()
                        showingQRScanner = true
                    }) {
                        Label("Scan New Student QR Code", systemImage: "qrcode.viewfinder")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(12)
                }
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            ZStack {
                if showingElectiveForm, let url = electiveFormURL {
                    ElectiveFormContainer(url: url, title: electiveFormTitle, onClose: { showingElectiveForm = false })
                } else if showSkills, let url = skillsURL {
                    SkillsWebView(url: url)
                } else if showingElectiveQuiz, let url = electiveQuizURL {
                    WebViewContainer(url: url)
                } else if showingQuizzes {
                    if let quiz = selectedReviewQuiz {
                        QuizReviewView(
                            config: config,
                            attendee: attendee,
                            quiz: quiz
                        )
                    } else if let quiz = selectedQuiz {
                        QuizWorkspaceView(
                            config: config,
                            attendee: attendee,
                            jotform: jotform,
                            flexi: flexi,
                            quiz: quiz,
                            onSSOLoaded: {
                                progressStore.markQuiz()
                            },
                            onBack: { selectedQuiz = nil }
                        )
                    } else {
                        QuizSelectionView(
                            progressStore: progressStore,
                            attendee: attendee,
                            quizURLs: getQuizzesForCourse().map { $0.asInfo() },
                            selectedQuiz: $selectedQuiz,
                            completedQuizzes: $completedQuizzes,
                            onBlocked: { msg in toast = msg },
                            onReview: { quiz in selectedReviewQuiz = quiz }
                        )
                    }
                } else if showingPDF, let url = selectedMaterialURL {
                    pdfViewer(for: url)
                } else if showingMaterials {
                    materialsList
                } else {
                    // Right-side placeholder – show app logo and guidance (no action buttons on right)
                    VStack {
                        Spacer()
                        Image("gcems_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 160)
                            .opacity(0.9)
                        Text("Choose an action from the left to continue")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.top, 12)
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Materials List and Picker
    private var materialsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Course Materials").font(.title2.weight(.semibold)).padding(.bottom, 4)
                Text("Tap a document to open it.").font(.subheadline).foregroundColor(.secondary)
                ForEach(Array(materialsManager.materials.enumerated()), id: \.offset) { _, item in
                    Button(action: {
                        busy = true
                        selectedMaterialURL = item.url
                        showingMaterials = false
                        showingPDF = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { busy = false }
                    }) {
                        HStack {
                            Image(systemName: "doc.richtext")
                            Text(item.title).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Busy Overlay
    private var busyOverlay: some View {
        Group {
            if busy {
                VStack(spacing: 24) {
                    LoadingSpinnerView()
                    if generatingComment {
                        Text("Generating personalized comment...")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
        }
    }

    // MARK: - PDF Viewer
    private func pdfViewer(for url: URL) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    showingPDF = false
                    showingMaterials = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back to Materials")
                    }
                    .font(.headline)
                    .foregroundColor(.accentColor)
                    .padding()
                }
                Spacer()
                Text(url.lastPathComponent.removingPercentEncoding ?? "Document")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back to Materials")
                    }
                    .font(.headline)
                    .padding()
                }
                .opacity(0)
            }
            .background(Color(.systemBackground))
            Divider()
            PDFKitView(url: url)
        }
    }

    // MARK: - Instructor Gate Sheet
    private var instructorGateSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Image("gcems_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .padding(.bottom, 8)
                Text("Instructor Verification").font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Enter your 6-digit Instructor ID to continue.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                TextField("e.g., 123456", text: $instructorIdInput)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                if let error = instructorAuthError, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                Spacer()
                HStack {
                    Button("Cancel") { showingInstructorGate = false }
                    Spacer()
                    Button("Continue") { Task { await authenticateInstructor() } }
                        .disabled(instructorIdInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Instructor Verification")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Lifecycle
    private func onAppearLoad() {
        Task { @MainActor in
            await progressStore.load(oemsId: attendee.oemsId, courseDate: attendee.courseDate ?? "")
            // Ensure we also fetch latest server progress and merge so UI is up-to-date
            await progressStore.fetchLatestAndMerge()
            // Also attempt to load course materials on appear so Accept/Continue from
            // the welcome/review flow immediately wires elective quiz/skills links.
            await materialsManager.loadMaterials(for: attendee.courseType)
            let (skills, quizzes) = electiveExtrasFromCandidates()
            electiveQuizLinks = quizzes
            electiveSkillsLink = skills
                // Ensure we don't auto-show any elective quiz that might have been open
                showingElectiveQuiz = false
                electiveQuizURL = nil
        }
    }

    // MARK: - Reset State for New Scan
    private func resetForNewScan() {
        showSkills = false
        showQuizWorkspace = false
        showingQuizzes = false
        showingElectiveForm = false
        showingMaterials = false
        showingPDF = false
        selectedQuiz = nil
        selectedReviewQuiz = nil
        selectedMaterialURL = nil
        electiveFormURL = nil
        electiveFormTitle = ""
        skillsURL = nil
        electiveQuizLinks = []
        electiveSkillsLink = nil
        showingElectiveQuiz = false
        toast = nil
        busy = false
        generatingComment = false
        didCheckIn = false
        didCheckOut = false
        didOpenSkills = false
        didOpenQuiz = false
        showingInstructorGate = false
        instructorIdInput = ""
        authenticatedInstructor = nil
        instructorAuthError = nil
        materialsManager.clearCache()
    }

    // MARK: - New Scan handler
    private func handleNewScan(_ qrString: String) async {
        let submissionId = qrString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submissionId.isEmpty else { return }
        await MainActor.run { busy = true; toast = nil }
        defer { Task { @MainActor in busy = false } }
        do {
            let lookup = try await ClassManagerAPIClient.shared.lookupSession(submissionId: submissionId)
            let newAttendee = lookup.attendee
            await MainActor.run {
                self.attendee = newAttendee
                resetForNewScan()
                Task { @MainActor in
                    await progressStore.load(oemsId: newAttendee.oemsId, courseDate: newAttendee.courseDate ?? "")
                    // Ensure we also fetch the latest server record and merge immediately so
                    // server-side changes (for example, a remote update) are reflected
                    // as soon as a QR scan loads a new attendee.
                    await progressStore.fetchLatestAndMerge()
                    // Also merge any CK-backed completions into the visible set immediately
                    let courseQuizIDs = Set(getQuizzesForCourse().map { $0.id })
                    let ckIDs = Set(progressStore.progress.completedQuizIDs).intersection(courseQuizIDs)
                    completedQuizzes.formUnion(ckIDs)

                    // Load elective materials (if any) so we can surface elective quiz/skills
                    // quick actions immediately after scanning an elective student.
                    await materialsManager.loadMaterials(for: newAttendee.courseType)
                    // Extract elective extras from any candidates the manager found
                    let (skills, quizzes) = electiveExtrasFromCandidates()
                    electiveQuizLinks = quizzes
                    electiveSkillsLink = skills
                }
                toast = "Loaded new student: \(newAttendee.firstName) \(newAttendee.lastName)"
            }
        } catch {
            await MainActor.run { toast = "Could not load registration data. Please try again." }
        }
    }

    // MARK: - Check In/Out
    private func check(inOut: String) {
        let isElective = attendee.productCategories?.contains("2002") ?? false
        // If this is a check-out action, present the required completion survey first.
        if inOut == "Check-Out" {
            // Build checkout survey URL with courseType param populated from the attendee's course name
            if var comps = URLComponents(string: "https://form.jotform.com/240184388762060") {
                var items: [URLQueryItem] = comps.queryItems ?? []
                let courseName = cleanCourseName(attendee.courseType)
                items.append(URLQueryItem(name: "courseType", value: courseName))
                comps.queryItems = items
                checkoutSurveyURL = comps.url
            } else {
                checkoutSurveyURL = URL(string: "https://form.jotform.com/240184388762060")
            }
            showingCheckoutSurvey = true
            return
        }

        if isElective {
            beginAttendanceCapture(inOut: inOut)
        } else {
            beginAttendanceCapture(inOut: inOut)
        }
    }

    private func canCheckOut() -> Bool { true }

    private func beginAttendanceCapture(inOut: String) {
        if inOut == "Check-Out" && !canCheckOut() {
            toast = "You cannot check out until the class is over."
            return
        }

        let isElective = attendee.productCategories?.contains("2002") ?? false
        let formId = isElective ? electiveFormId : refresherCheckInOutFormId
        guard !formId.isEmpty else {
            toast = isElective ? "Elective form ID not configured." : "Refresher check-in/out form not configured."
            return
        }

        attendanceCaptureAction = inOut
    }

    private func submitNativeAttendance(inOut: String, attestation: ClassManagerAPIClient.AttendanceAttestation) {
        let isElective = attendee.productCategories?.contains("2002") ?? false
        let formId = isElective ? electiveFormId : refresherCheckInOutFormId

        let fields = isElective
            ? electiveAttendanceFields(inOut: inOut)
            : refresherAttendanceFields(inOut: inOut)

        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                _ = try await ClassManagerAPIClient.shared.submitAttendance(
                    formId: formId,
                    inOut: inOut,
                    attendee: attendee,
                    fields: fields,
                    attestation: attestation
                )

                showingElectiveForm = false
                showSkills = false
                showQuizWorkspace = false
                showingMaterials = false

                if inOut == "Check-In" {
                    didCheckIn = true
                    progressStore.markCheckIn()
                } else {
                    didCheckOut = true
                    progressStore.markCheckOut()
                }

                toast = "\(inOut) posted successfully."
            } catch {
                toast = "Failed to post \(inOut). Please try again."
            }
        }
    }

    private func electiveAttendanceFields(inOut: String) -> [String: String] {
        var fields: [String: String] = [:]
        func add(_ name: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            fields[name] = value
        }

        add("name[first]", attendee.firstName)
        add("name[last]", attendee.lastName)
        add("email", attendee.email)
        add("typeA", attendee.oemsId)
        add("courseTitle", cleanCourseName(attendee.courseType))
        add("status", "2")
        add("courseId", attendee.courseId)
        add("ceuValue", attendee.ceuValue)
        add("courseLocation", attendee.courseLocation)
        if inOut == "Check-Out" { add("verified", "Yes") }
        addDobParts(to: &fields, prefix: "birthdate", dob: attendee.dob)
        addTodayParts(to: &fields, prefix: "date")
        add("courseStart", normalizedCourseStart())
        add("prefillapp", "1")
        return fields
    }

    private func refresherAttendanceFields(inOut: String) -> [String: String] {
        var fields: [String: String] = [:]
        func add(_ name: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            fields[name] = value
        }

        add("firstName", attendee.firstName)
        add("lastName", attendee.lastName)
        add("njOems", attendee.oemsId)
        add("courseId", attendee.courseId)
        add("courseType", cleanCourseName(attendee.courseType))
        add("inout", inOut)
        add("dob", attendee.dob)
        add("appform", "1")
        add("date", nowAttendanceString())
        addCourseDateParts(to: &fields, prefix: "courseDate")
        return fields
    }

    private func addDobParts(to fields: inout [String: String], prefix: String, dob: String?) {
        guard let date = parseFlexibleDate(dob) else { return }
        addDateParts(to: &fields, prefix: prefix, date: date)
    }

    private func addTodayParts(to fields: inout [String: String], prefix: String) {
        addDateParts(to: &fields, prefix: prefix, date: Date())
    }

    private func addCourseDateParts(to fields: inout [String: String], prefix: String) {
        guard let date = parseFlexibleDate(attendee.courseDate) else {
            if let courseDate = attendee.courseDate {
                let parts = courseDate.split(separator: "/")
                if parts.count == 3 {
                    fields["\(prefix)[month]"] = String(parts[0])
                    fields["\(prefix)[day]"] = String(parts[1])
                    fields["\(prefix)[year]"] = String(parts[2])
                }
            }
            return
        }
        addDateParts(to: &fields, prefix: prefix, date: date)
    }

    private func addDateParts(to fields: inout [String: String], prefix: String, date: Date) {
        let cal = Calendar(identifier: .gregorian)
        let components = cal.dateComponents([.month, .day, .year], from: date)
        if let month = components.month, let day = components.day, let year = components.year {
            fields["\(prefix)[month]"] = String(format: "%02d", month)
            fields["\(prefix)[day]"] = String(format: "%02d", day)
            fields["\(prefix)[year]"] = String(format: "%04d", year)
        }
    }

    private func normalizedCourseStart() -> String? {
        guard let courseDate = attendee.courseDate else { return nil }
        if let date = parseFlexibleDate(courseDate) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MM/dd/yyyy"
            return formatter.string(from: date)
        }
        return courseDate
    }

    private func nowAttendanceString() -> String {
        let formatter = DateFormatter()
        formatter.locale = .init(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        formatter.dateFormat = "MM/dd/yyyy HH:mm"
        return formatter.string(from: Date())
    }

    private func parseFlexibleDate(_ raw: String?) -> Date? {
        guard var candidate = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty else {
            return nil
        }
        if let range = candidate.range(of: #"(\d{1,2}/\d{1,2}/\d{4})"#, options: .regularExpression) {
            candidate = String(candidate[range])
        } else if let range = candidate.range(of: #"([A-Za-z]+\s+\d{1,2},\s+\d{4})"#, options: .regularExpression) {
            candidate = String(candidate[range])
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        for format in ["MM/dd/yyyy", "M/d/yyyy", "MMMM d, yyyy", "MMM d, yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: candidate) {
                return date
            }
        }
        return nil
    }

    private func showElectiveCheckInOut(inOut: String) {
        guard !electiveFormId.isEmpty else { toast = "Elective form ID not configured."; return }
        let courseLocation = attendee.courseLocation ?? "Location not provided"
        busy = true
        Task { @MainActor in
            defer { busy = false }
            if let url = buildElectivePrefilledURL(inOut: inOut, courseLocation: courseLocation) {
                electiveFormURL = url
                electiveFormTitle = inOut
                showingElectiveForm = true
                showSkills = false
                showQuizWorkspace = false
                showingMaterials = false
                if inOut == "Check-In" { didCheckIn = true; progressStore.markCheckIn() }
                else { didCheckOut = true; progressStore.markCheckOut() }
            } else {
                toast = "Unable to build elective form URL."
            }
        }
    }

    private func buildElectivePrefilledURL(inOut: String, courseLocation: String) -> URL? {
        guard var comps = URLComponents(string: "https://form.jotform.com/\(electiveFormId)") else { return nil }
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) {
            guard let v = value, !v.isEmpty else { return }
            items.append(URLQueryItem(name: name, value: v))
        }
        add("name[first]", attendee.firstName)
        add("name[last]", attendee.lastName)
        add("email", attendee.email)
        add("typeA", attendee.oemsId)
        add("courseTitle", cleanCourseName(attendee.courseType))
        add("status", "2")
        add("courseId", attendee.courseId)
        add("ceuValue", attendee.ceuValue)
        add("courseLocation", attendee.courseLocation)
        if inOut == "Check-Out" { add("verified", "Yes") }
        if let dob = attendee.dob {
            let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "MM/dd/yyyy"
            if let d = df.date(from: dob) {
                let cal = Calendar(identifier: .gregorian)
                let c = cal.dateComponents([.month, .day, .year], from: d)
                if let m = c.month, let day = c.day, let y = c.year {
                    add("birthdate[month]", String(format: "%02d", m))
                    add("birthdate[day]", String(format: "%02d", day))
                    add("birthdate[year]", String(format: "%04d", y))
                }
            }
        }
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let compsNow = cal.dateComponents([.month, .day, .year], from: now)
        if let m = compsNow.month, let d = compsNow.day, let y = compsNow.year {
            add("date[month]", String(format: "%02d", m))
            add("date[day]", String(format: "%02d", d))
            add("date[year]", String(format: "%04d", y))
        }
        if let courseDate = attendee.courseDate {
            var justDate = courseDate
            if let r = courseDate.range(of: #"(\d{2}/\d{2}/\d{4})"#, options: .regularExpression) { justDate = String(courseDate[r]) }
            else if let r = courseDate.range(of: #"([A-Za-z]+\s+\d{1,2},\s+\d{4})"#, options: .regularExpression) { justDate = String(courseDate[r]) }
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "MM/dd/yyyy"
            if let cDate = dateFormatter.date(from: justDate) {
                let c = cal.dateComponents([.month, .day, .year], from: cDate)
                if let m = c.month, let d = c.day, let y = c.year { add("courseStart", String(format: "%02d/%02d/%04d", m, d, y)) }
            } else {
                dateFormatter.dateFormat = "MMMM d, yyyy"
                if let cDate = dateFormatter.date(from: justDate) {
                    let c = cal.dateComponents([.month, .day, .year], from: cDate)
                    if let m = c.month, let d = c.day, let y = c.year { add("courseStart", String(format: "%02d/%02d/%04d", m, d, y)) }
                } else { add("courseStart", justDate) }
            }
        }
        add("prefillapp", "1")
        comps.queryItems = items
        return comps.url
    }

    private func showRefresherCheckInOut(inOut: String) {
        guard !refresherCheckInOutFormId.isEmpty else { toast = "Refresher check-in/out form not configured."; return }
        if inOut == "Check-Out" && !canCheckOut() { toast = "You cannot check out until the class is over."; return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            if let url = buildRefresherCheckInOutURL(inOut: inOut) {
                electiveFormURL = url
                electiveFormTitle = inOut
                showingElectiveForm = true
                showSkills = false
                showQuizWorkspace = false
                showingMaterials = false
                if inOut == "Check-In" { didCheckIn = true; progressStore.markCheckIn() }
                else { didCheckOut = true; progressStore.markCheckOut() }
            } else {
                toast = "Unable to build refresher form URL."
            }
        }
    }

    private func buildRefresherCheckInOutURL(inOut: String) -> URL? {
        guard var comps = URLComponents(string: "https://form.jotform.com/\(refresherCheckInOutFormId)") else { return nil }
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) { guard let v = value, !v.isEmpty else { return }; items.append(URLQueryItem(name: name, value: v)) }
        add("firstName", attendee.firstName)
        add("lastName", attendee.lastName)
        add("njOems", attendee.oemsId)
        add("courseId", attendee.courseId)
        add("courseType", cleanCourseName(attendee.courseType))
        add("inout", inOut)
        add("dob", attendee.dob)
        add("appform", "1")
        let df = DateFormatter()
        df.locale = .init(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        df.dateFormat = "MM/dd/yyyy HH:mm"
        let now = df.string(from: Date())
        add("date", now)
        if let courseDate = attendee.courseDate {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "MM/dd/yyyy"
            if let d = dateFormatter.date(from: courseDate) {
                let cal = Calendar(identifier: .gregorian)
                let components = cal.dateComponents([.month, .day, .year], from: d)
                if let m = components.month, let day = components.day, let y = components.year {
                    add("courseDate[month]", String(format: "%02d", m))
                    add("courseDate[day]", String(format: "%02d", day))
                    add("courseDate[year]", String(format: "%04d", y))
                }
            } else {
                let parts = courseDate.split(separator: "/")
                if parts.count == 3 {
                    add("courseDate[month]", String(parts[0]))
                    add("courseDate[day]", String(parts[1]))
                    add("courseDate[year]", String(parts[2]))
                }
            }
        }
        comps.queryItems = items
        return comps.url
    }

    // MARK: - Skills
    private func openSkills() {
        if authenticatedInstructor == nil { showingInstructorGate = true; return }
        guard !skillsFormId.isEmpty else { toast = "Skills validation form not configured for this course."; return }
        Task { @MainActor in
            busy = true; generatingComment = true
            defer { busy = false; generatingComment = false }
            let studentName = "\(attendee.firstName) \(attendee.lastName)"
            let courseTitle = cleanCourseName(attendee.courseType)
            let aiComment = await CFAICommentGenerator.generateCommentWithRetry(studentName: studentName, courseTitle: courseTitle, context: "skills validation")
            if let url = buildSkillsURL(aiComment: aiComment) {
                skillsURL = url
                showSkills = true
                showQuizWorkspace = false
                showingMaterials = false
                showingElectiveForm = false
                didOpenSkills = true
                progressStore.markSkills()
            } else {
                toast = "Unable to build skills validation form URL."
            }
        }
    }

    private func buildSkillsURL(aiComment: String) -> URL? {
        guard var comps = URLComponents(string: "https://form.jotform.com/\(skillsFormId)") else { return nil }
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) { guard let v = value, !v.isEmpty else { return }; items.append(URLQueryItem(name: name, value: v)) }
        add("studentFirst", attendee.firstName)
        add("studentLast", attendee.lastName)
        add("njOems", attendee.oemsId)
        if let courseId = attendee.courseId { add("courseId", courseId) }
        add("theseComments", aiComment)
        if let courseDate = attendee.courseDate {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "MM/dd/yyyy"
            if let d = df.date(from: courseDate) {
                let cal = Calendar(identifier: .gregorian)
                let comps = cal.dateComponents([.month, .day, .year], from: d)
                if let m = comps.month, let day = comps.day, let y = comps.year {
                    add("date42[month]", String(format: "%02d", m))
                    add("date42[day]", String(format: "%02d", day))
                    add("date42[year]", String(format: "%04d", y))
                }
            } else {
                let parts = courseDate.split(separator: "/")
                if parts.count == 3 {
                    add("date42[month]", String(parts[0]))
                    add("date42[day]", String(parts[1]))
                    add("date42[year]", String(parts[2]))
                }
            }
        }
        if !attendee.email.isEmpty { add("studentEmail", attendee.email) }
        if let instr = authenticatedInstructor {
            add("instructorFirst", instr.fullName)
            add("instructor6digit", instr.oemsId)
            add("instructorEmail", instr.email)
        }
        comps.queryItems = items
        return comps.url
    }

    // MARK: - Quizzes
    private func openQuizzes() {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                completedQuizzes = try await quizTracker.fetchCompletedQuizzes(submissionId: attendee.submissionId)
            } catch {
                completedQuizzes = []
            }
            // Merge any CK-synced completions, but only for quizzes that belong to this course
            let courseQuizIDs = Set(getQuizzesForCourse().map { $0.id })
            let ckIDs = Set(progressStore.progress.completedQuizIDs).intersection(courseQuizIDs)
            completedQuizzes.formUnion(ckIDs)
            selectedReviewQuiz = nil
            selectedQuiz = nil
            showingQuizzes = true
            showSkills = false
            showingElectiveForm = false
            showingMaterials = false
            showingPDF = false
            showQuizWorkspace = false
        }
    }

    private func markQuizComplete(quizId: String) {
        Task { @MainActor in
            do {
                try await quizTracker.markComplete(
                    submissionId: attendee.submissionId,
                    quizId: quizId,
                    studentName: "\(attendee.firstName) \(attendee.lastName)",
                    courseTitle: attendee.courseType
                )
                completedQuizzes.insert(quizId)
                // Persist to CloudKit progress store for cross-device sync
                progressStore.markQuizComplete(quizId)
                selectedQuiz = nil
            } catch {
                // swallow
            }
        }
    }

    private func getQuizzesForCourse() -> [QuizInfo] {
        let courseType = cleanCourseName(attendee.courseType).uppercased()
        if courseType.contains("REFRESHER A") { return QuizInfo.refresherAQuizzes() }
        else if courseType.contains("REFRESHER B") { return QuizInfo.refresherBQuizzes() }
        else if courseType.contains("REFRESHER C") { return QuizInfo.refresherCQuizzes() }
        else { return [] }
    }

    // MARK: - Course Materials
    private func loadCourseMaterials() {
        showSkills = false
        showQuizWorkspace = false
        showingElectiveForm = false
        showingPDF = false
        showingMaterials = false
        // If a quiz was open, close it so the right pane can show materials when ready
        showingQuizzes = false
        // Also close any elective-URL view so materials are visible
        showingElectiveQuiz = false
        electiveQuizURL = nil
        busy = true
        Task {
            await materialsManager.loadMaterials(for: attendee.courseType)
            await MainActor.run {
                busy = false
                // Copy elective extras into local state for quick access (extract from parsed candidates)
                let (skills, quizzes) = electiveExtrasFromCandidates()
                electiveQuizLinks = quizzes
                electiveSkillsLink = skills

                if !materialsManager.materials.isEmpty {
                    showingMaterials = true
                } else if !materialsManager.materialCandidates.isEmpty {
                    // If your app needs a picker view, you can add it back here.
                    showingMaterials = true
                } else if let err = materialsManager.errorMessage {
                    toast = err
                } else {
                    toast = "No materials found for \(attendee.courseType)."
                }
            }
        }
    }

    private func selectMaterialsCandidate(_ answers: [String: Any]) {
        materialsManager.selectCandidate(answers)
        if !materialsManager.materials.isEmpty { self.showingMaterials = true }
        else if let err = materialsManager.errorMessage { self.toast = err }
    }

    @MainActor
    private func authenticateInstructor() async {
        instructorAuthError = nil
        busy = true
        defer { busy = false }
        do {
            let instr = try await InstructorAuthService.authenticate(instructorId: instructorIdInput)
            authenticatedInstructor = instr
            showingInstructorGate = false
            openSkills()
        } catch {
            if let e = error as? InstructorAuthService.AuthError { instructorAuthError = e.localizedDescription }
            else { instructorAuthError = error.localizedDescription }
        }
    }

    // MARK: - Small UI Helpers
    private func Chip(text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(.systemGray6)))
    }

    private func CourseChip(courseName: String) -> some View {
        Text(courseName)
            .font(.subheadline.weight(.bold))
            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.0, green: 0.0, blue: 0.5))
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    private func actionButton(title: String, systemImage: String? = nil, done: Bool = false, action: @escaping () -> Void) -> AnyView {
        // If already done, show a muted completed style, otherwise use accent button style with pressed feedback
        if done {
            return AnyView(
                Button(action: action) {
                    HStack {
                        if let s = systemImage { Image(systemName: s).font(.system(size: 18)).foregroundColor(.accentColor) }
                        Text(title)
                        Spacer(minLength: 8)
                        ZStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .accessibilityLabel("Completed")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.2))
                    )
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            )
        } else {
            return AnyView(
                Button(action: action) {
                    HStack {
                        if let s = systemImage { Image(systemName: s).font(.system(size: 18)) }
                        Text(title)
                        Spacer(minLength: 8)
                    }
                    .padding()
                }
                .buttonStyle(AccentButtonStyle())
            )
        }
    }

    // Accent button style: blue fill with lighter feedback when pressed
    private struct AccentButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                        .opacity(configuration.isPressed ? 0.75 : 1.0)
                )
                .foregroundColor(.white)
                .scaleEffect(configuration.isPressed ? 0.997 : 1.0)
        }
    }

    private func cleanCourseName(_ s: String) -> String {
        if let range = s.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            return String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Try to extract elective skills/quiz URLs from the materials manager's candidate answers.
    /// Returns (skillsURL, [quizURLs]). This mirrors lightweight parsing used by the full manager.
    private func electiveExtrasFromCandidates() -> (URL?, [URL]) {
        // If the manager has already extracted elective extras (exact match path),
        // prefer those published properties first.
        if let skills = materialsManager.electiveSkillsURL {
            return (skills, materialsManager.electiveQuizURLs)
        }

        if !materialsManager.electiveQuizURLs.isEmpty {
            return (nil, materialsManager.electiveQuizURLs)
        }

        // Fallback: inspect the first candidate's answers for QID 5/6
        func extractURLs(fromField field: Any?) -> [URL] {
            guard let f = field else { return [] }
            if let dict = f as? [String: Any] {
                if let arr = dict["answer"] as? [String] { return arr.compactMap { URL(string: $0) } }
                if let s = dict["answer"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let parts = s.split(whereSeparator: { $0 == "," || $0.isNewline }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    return parts.compactMap { URL(string: $0) }
                }
            } else if let arr = f as? [String] { return arr.compactMap { URL(string: $0) } }
            else if let s = f as? String {
                if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
                let parts = s.split(whereSeparator: { $0 == "," || $0.isNewline }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return parts.compactMap { URL(string: $0) }
            }
            return []
        }

        if let candidate = materialsManager.materialCandidates.first {
            let answers = candidate.0
            let skillsField = answers["5"] ?? answers["skillsUrl"]
            let quizField = answers["6"] ?? answers["quizUrl"]
            let skills = extractURLs(fromField: skillsField)
            let quizzes = extractURLs(fromField: quizField)
            return (skills.first, quizzes)
        }

        return (nil, [])
    }

    // MARK: - Supporting Types
    struct ToastMessage: Identifiable { let id: UUID; let message: String }
}

// MARK: - Extensions and Helper Views at File Scope
private struct AttendanceCaptureAction: Identifiable {
    let id: String
}

private struct AttendanceCaptureSheet: View {
    let attendee: RosterAttendee
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
                    Text(attendee.fullName)
                        .font(.headline)
                    Text(displayCourseName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(locationStatus, systemImage: location == nil ? "location" : "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(location == nil ? Color.secondary : Color.green)

                Text("Signature")
                    .font(.headline)

                SignatureCanvas(drawing: $drawing)
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
            .navigationTitle("Attendance")
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
        let attestationText = "I certify that \(attendee.fullName) \(actionText) \(displayCourseName) on \(signedAt)."
        onSubmit(
            ClassManagerAPIClient.AttendanceAttestation(
                signatureDataUrl: "data:image/png;base64,\(png.base64EncodedString())",
                signedAt: signedAt,
                attestationText: attestationText,
                location: locationPayload
            )
        )
    }

    private var displayCourseName: String {
        attendee.courseType.replacingOccurrences(of: #"^\d+\s*-\s*"#, with: "", options: .regularExpression)
    }
}

private struct SignatureCanvas: UIViewRepresentable {
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

private extension CourseMaterialsManager {
    func clearCache() {
        self.materials.removeAll()
        self.materialCandidates.removeAll()
        self.errorMessage = nil
    }
}

private struct CourseImageView: View {
    let url: URL
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                case .failure:
                    Image(systemName: "photo.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
        return pdfView
    }
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
    }
}

private struct ElectiveFormContainer: View {
    let url: URL
    let title: String
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) { Image(systemName: "xmark.circle.fill").imageScale(.large) }
                    .buttonStyle(.plain)
                Text(title).font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            WebViewContainer(url: url)
                .edgesIgnoringSafeArea(.bottom)
        }
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.load(URLRequest(url: url))
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}

// WebView that detects a JotForm thank-you page by inspecting the page text or URL and calls onComplete once detected.
private struct SurveyWebView: UIViewRepresentable {
    let url: URL
    var onComplete: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.load(URLRequest(url: url))
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onComplete: () -> Void
        init(onComplete: @escaping () -> Void) { self.onComplete = onComplete }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Detect the exact thank-you marker added to the JotForm thank-you page.
            let completionMarker = "6e0a9b0f6f6d5a0d2d3d2c88c97e7b1a"
            // Check URL first
            if let u = webView.url?.absoluteString, u.contains(completionMarker) {
                DispatchQueue.main.async { self.onComplete() }
                return
            }
            // Inspect page text for the exact marker
            webView.evaluateJavaScript("document.body.innerText") { result, _ in
                if let txt = result as? String {
                    if txt.contains(completionMarker) {
                        DispatchQueue.main.async { self.onComplete() }
                    }
                }
            }
        }
    }
}

private struct CheckoutSurveyContainer: View {
    let url: URL
    let onComplete: () -> Void
    let onCancel: () -> Void
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SurveyWebView(url: url, onComplete: {
                    // Close and notify
                    onComplete()
                })
                .edgesIgnoringSafeArea(.bottom)
            }
            .navigationBarItems(leading: Button(action: onCancel) { Image(systemName: "xmark.circle.fill") })
        }
    }
}

private extension QuizInfo {
    func asInfo() -> QuizInfo { self }
}
