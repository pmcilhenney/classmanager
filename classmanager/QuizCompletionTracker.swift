//
//  QuizCompletionTracker.swift
//  classmanager
//
//  CloudKit tracking for quiz completion
//

import Foundation
import CloudKit

actor QuizCompletionTracker {
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        container = CKContainer(identifier: "iCloud.icloud.org.gcems.classmanager")
        database = container.publicCloudDatabase
    }
    
    func fetchCompletedQuizzes(submissionId: String) async throws -> Set<String> {
        let predicate = NSPredicate(format: "submissionId == %@", submissionId)
        let query = CKQuery(recordType: "QuizCompletion", predicate: predicate)
        let results = try await database.records(matching: query)
        
        var completed = Set<String>()
        for (_, result) in results.matchResults {
            if case .success(let record) = result,
               let quizId = record["quizId"] as? String {
                completed.insert(quizId)
            }
        }
        return completed
    }
    
    func markComplete(submissionId: String, quizId: String, studentName: String, courseTitle: String) async throws {
        let recordId = "\(submissionId)-\(quizId)"
        let record = CKRecord(recordType: "QuizCompletion", recordID: CKRecord.ID(recordName: recordId))
        
        record["submissionId"] = submissionId
        record["quizId"] = quizId
        record["studentName"] = studentName
        record["courseTitle"] = courseTitle
        record["completedAt"] = Date()
        
        do {
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Already exists, that's fine
        }
    }
}
