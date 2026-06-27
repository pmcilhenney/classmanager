import SwiftUI
import Foundation

struct QuizWorkspaceView: View {
    let config: AppConfig
    let attendee: RosterAttendee
    let jotform: JotFormClient
    let flexi: FlexiQuizClient
    var quiz: QuizInfo?
    var onSSOLoaded: (() -> Void)?
    var onReviewLoaded: ((QuizInfo, ClassManagerAPIClient.QuizReviewResponse) -> Void)?
    var onPageCheckpoint: ((QuizInfo, FlexiQuizPageNavigationEvent) -> Void)?
    var onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var currentURL: URL?
    @State private var lastURL: URL?
    @State private var toast: String?
    @State private var showingReview = false
    @State private var webViewError: String?
    @State private var webViewReloadToken = UUID()
    @State private var pageNavigationEvent: FlexiQuizPageNavigationEvent?
    @State private var isCheckingSectionCompletion = false
    @State private var reviewQuiz: QuizInfo?
    @State private var sectionTransitionMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if let onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                } label: {
                    Label("Back to Exams", systemImage: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                }

                Spacer()

                Text(quiz?.title ?? "Exam")
                    .font(.headline)

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            ZStack {
                if let event = pageNavigationEvent, let quiz {
                    QuizPageCheckpointView(
                        quiz: quiz,
                        event: event,
                        onBackToExams: {
                            if let onBack {
                                onBack()
                            } else {
                                dismiss()
                            }
                        },
                        onReviewQuiz: {
                            pageNavigationEvent = nil
                            showingReview = true
                        }
                    )
                } else if showingReview, let quiz {
                    let activeReviewQuiz = reviewQuiz ?? quiz
                    QuizReviewView(
                        config: config,
                        attendee: attendee,
                        quiz: activeReviewQuiz,
                        onLoaded: { review in
                            onReviewLoaded?(activeReviewQuiz, review)
                        },
                        onDone: {
                            showingReview = false
                            reviewQuiz = nil
                            if let onBack {
                                onBack()
                            } else {
                                dismiss()
                            }
                        }
                    )
                } else if let sectionTransitionMessage {
                    VStack(spacing: 14) {
                        LoadingSpinnerView()
                        Text(sectionTransitionMessage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if let url = currentURL {
                    if let webViewError {
                        ContentUnavailableView {
                            Label("Exam Web View Stopped", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(webViewError)
                        } actions: {
                            Button("Reload Exam") {
                                self.webViewError = nil
                                webViewReloadToken = UUID()
                                isLoading = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        FlexiWebView(
                            url: url,
                            lastURL: $lastURL,
                            loading: $isLoading,
                            pageNavigationEventsToIgnore: initialPageNavigationEventsToIgnore,
                            onResultDetected: {
                                isLoading = false
                                sectionTransitionMessage = nil
                                if quiz?.questionRange == nil || quiz?.number == 4 {
                                    if let quiz, quiz.number == 4 {
                                        reviewQuiz = fullExamReviewQuiz(from: quiz)
                                    }
                                    showingReview = true
                                }
                            },
                            onPageNavigationDetected: { event in
                                isLoading = false
                                handlePageNavigation(event)
                            },
                            onProcessTerminated: {
                                webViewError = "FlexiQuiz stopped responding inside the embedded exam window. Reloading the exam usually restores the session."
                            }
                        )
                        .id(webViewReloadToken)
                        .onChange(of: lastURL) {
                            // Called once when real content is visible in the webview
                            isLoading = false
                            onSSOLoaded?()
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        LoadingSpinnerView()
                        Text("Preparing quiz…").font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                }

                if isLoading {
                    LoadingSpinnerView()
                }
            }
        }
        .task {
            await launchOrResumeQuiz()
        }
        .onChange(of: quiz?.id) {
            pageNavigationEvent = nil
            showingReview = false
            reviewQuiz = nil
            sectionTransitionMessage = nil
            webViewError = nil
            currentURL = nil
            lastURL = nil
            isCheckingSectionCompletion = false
            Task { await launchOrResumeQuiz() }
        }
        .alert(toast ?? "", isPresented: Binding(
            get: { toast != nil },
            set: { if !$0 { toast = nil } }
        )) { Button("OK", role: .cancel) {} }
    }

    private var initialPageNavigationEventsToIgnore: Int {
        guard let quiz, quiz.questionRange != nil else { return 0 }
        return 1
    }

    // MARK: - Flow

    private func handlePageNavigation(_ event: FlexiQuizPageNavigationEvent) {
        guard let quiz else { return }
        guard quiz.questionRange != nil else {
            return
        }
        guard !isCheckingSectionCompletion else { return }

        isCheckingSectionCompletion = true
        sectionTransitionMessage = quiz.number == 4
            ? "Submitting the full exam..."
            : "Preparing your section review..."
        Task {
            let accepted = await sectionHasEnoughAnswers(for: quiz)
            await MainActor.run {
                isCheckingSectionCompletion = false
                guard accepted else {
                    sectionTransitionMessage = nil
                    return
                }
                onPageCheckpoint?(quiz, event)
                sectionTransitionMessage = nil
                if quiz.number == 4 {
                    reviewQuiz = fullExamReviewQuiz(from: quiz)
                    showingReview = true
                    pageNavigationEvent = nil
                } else {
                    pageNavigationEvent = event
                }
            }
        }
    }

    private func sectionHasEnoughAnswers(for quiz: QuizInfo) async -> Bool {
        guard let questionRange = quiz.questionRange else { return true }
        let email = attendee.email.isEmpty
            ? "\(attendee.firstName.lowercased()).\(attendee.lastName.lowercased())@\(config.flexiEmailDomain)"
            : attendee.email

        for attempt in 0..<2 {
            do {
                let review = try await ClassManagerAPIClient.shared.fetchQuizReview(
                    attendee: attendee,
                    quizId: quiz.flexiQuizId,
                    email: email,
                    questionRange: questionRange,
                    includeInProgress: true
                )
                let answered = review.questions.filter { ($0.studentAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count
                if answered >= questionRange.count {
                    return true
                }
            } catch {
                if attempt == 1 {
                    return false
                }
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        return false
    }

    private func fullExamReviewQuiz(from quiz: QuizInfo) -> QuizInfo {
        QuizInfo(
            id: "full-exam-review-\(quiz.flexiQuizId)",
            flexiQuizId: quiz.flexiQuizId,
            number: 0,
            title: "Full Exam Review",
            url: quiz.url
        )
    }

    private func launchOrResumeQuiz() async {
        await MainActor.run { isLoading = true }

        let courseName = cleanCourseName(attendee.courseType)

        #if DEBUG
        print("[Quiz] courseName(cleaned)=\(courseName)")
        #endif

        // Fuzzy match: treat any course containing "pepp" or the full phrase as PEPP
        let lower = courseName.lowercased()
        let isPEPP = lower.contains("pepp") || lower.contains("pediatric education for prehospital professionals")

        #if DEBUG
        print("[Quiz] isPEPP=\(isPEPP)")
        #endif

        let resolvedQuizId: String? = {
            if let quiz {
                return quiz.flexiQuizId
            }
            if isPEPP {
                if let id = Bundle.main.object(forInfoDictionaryKey: "PEPP_QUIZ_ID") as? String,
                   !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return id
                }
                return nil
            } else {
                return flexi.quizId(for: courseName)
            }
        }()

        #if DEBUG
        let dbgId = resolvedQuizId ?? "(nil)"
        print("[Quiz] resolvedQuizId=\(dbgId)")
        if isPEPP, dbgId == "(nil)" {
            let raw = Bundle.main.object(forInfoDictionaryKey: "PEPP_QUIZ_ID") as? String ?? "(missing)"
            print("[Quiz] PEPP_QUIZ_ID from Info.plist=\(raw)")
        }
        #endif

        guard let quizId = resolvedQuizId else {
            await MainActor.run {
                isLoading = false
                toast = "No quiz configured for \(courseName)."
            }
            return
        }

        // 2) Email fallback if blank
        let email = attendee.email.isEmpty
            ? attendee.firstName.lowercased() + "." + attendee.lastName.lowercased() + "@\(config.flexiEmailDomain)"
            : attendee.email

        let launch: ClassManagerAPIClient.QuizAssignResponse
        do {
            launch = try await ClassManagerAPIClient.shared.assignQuiz(
                attendee: attendee,
                email: email,
                quizId: quizId
            )
        } catch {
            #if DEBUG
            print("[Quiz] Worker assign/SSO failed: \(error)")
            #endif
            await MainActor.run {
                isLoading = false
                toast = error.localizedDescription
            }
            return
        }

        #if DEBUG
        print("[Quiz] Worker SSO URL generated successfully warnings=\(launch.warnings)")
        #endif

        await MainActor.run {
            webViewError = nil
            pageNavigationEvent = nil
            webViewReloadToken = UUID()
            currentURL = launch.launchUrl
            // isLoading stays true; FlexiWebView will turn it false on finish/fail/timeout
        }
    }

    // MARK: - Local helpers

    private func cleanCourseName(_ s: String) -> String {
        // Only remove TRAILING parentheticals like "(8AM - 5PM)" or "(time ranges)"
        // Preserve leading ones like "(PEPP)" in "(PEPP) Pediatric Education..."
        if let r = s.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            let before = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            let after = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            // If there's substantial text after the paren match, it's likely a leading code. Keep original.
            if after.isEmpty && before.isEmpty {
                return s
            }
            // If before is empty or very short, and after is long, original paren was leading
            if before.isEmpty || before.count < 5 {
                return s
            }
            // Otherwise, before is the main text and after is empty -> remove trailing paren
            return before
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}

private struct QuizPageCheckpointView: View {
    let quiz: QuizInfo
    let event: FlexiQuizPageNavigationEvent
    let onBackToExams: () -> Void
    let onReviewQuiz: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("\(quiz.title) Submitted")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("This section was accepted by FlexiQuiz. Return to the exam list to continue the next mini-quiz section.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            HStack(spacing: 12) {
                Button {
                    onReviewQuiz()
                } label: {
                    Label("Review Quiz", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)

                Button {
                    onBackToExams()
                } label: {
                    Label("Back to Exams", systemImage: "list.bullet.clipboard")
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(spacing: 4) {
                if !event.title.isEmpty {
                    Text(event.title)
                }
                Text(formatEasternTime(event.at))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func formatEasternTime(_ rawValue: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackISO = ISO8601DateFormatter()
        let date = iso.date(from: rawValue) ?? fallbackISO.date(from: rawValue)

        guard let date else { return rawValue }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "MMM d, yyyy h:mm a z"
        return formatter.string(from: date)
    }
}
