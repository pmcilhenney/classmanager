//
//  QuizModels.swift
//  classmanager
//

import Foundation

struct QuizInfo: Identifiable {
    static let refresherACombinedQuizId = "89db2c06-5052-4ff5-867b-95ef67fcfcd2"
    static let refresherBCombinedQuizId = "bcab075c-a56a-459c-b313-f7b3966d7bb4"
    static let refresherCCombinedQuizId = "7f21b940-8344-4614-a935-49f2ea4218c7"
    static let refresherAQuizIds = [
        "66564166-9de9-4b17-9c2d-6f76bc186970",
        "78df99bd-d81a-4f24-a855-81ea0a3a71ec",
        "772e07cf-d20b-4c8e-a6a5-d2917f5aa5c7",
        "16ca7d9a-d3a4-4a24-85fe-ccb49def519d"
    ]
    static let refresherBQuizIds = [
        "3eff7d7c-74d4-44d8-bb4f-b8561c0c62b8",
        "67ca0a1e-7c79-4ae7-aa55-418d10e9f3b5",
        "e5fdb765-119b-4f5e-905b-c9b7d27ed2bb",
        "757c48dc-6ab2-4aad-a262-30ed854157c9"
    ]
    static let refresherCQuizIds = [
        "ab8a5c9d-9e06-42c2-a866-e5759d8b2209",
        "d76f4483-d8cc-4029-aea6-a2bebbb3d086",
        "b7adaf94-a911-4dad-8152-a5853cb02e35",
        "b938cd8b-913c-41bf-b247-1406b11115f2"
    ]
    static let refresherAVersionBQuizId = "a08bbc93-3c52-4ea9-9bbb-e9c2de39266b"
    static let refresherBVersionBQuizId = "76483815-190a-4c67-89ff-2e69c74b0c2a"
    static let refresherCVersionBQuizId = "36088669-4530-48b8-ae82-1f549009d380"
    static let versionAPassingPercent = 70
    static let versionBPassingPercent = 75

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

    static func versionBRemediationRequestedMarkerId(for combinedQuizId: String) -> String {
        "\(combinedQuizId)-version-b-remediation-requested"
    }

    static func versionBRemediationDeclinedMarkerId(for combinedQuizId: String) -> String {
        "\(combinedQuizId)-version-b-remediation-declined"
    }

    static func versionBRemediationCompletedMarkerId(for combinedQuizId: String) -> String {
        "\(combinedQuizId)-version-b-remediation-completed"
    }

    static func isCombinedVersionAQuizId(_ quizId: String) -> Bool {
        [refresherACombinedQuizId, refresherBCombinedQuizId, refresherCCombinedQuizId].contains(quizId)
    }

    static func isVersionBQuizId(_ quizId: String) -> Bool {
        [refresherAVersionBQuizId, refresherBVersionBQuizId, refresherCVersionBQuizId].contains(quizId)
    }

    static func isVersionAQuizId(_ quizId: String) -> Bool {
        (refresherAQuizIds + refresherBQuizIds + refresherCQuizIds).contains(quizId)
    }

    static func versionAQuizIds(forCourseTitle courseTitle: String) -> [String] {
        let normalized = courseTitle.lowercased()
        if normalized.contains("refresher a") { return refresherAQuizIds }
        if normalized.contains("refresher b") { return refresherBQuizIds }
        if normalized.contains("refresher c") { return refresherCQuizIds }
        return []
    }

    static func passingPercent(for quizId: String) -> Int {
        isVersionBQuizId(quizId) ? versionBPassingPercent : versionAPassingPercent
    }

    static func passingPercentText(for quizId: String) -> String {
        "\(passingPercent(for: quizId))%"
    }

    static func versionBQuiz(forCombinedQuizId combinedQuizId: String) -> QuizInfo? {
        switch combinedQuizId {
        case refresherACombinedQuizId:
            return versionBQuiz(courseLetter: "A", quizId: refresherAVersionBQuizId)
        case refresherBCombinedQuizId:
            return versionBQuiz(courseLetter: "B", quizId: refresherBVersionBQuizId)
        case refresherCCombinedQuizId:
            return versionBQuiz(courseLetter: "C", quizId: refresherCVersionBQuizId)
        default:
            return nil
        }
    }

    private static func versionAQuizzes(courseLetter: String, quizIds: [String]) -> [QuizInfo] {
        quizIds.enumerated().map { index, quizId in
            QuizInfo(
                id: quizId,
                flexiQuizId: quizId,
                number: index + 1,
                title: "Refresher \(courseLetter) Mini-Quiz #\(index + 1)",
                url: URL(string: "https://www.flexiquiz.com/SC/N/\(quizId)")!
            )
        }
    }

    static func refresherAQuizzes() -> [QuizInfo] {
        versionAQuizzes(courseLetter: "A", quizIds: refresherAQuizIds)
    }

    static func refresherAVersionBQuiz() -> QuizInfo {
        versionBQuiz(courseLetter: "A", quizId: refresherAVersionBQuizId)
    }

    private static func versionBQuiz(courseLetter: String, quizId: String) -> QuizInfo {
        QuizInfo(
            id: "refresher-\(courseLetter.lowercased())-version-b",
            flexiQuizId: quizId,
            number: 5,
            title: "Refresher \(courseLetter) Version B Retest",
            url: URL(string: "https://www.flexiquiz.com/SC/N/\(quizId)")!
        )
    }
    
    static func refresherBQuizzes() -> [QuizInfo] {
        versionAQuizzes(courseLetter: "B", quizIds: refresherBQuizIds)
    }
    
    static func refresherCQuizzes() -> [QuizInfo] {
        versionAQuizzes(courseLetter: "C", quizIds: refresherCQuizIds)
    }
}
