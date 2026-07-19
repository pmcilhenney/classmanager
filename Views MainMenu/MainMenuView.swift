import SwiftUI
import Foundation
import PDFKit
import Combine
import WebKit
import CloudKit
import PencilKit
import PhotosUI
import Vision

struct MainMenuView: View {
    let config: AppConfig
    @State private var attendee: RosterAttendee
    let jotform: JotFormClient
    let flexi: FlexiQuizClient
    let onRequestScanNew: (() -> Void)? = nil
    let onRequestLaunchReset: (() -> Void)?
    let initialNotificationRoute: ClassManagerNotificationRoute?

    @StateObject var materialsManager: CourseMaterialsManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var showingCPRUpload = false
    @State private var cprCardStatus: ClassManagerAPIClient.CPRCardStatusResponse?

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

    init(
        config: AppConfig,
        attendee: RosterAttendee,
        jotform: JotFormClient,
        flexi: FlexiQuizClient,
        onRequestLaunchReset: (() -> Void)? = nil,
        initialNotificationRoute: ClassManagerNotificationRoute? = nil
    ) {
        self.config = config
        self.jotform = jotform
        self.flexi = flexi
        self.onRequestLaunchReset = onRequestLaunchReset
        self.initialNotificationRoute = initialNotificationRoute
        _attendee = State(initialValue: attendee)
        _materialsManager = StateObject(wrappedValue: CourseMaterialsManager(jotformApiKey: config.jotformApiKey, materialsFormId: (Bundle.main.object(forInfoDictionaryKey: "COURSE_MATERIALS_ID") as? String) ?? ""))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if requiresInitialCheckIn {
                    checkInGate
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 1.03))
                        ))
                } else {
                    HStack(spacing: 0) {
                        leftSidebar
                            .frame(width: max(geo.size.width * 0.33, 280))
                        Divider()
                        rightContent
                            .frame(width: geo.size.width - max(geo.size.width * 0.33, 280))
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: requiresInitialCheckIn)
        }
        .overlay(busyOverlay)
        .onAppear {
            expireActiveSessionIfNeeded()
            onAppearLoad()
            routeNotificationIfNeeded(initialNotificationRoute)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                expireActiveSessionIfNeeded()
            }
        }
        .onReceive(progressStore.$progress) { _ in
            Task { @MainActor in
                // Merge any CK-synced completions into the visible set for the current course
                let courseQuizIDs = Set(getQuizzesForCourse().map { $0.id })
                let ckIDs = Set(progressStore.progress.completedQuizIDs).intersection(courseQuizIDs)
                completedQuizzes.formUnion(ckIDs)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .classManagerNotificationTapped)) { notification in
            guard let route = ClassManagerNotificationRoute(userInfo: notification.userInfo ?? [:]) else { return }
            routeNotificationIfNeeded(route)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ckRemoteNotificationReceived)) { notification in
            guard let route = ClassManagerNotificationRoute(userInfo: notification.userInfo ?? [:]),
                  route.isStudentCprRoute,
                  route.matches(attendee: attendee) else { return }
            Task { await loadCprCardStatus() }
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
        .sheet(isPresented: $showingCPRUpload) {
            CPRCardUploadSheet(
                attendee: attendee,
                existingUpload: cprCardStatus?.upload,
                onCancel: { showingCPRUpload = false },
                onUploaded: {
                    showingCPRUpload = false
                    Task { await loadCprCardStatus() }
                    toast = "CPR card uploaded."
                }
            )
        }
    }

    private var requiresInitialCheckIn: Bool {
        !progressStore.progress.didCheckIn
    }

    private var examWorkflowComplete: Bool {
        if versionBRequiredOrActive {
            return hasVersionBFinalResult
        }

        if progressStore.progress.finalExamResult != nil {
            return true
        }

        guard !trackedQuizIds.isEmpty else {
            return true
        }

        let completed = Set(progressStore.progress.completedQuizIDs).union(completedQuizzes)
        return trackedQuizIds.isSubset(of: completed)
    }

    private var skillsValidationUnlocked: Bool {
        examWorkflowComplete && !versionBFailedFinalResult
    }

    private var skillsLockedMessage: String {
        if versionBFailedFinalResult {
            return "Skills validation is locked because Version B was unsuccessful. See your instructor."
        }
        return "Skills validation unlocks after all exam sections are complete."
    }

    private var versionBFailedFinalResult: Bool {
        guard let final = progressStore.progress.finalExamResult else {
            return false
        }
        return QuizInfo.isVersionBQuizId(final.quizId) && final.passed == false
    }

    private var versionBRequiredOrActive: Bool {
        let completed = Set(progressStore.progress.completedQuizIDs).union(completedQuizzes)
        if let versionBQuiz = getVersionBQuizForCourse(),
           completed.contains(QuizInfo.versionBStartedMarkerId(for: versionBQuiz.flexiQuizId)) {
            return true
        }
        guard let final = progressStore.progress.finalExamResult else {
            return false
        }
        return QuizInfo.isCombinedVersionAQuizId(final.quizId) && final.passed == false && getVersionBQuizForCourse() != nil
    }

    private var hasVersionBFinalResult: Bool {
        guard let versionBQuiz = getVersionBQuizForCourse() else { return false }
        if progressStore.progress.finalExamResult?.quizId == versionBQuiz.flexiQuizId {
            return true
        }
        let completed = Set(progressStore.progress.completedQuizIDs).union(completedQuizzes)
        return completed.contains(versionBQuiz.flexiQuizId)
    }

    private var trackedQuizIds: Set<String> {
        Set(getQuizzesForCourse().map { $0.id })
    }

    private var trackedQuizCount: Int {
        trackedQuizIds.count
    }

    private var completedTrackedQuizCount: Int {
        if hasCompletedVersionAFullExam {
            return trackedQuizCount
        }
        return Set(progressStore.progress.completedQuizIDs)
            .union(completedQuizzes)
            .intersection(trackedQuizIds)
            .count
    }

    private var hasCompletedVersionAFullExam: Bool {
        guard let finalQuizId = progressStore.progress.finalExamResult?.quizId,
              let combinedQuizId = getQuizzesForCourse().first?.flexiQuizId else {
            return false
        }
        return finalQuizId == combinedQuizId || QuizInfo.isVersionBQuizId(finalQuizId)
    }

    private var checkInGate: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("gcems_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .opacity(0.95)

            VStack(spacing: 8) {
                Text(attendee.fullName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(cleanCourseName(attendee.courseType))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                check(inOut: "Check-In")
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 54, weight: .bold))
                    Text("CHECK IN")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                }
                .frame(maxWidth: 520)
                .padding(.vertical, 34)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.accentColor.opacity(0.28), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(busy)

            Text("Signature and location are required.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(36)
        .background(Color(.systemBackground))
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
                actionButton(title: "Check In", systemImage: "checkmark.circle", done: progressStore.progress.didCheckIn, disabled: progressStore.progress.didCheckIn) {
                    check(inOut: "Check-In")
                }
                checkOutButton()

                actionButton(
                    title: "CPR Card",
                    systemImage: cprCardStatus?.hasCprCard == true ? "checkmark.seal.fill" : "cross.case",
                    done: cprCardStatus?.hasCprCard == true,
                    disablesWhenDone: false
                ) {
                    showingCPRUpload = true
                }
                
                // CONDITIONAL SKILLS BUTTON
                // Show for Refresher courses (always) OR Elective courses WITH a skills URL
                if shouldShowSkillsButton() {
                    actionButton(
                        title: "Validate Skills",
                        systemImage: "person.crop.circle.badge.checkmark",
                        done: progressStore.progress.didOpenSkills,
                        locked: !skillsValidationUnlocked,
                        lockedMessage: skillsLockedMessage
                    ) {
                        guard skillsValidationUnlocked else {
                            toast = skillsLockedMessage
                            return
                        }
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
                            if completedTrackedQuizCount > 0 {
                                Text("\(completedTrackedQuizCount)/\(trackedQuizCount)")
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
        let isLocked = !canCheckOut()
        return Button(action: {
            if isLocked {
                toast = checkoutLockedMessage
            } else if !isDone {
                check(inOut: "Check-Out")
            }
        }) {
            HStack {
                Image(systemName: isDone ? "arrow.right.circle" : (isLocked ? "lock.fill" : "arrow.right.circle"))
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
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDone ? Color.accentColor.opacity(0.2) : (isLocked ? Color(.systemGray5) : Color.accentColor))
            )
            .foregroundColor(isDone ? .accentColor : (isLocked ? .secondary : .white))
        }
        .buttonStyle(.plain)
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
                } else if showSkills {
                    if let url = skillsURL {
                        SkillsWebView(url: url)
                    } else {
                        LoadingSpinnerView()
                    }
                } else if showingElectiveQuiz, let url = electiveQuizURL {
                    WebViewContainer(url: url)
                } else if showingQuizzes {
                    if let quiz = selectedReviewQuiz {
                        QuizReviewView(
                            config: config,
                            attendee: attendee,
                            quiz: quiz,
                            onLoaded: { review in
                                recordQuizReview(quiz: quiz, review: review)
                            },
                            onDone: {
                                selectedReviewQuiz = nil
                            }
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
                                if QuizInfo.isVersionBQuizId(quiz.flexiQuizId) {
                                    let markerId = QuizInfo.versionBStartedMarkerId(for: quiz.flexiQuizId)
                                    completedQuizzes.insert(markerId)
                                    progressStore.markQuizResult(
                                        markerId,
                                        result: "Version B started"
                                    )
                                }
                            },
                            onReviewLoaded: { quiz, review in
                                recordQuizReview(quiz: quiz, review: review)
                            },
                            onPageCheckpoint: { quiz, _ in
                                recordQuizCheckpoint(quiz: quiz)
                            },
                            onBack: { selectedQuiz = nil }
                        )
                    } else {
                        QuizSelectionView(
                            progressStore: progressStore,
                            attendee: attendee,
                            quizURLs: getQuizzesForCourse().map { $0.asInfo() },
                            versionBQuiz: getVersionBQuizForCourse(),
                            selectedQuiz: $selectedQuiz,
                            completedQuizzes: $completedQuizzes,
                            onBlocked: { msg in toast = msg },
                            onReview: { quiz in selectedReviewQuiz = quiz },
                            onVersionAReviewComplete: { quizId in
                                let markerId = QuizInfo.versionAReviewMarkerId(for: quizId)
                                completedQuizzes.insert(markerId)
                                progressStore.markQuizResult(markerId, result: "Version A review complete")
                            }
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
            await loadCprCardStatus()
            electiveQuizLinks = []
            electiveSkillsLink = nil
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
                ClassManagerLaunchSession.markScan()
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

                    electiveQuizLinks = []
                    electiveSkillsLink = nil
                }
                toast = "Loaded new student: \(newAttendee.firstName) \(newAttendee.lastName)"
            }
        } catch {
            await MainActor.run { toast = "Could not load registration data. Please try again." }
        }
    }

    private func expireActiveSessionIfNeeded() {
        guard ClassManagerLaunchSession.shouldResetActiveSession() else { return }
        ClassManagerLaunchSession.clear()
        onRequestLaunchReset?()
    }

    // MARK: - Check In/Out
    private func check(inOut: String) {
        let isElective = attendee.productCategories?.contains("2002") ?? false
        if inOut == "Check-In" && progressStore.progress.didCheckIn {
            toast = "Check-in is already complete for this student."
            return
        }
        if inOut == "Check-Out" && !canCheckOut() {
            toast = checkoutLockedMessage
            return
        }
        // If this is a check-out action, present the required completion survey first.
        if inOut == "Check-Out" {
            Task { await prepareCheckoutSurvey() }
            return
        }

        if isElective {
            beginAttendanceCapture(inOut: inOut)
        } else {
            beginAttendanceCapture(inOut: inOut)
        }
    }

    @MainActor
    private func prepareCheckoutSurvey() async {
        busy = true
        defer { busy = false }

        let activeInstructor: ClassManagerAPIClient.InstructorDashboardInstructor?
        do {
            let response = try await ClassManagerAPIClient.shared.fetchActiveInstructor(
                classSessionId: classSessionIdForCurrentAttendee()
            )
            activeInstructor = response.instructor
        } catch {
            activeInstructor = nil
        }

        checkoutSurveyURL = buildCheckoutSurveyURL(activeInstructor: activeInstructor)
        showingCheckoutSurvey = true
    }

    private func buildCheckoutSurveyURL(activeInstructor: ClassManagerAPIClient.InstructorDashboardInstructor?) -> URL? {
        guard var comps = URLComponents(string: "https://form.jotform.com/240184388762060") else {
            return URL(string: "https://form.jotform.com/240184388762060")
        }

        var items: [URLQueryItem] = comps.queryItems ?? []
        func add(_ name: String, _ value: String?) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            items.append(URLQueryItem(name: name, value: value))
        }

        let instructorName = activeInstructor?.fullName ?? authenticatedInstructor?.fullName
        let instructorEmail = activeInstructor?.email ?? authenticatedInstructor?.email
        let courseName = cleanCourseName(attendee.courseType)
        let njCourseId = attendee.courseId
        let classSessionId = classSessionIdForCurrentAttendee()

        add("courseType", courseName)
        add("q23_courseType", courseName)
        add("njCourse", njCourseId)
        add("q28_njCourse", njCourseId)
        add("q28", njCourseId)
        add("classSessionId", classSessionId)
        add("classsessionid", classSessionId)
        add("class_session_id", classSessionId)
        add("q29_classSessionId", classSessionId)
        add("primaryInstructor", instructorName)
        add("q24_primaryInstructor", instructorName)
        add("email", instructorEmail)
        add("q25_email", instructorEmail)

        comps.queryItems = items
        return comps.url
    }

    private var checkoutLockedMessage: String {
        if !progressStore.progress.didCheckIn {
            return "Check out unlocks after the student is checked in."
        }
        if !examWorkflowComplete {
            return "Check out unlocks after all exam sections are complete."
        }
        return "Check out is not available yet."
    }

    private func canCheckOut() -> Bool {
        progressStore.progress.didCheckIn && examWorkflowComplete
    }

    private func classSessionIdForCurrentAttendee() -> String {
        let raw = (attendee.courseDate ?? attendee.submissionId).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "undated" : raw.replacingOccurrences(of: "/", with: "-")
    }

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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        progressStore.markCheckIn()
                    }
                    await promptForCprCardIfNeeded()
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

    @MainActor
    private func promptForCprCardIfNeeded() async {
        await loadCprCardStatus()
        if cprCardStatus?.hasCprCard == true {
            showingCPRUpload = true
            return
        }
        showingCPRUpload = true
    }

    @MainActor
    private func loadCprCardStatus() async {
        do {
            let status = try await ClassManagerAPIClient.shared.fetchCprCardStatus(attendee: attendee)
            cprCardStatus = status
        } catch {
            cprCardStatus = nil
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
        guard skillsValidationUnlocked else {
            toast = skillsLockedMessage
            return
        }
        if authenticatedInstructor == nil { showingInstructorGate = true; return }
        guard !skillsFormId.isEmpty else { toast = "Skills validation form not configured for this course."; return }
        Task { @MainActor in
            skillsURL = nil
            showSkills = true
            showQuizWorkspace = false
            showingMaterials = false
            showingElectiveForm = false
            generatingComment = true
            defer { generatingComment = false }
            let studentName = "\(attendee.firstName) \(attendee.lastName)"
            let courseTitle = cleanCourseName(attendee.courseType)
            let studentId = attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? attendee.submissionId
                : attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines)
            let classSessionId = (attendee.courseDate ?? attendee.submissionId)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "/", with: "-")
            let aiComment = await CFAICommentGenerator.generateCommentWithRetry(
                studentName: studentName,
                courseTitle: courseTitle,
                context: "skills validation",
                studentId: studentId,
                classSessionId: classSessionId
            )
            if let url = buildSkillsURL(aiComment: aiComment) {
                skillsURL = url
                didOpenSkills = true
                progressStore.markSkills()
            } else {
                showSkills = false
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
        if let courseId = attendee.courseId {
            add("courseId", courseId)
            add("njCourse", courseId)
        }
        let studentId = attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? attendee.submissionId
            : attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines)
        let classSessionId = (attendee.courseDate ?? attendee.submissionId)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        add("classSessionId", classSessionId)
        add("classManagerStudentId", studentId)
        add("typeA90", attendee.courseId)
        add("q90_typeA90", attendee.courseId)
        add("q91_classsessionid", classSessionId)
        add("classsessionid", classSessionId)
        add("q92_classManagerStudentId", studentId)
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
            await progressStore.fetchLatestAndMerge()
            completedQuizzes = []
            let courseQuizIDs = Set(getQuizzesForCourse().map { $0.id })
            let workerIDs = Set(progressStore.progress.completedQuizIDs).intersection(courseQuizIDs)
            completedQuizzes.formUnion(workerIDs)
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

    private func routeNotificationIfNeeded(_ route: ClassManagerNotificationRoute?) {
        guard let route, route.isFresh, route.matches(attendee: attendee) else { return }
        if route.isStudentCprRoute {
            Task { await loadCprCardStatus() }
            showingCPRUpload = true
        } else if route.isStudentExamRoute || route.quizId != nil {
            openExamReviewFromNotification(route)
        }
    }

    private func openExamReviewFromNotification(_ route: ClassManagerNotificationRoute) {
        guard let quiz = quizForNotificationRoute(route) else {
            openQuizzes()
            return
        }
        showSkills = false
        showingElectiveForm = false
        showingMaterials = false
        showingPDF = false
        showingElectiveQuiz = false
        selectedQuiz = nil
        selectedReviewQuiz = quiz
        showingQuizzes = true
    }

    private func quizForNotificationRoute(_ route: ClassManagerNotificationRoute) -> QuizInfo? {
        guard let quizId = route.quizId else { return nil }
        if let versionB = getVersionBQuizForCourse(), versionB.flexiQuizId == quizId {
            return versionB
        }
        if let existing = getQuizzesForCourse().first(where: { $0.flexiQuizId == quizId || $0.id == quizId }) {
            return existing
        }
        if let first = getQuizzesForCourse().first, first.flexiQuizId == quizId || QuizInfo.isCombinedVersionAQuizId(quizId) {
            return QuizInfo(
                id: "full-exam-review-\(quizId)",
                flexiQuizId: quizId,
                number: 0,
                title: "Full Exam Review",
                url: first.url
            )
        }
        return nil
    }

    private func markQuizComplete(quizId: String) {
        Task { @MainActor in
            completedQuizzes.insert(quizId)
            progressStore.markQuizComplete(quizId)
            selectedQuiz = nil
        }
    }

    private func recordQuizReview(quiz: QuizInfo, review: ClassManagerAPIClient.QuizReviewResponse) {
        if quiz.questionRange != nil && answeredQuestionCount(review, quiz: quiz) == 0 {
            completedQuizzes.remove(quiz.id)
            progressStore.clearQuizResult(quiz.id)
            toast = "\(quiz.title) has no recorded answers yet. It was reopened for completion."
            return
        }

        guard trackedQuizIds.contains(quiz.id) else {
            if QuizInfo.isCombinedVersionAQuizId(quiz.flexiQuizId) {
                markAllTrackedQuizzesComplete()
            }

            if QuizInfo.isCombinedVersionAQuizId(quiz.flexiQuizId) && review.passed == false {
                let markerId = QuizInfo.versionAReviewMarkerId(for: quiz.flexiQuizId)
                completedQuizzes.insert(markerId)
                progressStore.markQuizResult(
                    markerId,
                    result: "Version A review complete"
                )
                Task { await progressStore.fetchLatestAndMerge() }
                if getVersionBQuizForCourse() != nil {
                    toast = "Version A is below the \(QuizInfo.versionAPassingPercent)% passing standard. Review is complete; complete remediation with your instructor, then start Version B."
                } else {
                    toast = "Version A is below the \(QuizInfo.versionAPassingPercent)% passing standard. Review is complete; complete remediation with your instructor."
                }
            } else if QuizInfo.isCombinedVersionAQuizId(quiz.flexiQuizId) {
                Task { await progressStore.fetchLatestAndMerge() }
            } else if QuizInfo.isVersionBQuizId(quiz.flexiQuizId) {
                guard answeredQuestionCount(review, quiz: quiz) > 0 else {
                    completedQuizzes.remove(quiz.id)
                    progressStore.clearQuizResult(quiz.id)
                    toast = "Version B is ready. Complete the retest before review is available."
                    return
                }
                completedQuizzes.insert(quiz.id)
                progressStore.markQuizResult(quiz.id, result: quizResultSummary(review, quiz: quiz))
                Task { await progressStore.fetchLatestAndMerge() }
            }
            return
        }

        let result = quizResultSummary(review, quiz: quiz)
        completedQuizzes.insert(quiz.id)
        progressStore.markQuizResult(quiz.id, result: result)
    }

    private func recordQuizCheckpoint(quiz: QuizInfo) {
        completedQuizzes.insert(quiz.id)
        progressStore.markQuizResult(quiz.id, result: "Section submitted")
    }

    private func markAllTrackedQuizzesComplete() {
        for quizId in trackedQuizIds {
            completedQuizzes.insert(quizId)
            if progressStore.progress.quizResults[quizId] == nil {
                progressStore.markQuizResult(quizId, result: "Section submitted")
            }
        }
    }

    private func quizResultSummary(_ review: ClassManagerAPIClient.QuizReviewResponse, quiz: QuizInfo) -> String {
        let sectionQuestions: [ClassManagerAPIClient.QuizReviewQuestion]
        if let range = quiz.questionRange {
            sectionQuestions = review.questions.filter { range.contains($0.number) }
        } else {
            sectionQuestions = review.questions
        }

        if !sectionQuestions.isEmpty {
            let answered = sectionQuestions.filter { ($0.studentAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            guard !answered.isEmpty else { return "No answers yet" }
            let correct = answered.filter { $0.isCorrect == true }.count
            return "\(correct)/\(answered.count)"
        }

        if QuizInfo.isVersionAQuizId(quiz.flexiQuizId) {
            if let scoreText = review.scoreText, let ratio = ratioScoreText(scoreText) {
                return ratio
            }
            if let scoreText = review.scoreText, let normalized = versionAMiniQuizFallbackScore(scoreText) {
                return normalized
            }
            return "Completed"
        }

        let status: String? = {
            if let passed = review.passed {
                return passed ? "Passed" : "Failed"
            }
            return review.resultText
        }()

        if quiz.questionRange != nil, let status, status.lowercased().contains("fail"), review.scoreText?.contains("0") == true {
            return "Section submitted"
        }

        let summary = [status, review.scoreText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return summary.isEmpty ? "Completed" : summary
    }

    private func ratioScoreText(_ value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)"#) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let pointsRange = Range(match.range(at: 1), in: value),
              let availableRange = Range(match.range(at: 2), in: value) else {
            return nil
        }
        let points = Double(value[pointsRange]) ?? 0
        let available = Double(value[availableRange]) ?? 0
        guard available > 0 else { return nil }
        return "\(Int(points.rounded()))/\(Int(available.rounded()))"
    }

    private func versionAMiniQuizFallbackScore(_ value: String) -> String? {
        let withoutStatus = value
            .replacingOccurrences(of: #"(?i)\b(pass(?:ed)?|fail(?:ed)?)\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let ratio = ratioScoreText(withoutStatus) {
            return ratio
        }
        if withoutStatus.range(of: #"\d+\s*%"#, options: .regularExpression) != nil {
            return withoutStatus
        }
        return withoutStatus.isEmpty ? nil : withoutStatus
    }

    private func answeredQuestionCount(_ review: ClassManagerAPIClient.QuizReviewResponse, quiz: QuizInfo) -> Int {
        let questions: [ClassManagerAPIClient.QuizReviewQuestion]
        if let range = quiz.questionRange {
            questions = review.questions.filter { range.contains($0.number) }
        } else {
            questions = review.questions
        }
        return questions.filter { ($0.studentAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count
    }

    private func getQuizzesForCourse() -> [QuizInfo] {
        let courseType = cleanCourseName(attendee.courseType).uppercased()
        if courseType.contains("REFRESHER A") {
            return QuizInfo.refresherAQuizzes()
        } else if courseType.contains("REFRESHER B") {
            return QuizInfo.refresherBQuizzes()
        } else if courseType.contains("REFRESHER C") {
            return QuizInfo.refresherCQuizzes()
        }
        return []
    }

    private func getVersionBQuizForCourse() -> QuizInfo? {
        guard let combinedQuizId = getQuizzesForCourse().first?.flexiQuizId else { return nil }
        return QuizInfo.versionBQuiz(forCombinedQuizId: combinedQuizId)
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
            let instr = try await ClassManagerAPIClient.shared.authenticateInstructor(instructorId: instructorIdInput)
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

    private func actionButton(
        title: String,
        systemImage: String? = nil,
        done: Bool = false,
        locked: Bool = false,
        disabled: Bool = false,
        disablesWhenDone: Bool = true,
        lockedMessage: String? = nil,
        action: @escaping () -> Void
    ) -> AnyView {
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
                .disabled(disablesWhenDone)
            )
        } else if locked {
            return AnyView(
                Button(action: {
                    if let lockedMessage {
                        toast = lockedMessage
                    }
                }) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(title)
                        Spacer(minLength: 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                    )
                    .foregroundColor(.secondary)
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
                .disabled(disabled)
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

private struct CPRCardUploadSheet: View {
    let attendee: RosterAttendee
    let existingUpload: ClassManagerAPIClient.CPRCardUploadStatus?
    let onCancel: () -> Void
    let onUploaded: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var pendingUpload: PendingCPRUpload?
    @State private var expirationDateText = ""
    @State private var showingExpirationPrompt = false
    @State private var isUpdatingExisting = false
    @State private var fullScreenImageURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Upload CPR Card")
                            .font(.title2.weight(.semibold))
                        Text(attendee.fullName)
                            .font(.headline)
                        Text(existingUpload == nil ? "Add the CPR card for this class." : "Confirm the saved CPR card is still current or upload an updated card.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let existingUpload, !isUpdatingExisting {
                        existingCardSummary(existingUpload)
                        if isAcceptedCprStatus(existingUpload.validationStatus) {
                            Button {
                                Task { await confirmCurrentCard() }
                            } label: {
                                Label("This Is Still Current", systemImage: "checkmark.seal.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Label("A new upload is required unless an instructor approves this card.", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                        }

                        Button {
                            isUpdatingExisting = true
                        } label: {
                            Label("Update CPR Card", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        uploadControls
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding()
                .disabled(isUploading)

                if isUploading {
                    LoadingSpinnerView()
                }
            }
            .navigationTitle("CPR Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later", action: onCancel)
                        .disabled(isUploading)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await upload(item: item) }
            }
            .sheet(isPresented: $showingCamera) {
                CameraCaptureView { image in
                    showingCamera = false
                    guard let data = image.jpegData(compressionQuality: 0.88) else {
                        errorMessage = "Could not prepare the photo."
                        return
                    }
                    Task { await prepareUpload(data: data, fileName: "cpr-card.jpg", mimeType: "image/jpeg") }
                } onCancel: {
                    showingCamera = false
                }
            }
            .fullScreenCover(item: Binding(
                get: { fullScreenImageURL.map { FullScreenImageURL(url: $0) } },
                set: { if $0 == nil { fullScreenImageURL = nil } }
            )) { item in
                CPRCardFullScreenImage(url: item.url) {
                    fullScreenImageURL = nil
                }
            }
            .alert("Expiration Date", isPresented: $showingExpirationPrompt) {
                TextField("MM/DD/YYYY", text: $expirationDateText)
                    .keyboardType(.numbersAndPunctuation)
                Button("Upload") {
                    guard let pendingUpload else { return }
                    Task {
                        await upload(
                            data: pendingUpload.data,
                            fileName: pendingUpload.fileName,
                            mimeType: pendingUpload.mimeType,
                            expirationDate: normalizedExpirationDate(expirationDateText),
                            recognizedText: pendingUpload.recognizedText
                        )
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingUpload = nil
                }
            } message: {
                Text("We could not confidently read the CPR card expiration date. Enter it so the app can avoid asking again before it expires.")
            }
        }
    }

    private var uploadControls: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
        }
    }

    private func existingCardSummary(_ upload: ClassManagerAPIClient.CPRCardUploadStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageUrl = upload.imageUrl, let url = URL(string: imageUrl) {
                Button {
                    fullScreenImageURL = url
                } label: {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            ContentUnavailableView("Preview unavailable", systemImage: "photo")
                        default:
                            LoadingSpinnerView()
                        }
                    }
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            if let status = upload.validationStatus, !status.isEmpty {
                Label(cprStatusLabel(status), systemImage: isAcceptedCprStatus(status) ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isAcceptedCprStatus(status) ? .green : .red)
            }
            if let expiration = upload.expirationDate, !expiration.isEmpty {
                Label("Expires \(expiration)", systemImage: "calendar.badge.checkmark")
                    .font(.subheadline.weight(.semibold))
            }
            if let notes = upload.validationNotes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func isAcceptedCprStatus(_ status: String?) -> Bool {
        status == "valid" || status == "approved_by_instructor"
    }

    private func cprStatusLabel(_ status: String) -> String {
        switch status {
        case "valid": return "Accepted"
        case "approved_by_instructor": return "Approved by Instructor"
        case "expired": return "Expired"
        case "name_mismatch": return "Name Mismatch"
        case "needs_expiration": return "Expiration Needed"
        case "needs_review": return "Instructor Review Needed"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func upload(item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run { errorMessage = "Could not read the selected photo." }
                return
            }
            let mimeType = imageMimeType(for: data)
            await prepareUpload(data: data, fileName: mimeType == "image/png" ? "cpr-card.png" : "cpr-card.jpg", mimeType: mimeType)
        } catch {
            await MainActor.run { errorMessage = "Could not read the selected photo." }
        }
    }

    private func confirmCurrentCard() async {
        await MainActor.run {
            isUploading = true
            errorMessage = nil
        }
        defer { Task { @MainActor in isUploading = false } }

        do {
            _ = try await ClassManagerAPIClient.shared.confirmCprCard(attendee: attendee)
            await MainActor.run { onUploaded() }
        } catch {
            await MainActor.run { errorMessage = "Could not confirm CPR card status. Please try again." }
        }
    }

    private func prepareUpload(data: Data, fileName: String, mimeType: String) async {
        let recognizedText = await recognizeText(in: data)
        let expiration = expirationDate(from: recognizedText)
        if expiration == nil {
            await MainActor.run {
                pendingUpload = PendingCPRUpload(data: data, fileName: fileName, mimeType: mimeType, recognizedText: recognizedText)
                expirationDateText = ""
                showingExpirationPrompt = true
            }
            return
        }
        await upload(data: data, fileName: fileName, mimeType: mimeType, expirationDate: expiration, recognizedText: recognizedText)
    }

    private func upload(data: Data, fileName: String, mimeType: String, expirationDate: String?, recognizedText: String?) async {
        await MainActor.run {
            isUploading = true
            errorMessage = nil
        }
        defer { Task { @MainActor in isUploading = false } }

        do {
            _ = try await ClassManagerAPIClient.shared.uploadCprCard(
                attendee: attendee,
                imageData: data,
                fileName: fileName,
                mimeType: mimeType,
                expirationDate: expirationDate,
                recognizedText: recognizedText
            )
            await MainActor.run { onUploaded() }
        } catch ClassManagerAPIClient.APIError.httpStatus(_, let body) {
            await MainActor.run {
                errorMessage = cprUploadErrorMessage(from: body)
                isUpdatingExisting = true
            }
        } catch {
            await MainActor.run { errorMessage = "CPR card upload failed. Please try again." }
        }
    }

    private func imageMimeType(for data: Data) -> String {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
    }

    private func recognizeText(in data: Data) async -> String? {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            }
        }
    }

    private func expirationDate(from text: String?) -> String? {
        guard let text else { return nil }
        let patterns = [
            #"(?:exp(?:ires|iration)?\.?|renew(?:al)?|valid\s+(?:thru|through|until)|good\s+(?:thru|through|until))\s*(?:date)?[:\s]*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})"#,
            #"(?:exp(?:ires|iration)?\.?|renew(?:al)?|valid\s+(?:thru|through|until)|good\s+(?:thru|through|until))\s*(?:date)?[:\s]*([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                guard match.numberOfRanges > 1, let swiftRange = Range(match.range(at: 1), in: text) else { continue }
                if let normalized = normalizedExpirationDate(String(text[swiftRange])) {
                    return normalized
                }
            }
        }
        return nil
    }

    private func cprUploadErrorMessage(from body: String?) -> String {
        guard let body,
              let data = body.data(using: .utf8),
              let payload = try? JSONDecoder().decode(CPRUploadErrorPayload.self, from: data) else {
            return "This CPR card could not be accepted. Upload a new card or ask an instructor to review it."
        }
        return payload.validationNotes ?? "This CPR card could not be accepted. Upload a new card or ask an instructor to review it."
    }

    private func normalizedExpirationDate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        let formats = ["M/d/yyyy", "MM/dd/yyyy", "M-d-yyyy", "MM-dd-yyyy", "M/d/yy", "MM/dd/yy", "MMM d yyyy", "MMMM d yyyy", "MMM d, yyyy", "MMMM d, yyyy"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }
        }
        return nil
    }

    private struct PendingCPRUpload {
        let data: Data
        let fileName: String
        let mimeType: String
        let recognizedText: String?
    }

    private struct CPRUploadErrorPayload: Decodable {
        let validationNotes: String?
    }

    private struct FullScreenImageURL: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }
}

private struct CPRCardFullScreenImage: View {
    let url: URL
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding()
                    case .failure:
                        ContentUnavailableView("Preview unavailable", systemImage: "photo")
                            .foregroundStyle(.white)
                    default:
                        LoadingSpinnerView()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
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
                    LoadingSpinnerView()
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

private struct WebViewContainer: View {
    let url: URL
    @State private var isLoading = true

    var body: some View {
        ZStack {
            LoadedWebView(url: url, isLoading: $isLoading)
            if isLoading {
                LoadingSpinnerView()
            }
        }
    }
}

private struct LoadedWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        isLoading = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            isLoading = true
            uiView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}

// WebView that detects a JotForm thank-you page by inspecting the page text or URL and calls onComplete once detected.
private struct SurveyWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onComplete: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading, onComplete: onComplete) }
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        isLoading = true
        webView.load(URLRequest(url: url))
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            isLoading = true
            uiView.load(URLRequest(url: url))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var onComplete: () -> Void
        init(isLoading: Binding<Bool>, onComplete: @escaping () -> Void) {
            _isLoading = isLoading
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
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

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}

private struct CheckoutSurveyContainer: View {
    let url: URL
    let onComplete: () -> Void
    let onCancel: () -> Void
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                SurveyWebView(url: url, isLoading: $isLoading, onComplete: {
                    // Close and notify
                    onComplete()
                })
                .edgesIgnoringSafeArea(.bottom)

                if isLoading {
                    LoadingSpinnerView()
                }
            }
            .navigationBarItems(leading: Button(action: onCancel) { Image(systemName: "xmark.circle.fill") })
        }
    }
}

private extension QuizInfo {
    func asInfo() -> QuizInfo { self }
}
