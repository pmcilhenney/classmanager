//
//  QuizModels.swift
//  classmanager
//

import Foundation

struct QuizInfo: Identifiable {
    static let refresherACombinedQuizId = "89db2c06-5052-4ff5-867b-95ef67fcfcd2"
    static let refresherBCombinedQuizId = "bcab075c-a56a-459c-b313-f7b3966d7bb4"
    static let refresherCCombinedQuizId = "7f21b940-8344-4614-a935-49f2ea4218c7"
    static let refresherAVersionBQuizId = "a08bbc93-3c52-4ea9-9bbb-e9c2de39266b"

    let id: String
    let flexiQuizId: String
    let number: Int
    let title: String
    let url: URL
    let questionRange: ClosedRange<Int>?

    init(id: String, flexiQuizId: String? = nil, number: Int, title: String, url: URL, questionRange: ClosedRange<Int>? = nil) {
        self.id = id
        self.flexiQuizId = flexiQuizId ?? id
        self.number = number
        self.title = title
        self.url = url
        self.questionRange = questionRange
    }
    
    static func versionAReviewMarkerId(for combinedQuizId: String) -> String {
        "\(combinedQuizId)-version-a-review-complete"
    }

    static func versionBStartedMarkerId(for versionBQuizId: String) -> String {
        "\(versionBQuizId)-version-b-started"
    }

    static func isCombinedVersionAQuizId(_ quizId: String) -> Bool {
        [refresherACombinedQuizId, refresherBCombinedQuizId, refresherCCombinedQuizId].contains(quizId)
    }

    static func isVersionBQuizId(_ quizId: String) -> Bool {
        quizId == refresherAVersionBQuizId
    }

    static func versionBQuiz(forCombinedQuizId combinedQuizId: String) -> QuizInfo? {
        switch combinedQuizId {
        case refresherACombinedQuizId:
            return refresherAVersionBQuiz()
        default:
            return nil
        }
    }

    private static func combinedQuizzes(courseLetter: String, combinedQuizId: String, ranges: [ClosedRange<Int>]) -> [QuizInfo] {
        let combinedURL = URL(string: "https://www.flexiquiz.com/SC/N/\(combinedQuizId)")!
        return ranges.enumerated().map { index, range in
            QuizInfo(
                id: "refresher-\(courseLetter.lowercased())-page-\(index + 1)",
                flexiQuizId: combinedQuizId,
                number: index + 1,
                title: "Refresher \(courseLetter) Mini-Quiz #\(index + 1)",
                url: combinedURL,
                questionRange: range
            )
        }
    }

    static func refresherAQuizzes() -> [QuizInfo] {
        combinedQuizzes(
            courseLetter: "A",
            combinedQuizId: refresherACombinedQuizId,
            ranges: [1...12, 13...25, 26...38, 39...50]
        )
    }

    static func refresherAVersionBQuiz() -> QuizInfo {
        QuizInfo(
            id: "refresher-a-version-b",
            flexiQuizId: refresherAVersionBQuizId,
            number: 5,
            title: "Refresher A Version B Retest",
            url: URL(string: "https://www.flexiquiz.com/SC/N/\(refresherAVersionBQuizId)")!
        )
    }
    
    static func refresherBQuizzes() -> [QuizInfo] {
        combinedQuizzes(
            courseLetter: "B",
            combinedQuizId: refresherBCombinedQuizId,
            ranges: [1...12, 13...25, 26...37, 38...50]
        )
    }
    
    static func refresherCQuizzes() -> [QuizInfo] {
        combinedQuizzes(
            courseLetter: "C",
            combinedQuizId: refresherCCombinedQuizId,
            ranges: [1...13, 14...25, 26...38, 39...50]
        )
    }
}
