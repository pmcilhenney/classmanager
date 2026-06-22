import SwiftUI

struct QuizReviewView: View {
    let config: AppConfig
    let attendee: RosterAttendee
    let quiz: QuizInfo

    @Environment(\.dismiss) private var dismiss
    @State private var review: ClassManagerAPIClient.QuizReviewResponse?
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        LoadingSpinnerView()
                        Text("Loading exam review...")
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
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadReview()
        }
    }

    private func reviewContent(_ review: ClassManagerAPIClient.QuizReviewResponse) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(quiz.title)
                        .font(.headline)
                    HStack(spacing: 8) {
                        if let passed = review.passed {
                            StatusPill(text: passed ? "Passed" : "Failed", color: passed ? .green : .red)
                        }
                        if let score = review.scoreText, !score.isEmpty {
                            StatusPill(text: score, color: .blue)
                        }
                        if let result = review.resultText, !result.isEmpty {
                            StatusPill(text: result, color: review.passed == false ? .red : .gray)
                        }
                    }
                    if let completed = review.completedAt, !completed.isEmpty {
                        Label(completed, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if review.questions.isEmpty {
                Section {
                    Text("FlexiQuiz returned the completed attempt, but did not include question-level review data for this submission.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Questions") {
                    ForEach(review.questions) { question in
                        QuestionReviewRow(question: question)
                    }
                }
            }
        }
    }

    private func loadReview() async {
        await MainActor.run {
            isLoading = true
            errorText = nil
        }

        do {
            let email = attendee.email.isEmpty
                ? "\(attendee.firstName.lowercased()).\(attendee.lastName.lowercased())@\(config.flexiEmailDomain)"
                : attendee.email
            let loaded = try await ClassManagerAPIClient.shared.fetchQuizReview(
                attendee: attendee,
                quizId: quiz.id,
                email: email
            )
            await MainActor.run {
                review = loaded
                isLoading = false
            }
        } catch ClassManagerAPIClient.APIError.httpStatus(let status, _) {
            await MainActor.run {
                errorText = status == 404
                    ? "No completed FlexiQuiz submission was found for \(attendee.fullName)."
                    : "FlexiQuiz review lookup failed."
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorText = "FlexiQuiz review lookup failed."
                isLoading = false
            }
        }
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
                    Text("Question \(question.number)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(question.prompt)
                        .font(.body.weight(.semibold))
                }
            }

            answerBlock(title: "Your Answer", value: question.studentAnswer, color: question.isCorrect == false ? .red : .green)
            answerBlock(title: "Correct Answer", value: question.correctAnswer, color: .green)

            if let feedback = question.feedback, !feedback.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Feedback", systemImage: "text.bubble")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(feedback)
                        .font(.subheadline)
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
