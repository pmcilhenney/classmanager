import CloudKit

final class CloudKitManager {
    static let shared = CloudKitManager()
    private init() {}

    private let db = CKContainer.default().privateCloudDatabase
    private let recordType = "QuizProgress"

    func saveProgress(email: String, quizId: String, lastURL: URL?) {
        let key = "\(email.lowercased())|\(quizId)"
        let recordID = CKRecord.ID(recordName: key)
        let r = CKRecord(recordType: recordType, recordID: recordID)
        r["email"] = email as CKRecordValue
        r["quizId"] = quizId as CKRecordValue
        if let u = lastURL { r["lastURL"] = u.absoluteString as CKRecordValue }
        r["updatedAt"] = Date() as CKRecordValue

        db.save(r) { _, _ in }
    }

    func fetchProgress(email: String, quizId: String) async -> URL? {
        let key = "\(email.lowercased())|\(quizId)"
        do {
            let r = try await db.record(for: .init(recordName: key))
            if let s = r["lastURL"] as? String, let u = URL(string: s) { return u }
        } catch { }
        return nil
    }
}
