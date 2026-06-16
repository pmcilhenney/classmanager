//
//  StudentParser.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/29/25.
//
import Foundation

struct StudentParser {

    private let parser = JotFormSubmissionParser()

    func parseStudent(from data: Data) -> Student? {
        return parser.parse(data: data)
    }
}

