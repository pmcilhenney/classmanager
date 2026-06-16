import SwiftUI
import Foundation

struct QuizWorkspaceView: View {
    let config: AppConfig
    let attendee: RosterAttendee
    let jotform: JotFormClient
    let flexi: FlexiQuizClient
    var onSSOLoaded: (() -> Void)?

    @State private var isLoading = false
    @State private var currentURL: URL?
    @State private var lastURL: URL?
    @State private var toast: String?

    var body: some View {
        ZStack {
            if let url = currentURL {
                FlexiWebView(url: url, lastURL: $lastURL, loading: $isLoading)
                .ignoresSafeArea()
                .onChange(of: lastURL) { _ in
                    // Called once when real content is visible in the webview
                    onSSOLoaded?()
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

        #if DEBUG
        print("[Quiz] ensureUserAndAssignQuiz email=\(email) quizId=\(quizId)")
        #endif

        // 3) Ensure user + assign quiz (fail silently if duplicate/500)
        do {
            _ = try await flexi.ensureUserAndAssignQuiz(
                email: email,
                firstName: attendee.firstName,
                lastName: attendee.lastName,
                oemsId: attendee.oemsId,
                quizId: quizId
            )
            #if DEBUG
            print("[Quiz] ensure/assign succeeded")
            #endif
        } catch {
            #if DEBUG
            print("[Quiz] ensure/assign failed: \(error)")
            #endif
            // Swallow server-side flakiness (e.g. 500 on create/assign when it actually exists already)
            // We still proceed to SSO; worst case the quiz is already assigned.
        }

        // 4) Build SSO – use auto-POST bridge for reliability
        let ssoURL = flexi.ssoAutoPostBridgeURL(userName: email, quizId: quizId)
            ?? flexi.ssoURL(userName: email, quizId: quizId)

        guard let url = ssoURL else {
            #if DEBUG
            print("[Quiz] Failed to build SSO URL")
            #endif
            await MainActor.run {
                isLoading = false
                toast = "Couldn’t build SSO URL."
            }
            return
        }

        #if DEBUG
        print("[Quiz] SSO URL generated successfully")
        #endif

        await MainActor.run {
            currentURL = url
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

