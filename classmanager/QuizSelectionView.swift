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
                        Button(action: {
                            attemptSelect(quiz)
                        }) {
                            HStack(spacing: 16) {
                                // Left badge: when completed show green check, otherwise white badge with accent-colored number
                                ZStack {
                                    if completedQuizzes.contains(quiz.id) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
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
                                        let lower = result.lowercased()
                                        Text(result)
                                            .font(.subheadline).bold()
                                            .foregroundColor(lower.contains("pass") ? .green : (lower.contains("fail") ? .red : .primary))
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color.white)
                                            .clipShape(Capsule())
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
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor)
                                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(AccentButtonStyle())
                    }
                }
                .padding()
            }
        }
    }

    private func attemptSelect(_ quiz: QuizInfo) {
        // Quizzes must be completed in order. If this is quiz number > 1, ensure previous quiz is completed.
        if quiz.number > 1 {
            let prevNumber = quiz.number - 1
            if let prev = quizURLs.first(where: { $0.number == prevNumber }) {
                if !completedQuizzes.contains(prev.id) {
                    onBlocked("Please complete \(prev.title) before attempting this quiz.")
                    return
                }
            }
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
