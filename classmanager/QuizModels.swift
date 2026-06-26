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
                id: "73c71545-8d3b-45ef-b0c6-e0de27733df5",
                number: 1,
                title: "Refresher A Mini-Quiz #1",
                url: URL(string: "https://www.flexiquiz.com/SC/N/73c71545-8d3b-45ef-b0c6-e0de27733df5")!
            ),
            QuizInfo(
                id: "41b6732a-dbfd-4663-8265-484b7256e34f",
                number: 2,
                title: "Refresher A Mini-Quiz #2",
                url: URL(string: "https://www.flexiquiz.com/SC/N/41b6732a-dbfd-4663-8265-484b7256e34f")!
            ),
            QuizInfo(
                id: "42797c34-bbe7-4048-9b04-b206d6663e35",
                number: 3,
                title: "Refresher A Mini-Quiz #3",
                url: URL(string: "https://www.flexiquiz.com/SC/N/42797c34-bbe7-4048-9b04-b206d6663e35")!
            ),
            QuizInfo(
                id: "1295f5ad-3fdc-43a1-8386-037a5dee8ecc",
                number: 4,
                title: "Refresher A Mini-Quiz #4",
                url: URL(string: "https://www.flexiquiz.com/SC/N/1295f5ad-3fdc-43a1-8386-037a5dee8ecc")!
            )
        ]
    }
    
    static func refresherBQuizzes() -> [QuizInfo] {
        [
            QuizInfo(
            id: "a83694f9-baff-4d48-853e-653f5c0f8468",
            number: 1,
            title: "Refresher B Mini-Quiz #1",
            url: URL(string: "https://www.flexiquiz.com/SC/N/a83694f9-baff-4d48-853e-653f5c0f8468")!
        ),
        QuizInfo(
            id: "0f051560-59f5-4812-8874-e44968104bbc",
            number: 2,
            title: "Refresher B Mini-Quiz #2",
            url: URL(string: "https://www.flexiquiz.com/SC/N/0f051560-59f5-4812-8874-e44968104bbc")!
        ),
        QuizInfo(
            id: "b43eba66-0a3b-4136-ae95-4d4b806b36f7",
            number: 3,
            title: "Refresher B Mini-Quiz #3",
            url: URL(string: "https://www.flexiquiz.com/SC/N/b43eba66-0a3b-4136-ae95-4d4b806b36f7")!
        ),
        QuizInfo(
            id: "86dfa414-1245-406b-be54-8572e5b82812",
            number: 4,
            title: "Refresher B Mini-Quiz #4",
            url: URL(string: "https://www.flexiquiz.com/SC/N/86dfa414-1245-406b-be54-8572e5b82812")!
        )
        ]
    }
    
    static func refresherCQuizzes() -> [QuizInfo] {
        [
            QuizInfo(
            id: "dc9e0a85-4ac7-4418-b843-6a1c1edcfb5d",
            number: 1,
            title: "Refresher C Mini-Quiz #1",
            url: URL(string: "https://www.flexiquiz.com/SC/N/dc9e0a85-4ac7-4418-b843-6a1c1edcfb5d")!
        ),
        QuizInfo(
            id: "797d9c0b-bb05-4273-b2ee-418a870b376b",
            number: 2,
            title: "Refresher C Mini-Quiz #2",
            url: URL(string: "https://www.flexiquiz.com/SC/N/797d9c0b-bb05-4273-b2ee-418a870b376b")!
        ),
        QuizInfo(
            id: "99315211-1727-42cc-b7de-8b5c4843149b",
            number: 3,
            title: "Refresher C Mini-Quiz #3",
            url: URL(string: "https://www.flexiquiz.com/SC/N/99315211-1727-42cc-b7de-8b5c4843149b")!
        ),
        QuizInfo(
            id: "0ce0a5ce-2e06-46dc-8915-310d008b6eed",
            number: 4,
            title: "Refresher C Mini-Quiz #4",
            url: URL(string: "https://www.flexiquiz.com/SC/N/0ce0a5ce-2e06-46dc-8915-310d008b6eed")!
        )
            
            
        ]
    }
}
