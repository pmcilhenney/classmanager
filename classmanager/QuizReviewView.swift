import SwiftUI

struct QuizReviewView: View {
    let config: AppConfig
    let attendee: RosterAttendee
    let quiz: QuizInfo
    var onLoaded: ((ClassManagerAPIClient.QuizReviewResponse) -> Void)?
    var onDone: (() -> Void)?
    var onDoneWithReview: ((ClassManagerAPIClient.QuizReviewResponse) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var review: ClassManagerAPIClient.QuizReviewResponse?
    @State private var isLoading = true
    @State private var loadingMessage = "Loading exam review..."
    @State private var errorText: String?
    @State private var fullReviewFilter: FullReviewFilter = .incorrect

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        LoadingSpinnerView()
                        Text(loadingMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let review {
                    reviewContent(review)
                } else {
                    ContentUnavailableView(
                        "Review unavailable",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(errorText ?? "No completed submission was found for this exam.")
                    )
                }
            }
            .navigationTitle("Exam Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if let review, let onDoneWithReview {
                            onDoneWithReview(review)
                        } else if let onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            await loadReview()
        }
    }

    private func reviewContent(_ review: ClassManagerAPIClient.QuizReviewResponse) -> some View {
        let questions = questionsForCurrentQuiz(review)
        let isSectionReview = quiz.questionRange != nil
        let incorrectQuestions = questions.filter { $0.isCorrect == false }
        let correctQuestions = questions.filter { $0.isCorrect == true }
        let unscoredQuestions = questions.filter { $0.isCorrect == nil }
        let selectedQuestions = filteredQuestions(for: fullReviewFilter, incorrect: incorrectQuestions, correct: correctQuestions, unscored: unscoredQuestions)
        let requiresVersionBRemediation = !isSectionReview
            && review.passed == false
            && !QuizInfo.isVersionBQuizId(review.quizId)
            && !QuizInfo.isVersionBQuizId(quiz.flexiQuizId)

        return List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(quiz.title)
                        .font(.headline)
                    HStack(spacing: 8) {
                        if isSectionReview, !questions.isEmpty {
                            StatusPill(text: sectionRatioText(questions), color: .blue)
                        } else if let passed = review.passed {
                            StatusPill(text: passed ? "Passed" : "Failed", color: passed ? .green : .red)
                        }
                        if !isSectionReview, let score = review.scoreText, !score.isEmpty {
                            StatusPill(text: score, color: .blue)
                        }
                        if !isSectionReview, let result = review.resultText, !result.isEmpty {
                            StatusPill(text: result, color: review.passed == false ? .red : .gray)
                        }
                    }
                    if let completed = review.completedAt, !completed.isEmpty {
                        Label(formatEasternTime(completed), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if requiresVersionBRemediation {
                        Label("Review your correct and incorrect responses, then tap Done to continue to the required Version B options.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                        if onDoneWithReview != nil {
                            Button {
                                onDoneWithReview?(review)
                            } label: {
                                Label("Continue to Version B Options", systemImage: "arrow.right.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if questions.isEmpty {
                Section {
                    Text("FlexiQuiz returned the completed attempt, but did not include question-level review data for this submission.")
                        .foregroundStyle(.secondary)
                }
            } else {
                if isSectionReview {
                    Section("Questions") {
                        ForEach(questions) { question in
                            QuestionReviewRow(question: question)
                        }
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            FullReviewFilterButton(
                                title: "Review Incorrect",
                                count: incorrectQuestions.count,
                                systemImage: "xmark.circle.fill",
                                color: .red,
                                isSelected: fullReviewFilter == .incorrect
                            ) {
                                fullReviewFilter = .incorrect
                            }

                            FullReviewFilterButton(
                                title: "Review Correct",
                                count: correctQuestions.count,
                                systemImage: "checkmark.circle.fill",
                                color: .green,
                                isSelected: fullReviewFilter == .correct
                            ) {
                                fullReviewFilter = .correct
                            }

                            if !unscoredQuestions.isEmpty {
                                FullReviewFilterButton(
                                    title: "Review Unscored",
                                    count: unscoredQuestions.count,
                                    systemImage: "circle.dashed",
                                    color: .secondary,
                                    isSelected: fullReviewFilter == .unscored
                                ) {
                                    fullReviewFilter = .unscored
                                }
                            }
                        }
                    }

                    Section(fullReviewFilter.sectionTitle(count: selectedQuestions.count)) {
                        if selectedQuestions.isEmpty {
                            Text(fullReviewFilter.emptyText)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(selectedQuestions) { question in
                                QuestionReviewRow(question: question)
                            }
                        }
                    }
                }
            }
        }
    }

    private func questionsForCurrentQuiz(_ review: ClassManagerAPIClient.QuizReviewResponse) -> [ClassManagerAPIClient.QuizReviewQuestion] {
        guard let range = quiz.questionRange else { return review.questions }
        return review.questions.filter { range.contains($0.number) }
    }

    private var passingScoreText: String {
        QuizInfo.passingPercentText(for: quiz.flexiQuizId)
    }

    private func filteredQuestions(
        for filter: FullReviewFilter,
        incorrect: [ClassManagerAPIClient.QuizReviewQuestion],
        correct: [ClassManagerAPIClient.QuizReviewQuestion],
        unscored: [ClassManagerAPIClient.QuizReviewQuestion]
    ) -> [ClassManagerAPIClient.QuizReviewQuestion] {
        switch filter {
        case .incorrect: return incorrect
        case .correct: return correct
        case .unscored: return unscored
        }
    }

    private func sectionRatioText(_ questions: [ClassManagerAPIClient.QuizReviewQuestion]) -> String {
        let answered = questions.filter { ($0.studentAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        guard !answered.isEmpty else { return "No answers yet" }
        let correct = answered.filter { $0.isCorrect == true }.count
        return "\(correct)/\(answered.count)"
    }

    private func loadReview() async {
        await MainActor.run {
            isLoading = true
            loadingMessage = QuizInfo.isVersionBQuizId(quiz.flexiQuizId)
                ? "Checking FlexiQuiz for Version B results..."
                : "Loading exam review..."
            errorText = nil
        }

        let email = attendee.email.isEmpty
            ? "\(attendee.firstName.lowercased()).\(attendee.lastName.lowercased())@\(config.flexiEmailDomain)"
            : attendee.email
        let maxAttempts = quiz.questionRange == nil ? 12 : 1

        for attempt in 1...maxAttempts {
            do {
                if attempt > 1 {
                    await MainActor.run {
                        loadingMessage = "Still checking FlexiQuiz... attempt \(attempt) of \(maxAttempts)"
                    }
                }

                let loaded = try await ClassManagerAPIClient.shared.fetchQuizReview(
                    attendee: attendee,
                    quizId: quiz.flexiQuizId,
                    email: email,
                    questionRange: quiz.questionRange,
                    includeInProgress: quiz.questionRange != nil
                )
                await MainActor.run {
                    review = loaded
                    isLoading = false
                    onLoaded?(loaded)
                }
                return
            } catch ClassManagerAPIClient.APIError.httpStatus(let status, _) {
                if status == 404 && attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }

                await MainActor.run {
                    errorText = status == 404
                        ? "No completed FlexiQuiz submission was found for \(attendee.fullName)."
                        : "FlexiQuiz review lookup failed."
                    isLoading = false
                }
                return
            } catch {
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }

                await MainActor.run {
                    errorText = "FlexiQuiz review lookup failed."
                    isLoading = false
                }
                return
            }
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
        formatter.dateFormat = "MMM d, yyyy h:mm a z"
        return formatter.string(from: date)
    }
}

private enum FullReviewFilter {
    case incorrect
    case correct
    case unscored

    func sectionTitle(count: Int) -> String {
        switch self {
        case .incorrect: return "Incorrect Items (\(count))"
        case .correct: return "Correct Items (\(count))"
        case .unscored: return "Unscored Items (\(count))"
        }
    }

    var emptyText: String {
        switch self {
        case .incorrect: return "No incorrectly answered questions were found."
        case .correct: return "No correctly answered questions were found."
        case .unscored: return "No unscored questions were found."
        }
    }
}

private struct FullReviewFilterButton: View {
    let title: String
    let count: Int
    let systemImage: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12), in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.08) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct QuestionReviewRow: View {
    let question: ClassManagerAPIClient.QuizReviewQuestion

    private var statusColor: Color {
        switch question.isCorrect {
        case true: return .green
        case false: return .red
        case nil: return .secondary
        }
    }

    private var statusIcon: String {
        switch question.isCorrect {
        case true: return "checkmark.circle.fill"
        case false: return "xmark.circle.fill"
        case nil: return "circle.dashed"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.title3)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 6) {
                    Text([question.section, "Question \(question.number)"].compactMap { $0 }.joined(separator: " • "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(question.prompt)
                        .font(.body.weight(.semibold))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let choices = question.choices, !choices.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choices")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(choices, id: \.self) { choice in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: choice == question.correctAnswer ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundStyle(choice == question.correctAnswer ? .green : .secondary)
                            Text(choice)
                                .font(.subheadline)
                                .foregroundStyle(choice == question.correctAnswer ? .green : .primary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 34)
            }

            answerBlock(title: "Your Answer", value: question.studentAnswer, color: question.isCorrect == false ? .red : .green)
            answerBlock(title: "Correct Answer", value: question.correctAnswer, color: .green)

            if let feedback = question.feedback, !feedback.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Rationale", systemImage: "text.bubble")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(feedback)
                        .font(.subheadline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 8)
    }

    private func answerBlock(title: String, value: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text((value?.isEmpty == false ? value : "Not provided") ?? "Not provided")
                .font(.subheadline)
                .foregroundStyle(color)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 34)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}
