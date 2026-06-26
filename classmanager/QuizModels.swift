//
//  QuizModels.swift
//  classmanager
//

import Foundation

struct QuizInfo: Identifiable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    
    static func refresherAQuizzes() -> [QuizInfo] {
        [
            QuizInfo(
                id: "66564166-9de9-4b17-9c2d-6f76bc186970",
                number: 1,
                title: "Refresher A Mini-Quiz #1",
                url: URL(string: "https://www.flexiquiz.com/SC/N/66564166-9de9-4b17-9c2d-6f76bc186970")!
            ),
            QuizInfo(
                id: "78df99bd-d81a-4f24-a855-81ea0a3a71ec",
                number: 2,
                title: "Refresher A Mini-Quiz #2",
                url: URL(string: "https://www.flexiquiz.com/SC/N/78df99bd-d81a-4f24-a855-81ea0a3a71ec")!
            ),
            QuizInfo(
                id: "772e07cf-d20b-4c8e-a6a5-d2917f5aa5c7",
                number: 3,
                title: "Refresher A Mini-Quiz #3",
                url: URL(string: "https://www.flexiquiz.com/SC/N/772e07cf-d20b-4c8e-a6a5-d2917f5aa5c7")!
            ),
            QuizInfo(
                id: "16ca7d9a-d3a4-4a24-85fe-ccb49def519d",
                number: 4,
                title: "Refresher A Mini-Quiz #4",
                url: URL(string: "https://www.flexiquiz.com/SC/N/16ca7d9a-d3a4-4a24-85fe-ccb49def519d")!
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
