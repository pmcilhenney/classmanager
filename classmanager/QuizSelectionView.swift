import SwiftUI

//
//  QuizSelectionView.swift
//  classmanager
//

struct QuizSelectionView: View {
    @ObservedObject var progressStore: CKProgressStore
    let attendee: RosterAttendee
    let quizURLs: [QuizInfo]
    @Binding var selectedQuiz: QuizInfo?
    @Binding var completedQuizzes: Set<String>
    var onBlocked: (String) -> Void = { _ in }
    var onReview: (QuizInfo) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Course Quizzes")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    if let finalResult = progressStore.progress.finalExamResult {
                        fullExamReviewCard(finalResult)
                    } else {
                        miniQuizCards
                    }
                }
                .padding()
            }
        }
    }

    private var miniQuizCards: some View {
        ForEach(quizURLs) { quiz in
            let locked = isLocked(quiz)
            let completed = completedQuizzes.contains(quiz.id)
            VStack(alignment: .leading, spacing: 10) {
                Button(action: {
                    attemptSelect(quiz)
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            if completed {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 50, height: 50)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            } else if locked {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 50, height: 50)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.accentColor)
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 50, height: 50)
                                Text("\(quiz.number)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.accentColor)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(quiz.title)
                                .font(.headline)
                                .foregroundColor(.white)

                            if let result = progressStore.progress.quizResults[quiz.id] {
                                Text(displayResult(result, for: quiz))
                                    .font(.subheadline).bold()
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            } else if locked {
                                Text("Locked")
                                    .font(.subheadline)
                                    .foregroundColor(Color.white.opacity(0.85))
                            } else {
                                Text("Tap to start")
                                    .font(.subheadline)
                                    .foregroundColor(Color.white.opacity(0.85))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if completed {
                    Button {
                        onReview(quiz)
                    } label: {
                        Label("Review Quiz", systemImage: "doc.text.magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 66)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .buttonStyle(AccentButtonStyle())
        }
    }

    private func fullExamReviewCard(_ result: ClassManagerAPIClient.FinalExamResult) -> some View {
        let passed = result.passed
        let color: Color = passed == false ? .red : .green
        let status = passed == false ? "Final Exam Failed" : (passed == true ? "Final Exam Passed" : "Final Exam Result")
        let score = result.scoreText ?? result.percentageScore.map { "\(Int($0.rounded()))%" }

        return Button {
            if let fullExam = fullExamReviewQuiz(from: result) {
                onReview(fullExam)
            } else {
                onBlocked("The final exam review is not ready yet.")
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: passed == false ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full Exam Review")
                            .font(.headline)
                        Text(status)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color)
                    }
                    Spacer()
                    if let score {
                        Text(score)
                            .font(.headline)
                            .foregroundStyle(color)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }

                if passed == false {
                    Text("Review and remediation required for scores below 74%. Version B unlocks after review and instructor remediation.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
                if let completedAt = result.completedAt {
                    Label(formatEasternTime(completedAt), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .buttonStyle(.plain)
    }

    private func fullExamReviewQuiz(from result: ClassManagerAPIClient.FinalExamResult) -> QuizInfo? {
        let quizId = result.quizId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quizId.isEmpty,
              let url = URL(string: "https://www.flexiquiz.com/SC/N/\(quizId)") else {
            return nil
        }
        let title = result.quizName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return QuizInfo(
            id: "full-exam-review-\(quizId)",
            flexiQuizId: quizId,
            number: 0,
            title: title?.isEmpty == false ? title! : "Full Exam Review",
            url: url
        )
    }

    private func isLocked(_ quiz: QuizInfo) -> Bool {
        guard quiz.number > 1 else { return false }
        let previousNumber = quiz.number - 1
        guard let previous = quizURLs.first(where: { $0.number == previousNumber }) else { return false }
        return !completedQuizzes.contains(previous.id)
    }

    private func displayResult(_ result: String, for quiz: QuizInfo) -> String {
        guard quiz.questionRange != nil else { return result }
        let lower = result.lowercased()
        if lower.contains("pass") || lower.contains("fail") {
            return "Section submitted"
        }
        return result
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

    private func attemptSelect(_ quiz: QuizInfo) {
        if completedQuizzes.contains(quiz.id) {
            onReview(quiz)
            return
        }

        if isLocked(quiz) {
            let prevNumber = quiz.number - 1
            if let prev = quizURLs.first(where: { $0.number == prevNumber }) {
                onBlocked("Please complete \(prev.title) before attempting this quiz.")
            } else {
                onBlocked("Please complete the previous quiz before attempting this quiz.")
            }
            return
        }
        selectedQuiz = quiz
    }
}

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.997 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
