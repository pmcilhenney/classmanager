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
    // Called when selection is blocked (e.g., previous quiz not completed)
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

                                        // If we have a parsed result from CloudKit, show it as a contrasting "chip" (Pass/Fail or score).
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
                .padding()
            }
        }
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

    private func attemptSelect(_ quiz: QuizInfo) {
        if completedQuizzes.contains(quiz.id) {
            onReview(quiz)
            return
        }

        // Quizzes must be completed in order. If this is quiz number > 1, ensure previous quiz is completed.
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

// Local Accent button style used by quiz selector
private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.997 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
