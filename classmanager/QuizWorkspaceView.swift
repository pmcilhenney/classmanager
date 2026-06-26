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
    var onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var currentURL: URL?
    @State private var lastURL: URL?
    @State private var toast: String?
    @State private var showingReview = false
    @State private var webViewError: String?
    @State private var webViewReloadToken = UUID()

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
                if showingReview, let quiz {
                    QuizReviewView(
                        config: config,
                        attendee: attendee,
                        quiz: quiz,
                        onLoaded: { review in
                            onReviewLoaded?(quiz, review)
                        }
                    )
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
                            onResultDetected: {
                                isLoading = false
                                showingReview = true
                            },
                            onProcessTerminated: {
                                webViewError = "FlexiQuiz stopped responding inside the embedded exam window. Reloading the exam usually restores the session."
                            }
                        )
                        .id(webViewReloadToken)
                        .onChange(of: lastURL) { _ in
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
        .alert(toast ?? "", isPresented: Binding(
            get: { toast != nil },
            set: { if !$0 { toast = nil } }
        )) { Button("OK", role: .cancel) {} }
    }

    // MARK: - Flow

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
