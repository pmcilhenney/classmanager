//
//  QuizModels.swift
//  classmanager
//

import Foundation

struct QuizInfo: Identifiable {
    let id: String
    let flexiQuizId: String
    let number: Int
    let title: String
    let url: URL

    init(id: String, flexiQuizId: String? = nil, number: Int, title: String, url: URL) {
        self.id = id
        self.flexiQuizId = flexiQuizId ?? id
        self.number = number
        self.title = title
        self.url = url
    }
    
    static func refresherAQuizzes() -> [QuizInfo] {
        let combinedQuizId = "89db2c06-5052-4ff5-867b-95ef67fcfcd2"
        let combinedURL = URL(string: "https://www.flexiquiz.com/SC/N/\(combinedQuizId)")!
        return [
            QuizInfo(
                id: "refresher-a-page-1",
                flexiQuizId: combinedQuizId,
                number: 1,
                title: "Refresher A Mini-Quiz #1",
                url: combinedURL
            ),
            QuizInfo(
                id: "refresher-a-page-2",
                flexiQuizId: combinedQuizId,
                number: 2,
                title: "Refresher A Mini-Quiz #2",
                url: combinedURL
            ),
            QuizInfo(
                id: "refresher-a-page-3",
                flexiQuizId: combinedQuizId,
                number: 3,
                title: "Refresher A Mini-Quiz #3",
                url: combinedURL
            ),
            QuizInfo(
                id: "refresher-a-page-4",
                flexiQuizId: combinedQuizId,
                number: 4,
                title: "Refresher A Mini-Quiz #4",
                url: combinedURL
            )
        ]
    }
    
    static func refresherBQuizzes() -> [QuizInfo] {
        [
            QuizInfo(
            id: "3eff7d7c-74d4-44d8-bb4f-b8561c0c62b8",
            number: 1,
            title: "Refresher B Mini-Quiz #1",
            url: URL(string: "https://www.flexiquiz.com/SC/N/3eff7d7c-74d4-44d8-bb4f-b8561c0c62b8")!
        ),
        QuizInfo(
            id: "67ca0a1e-7c79-4ae7-aa55-418d10e9f3b5",
            number: 2,
            title: "Refresher B Mini-Quiz #2",
            url: URL(string: "https://www.flexiquiz.com/SC/N/67ca0a1e-7c79-4ae7-aa55-418d10e9f3b5")!
        ),
        QuizInfo(
            id: "e5fdb765-119b-4f5e-905b-c9b7d27ed2bb",
            number: 3,
            title: "Refresher B Mini-Quiz #3",
            url: URL(string: "https://www.flexiquiz.com/SC/N/e5fdb765-119b-4f5e-905b-c9b7d27ed2bb")!
        ),
        QuizInfo(
            id: "757c48dc-6ab2-4aad-a262-30ed854157c9",
            number: 4,
            title: "Refresher B Mini-Quiz #4",
            url: URL(string: "https://www.flexiquiz.com/SC/N/757c48dc-6ab2-4aad-a262-30ed854157c9")!
        )
        ]
    }
    
    static func refresherCQuizzes() -> [QuizInfo] {
        [
            QuizInfo(
            id: "ab8a5c9d-9e06-42c2-a866-e5759d8b2209",
            number: 1,
            title: "Refresher C Mini-Quiz #1",
            url: URL(string: "https://www.flexiquiz.com/SC/N/ab8a5c9d-9e06-42c2-a866-e5759d8b2209")!
        ),
        QuizInfo(
            id: "d76f4483-d8cc-4029-aea6-a2bebbb3d086",
            number: 2,
            title: "Refresher C Mini-Quiz #2",
            url: URL(string: "https://www.flexiquiz.com/SC/N/d76f4483-d8cc-4029-aea6-a2bebbb3d086")!
        ),
        QuizInfo(
            id: "b7adaf94-a911-4dad-8152-a5853cb02e35",
            number: 3,
            title: "Refresher C Mini-Quiz #3",
            url: URL(string: "https://www.flexiquiz.com/SC/N/b7adaf94-a911-4dad-8152-a5853cb02e35")!
        ),
        QuizInfo(
            id: "b938cd8b-913c-41bf-b247-1406b11115f2",
            number: 4,
            title: "Refresher C Mini-Quiz #4",
            url: URL(string: "https://www.flexiquiz.com/SC/N/b938cd8b-913c-41bf-b247-1406b11115f2")!
        )
            
            
        ]
    }
}
