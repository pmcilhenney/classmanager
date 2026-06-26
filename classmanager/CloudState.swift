//
//  CloudState.swift
//  classmanager
//

import Foundation
import Combine
import CloudKit

// Notification name used to forward system remote notifications into the CloudState store
extension Notification.Name {
    static let ckRemoteNotificationReceived = Notification.Name("CKRemoteNotificationReceived")
}

/// UI flags we sync to CloudKit for a specific attendee on a specific course date.
struct CKProgress: Codable, Equatable {
    var didCheckIn:    Bool = false
    var didCheckOut:   Bool = false
    var didOpenSkills: Bool = false
    var didOpenQuiz:   Bool = false
    var updatedAt:     Date = Date()
    var checkInTime:   Date? = nil    // 🕒 new field
    // Per-quiz completion IDs (persisted to CloudKit as array of strings)
    var completedQuizIDs: [String] = []
    // Map of quizId -> result string (e.g. "Pass", "Fail", "Pass 85%")
    var quizResults: [String: String] = [:]
    // Map of quizId -> review token/id (extracted from results page) so we can open review later
    var quizReviewIds: [String: String] = [:]
}

/// Observable store that reads/writes a single CloudKit record keyed by (oemsId, courseDate).
/// - Uses CloudKit if available for the container.
/// - Falls back to local UserDefaults if CK is unavailable/misconfigured, so state persists anyway.
final class CKProgressStore: ObservableObject {

    // Notification observer token for remote pushes
    private var remoteObserver: Any?

    init() {
        // Listen for forwarded remote notifications and fetch/merge when they arrive
        remoteObserver = NotificationCenter.default.addObserver(forName: .ckRemoteNotificationReceived, object: nil, queue: .main) { [weak self] note in
            guard let userInfo = note.userInfo else { return }
            Task { [weak self] in
                await self?.handleRemoteNotification(userInfo)
            }
        }
    }

    deinit {
        if let obs = remoteObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Config
    private static let containerID = "iCloud.icloud.org.gcems.classmanager"
    private var container: CKContainer { CKContainer(identifier: Self.containerID) }
    private var dbPublic: CKDatabase { container.publicCloudDatabase }
    private var dbPrivate: CKDatabase { container.privateCloudDatabase }

    // MARK: - Published state
    @Published private(set) var progress = CKProgress()

    // Identity for current record
    private var oemsId: String = ""
    private var courseDate: String? = nil
    private let apiClient = ClassManagerAPIClient.shared

    // CK runtime
    private var currentRecordID: CKRecord.ID?
    private var currentRecord: CKRecord?
    private var iCloudOK = false   // flips true once container/account is healthy
    // Serializer to ensure only one save sequence runs at a time (prevents oplock churn)
    private actor SaveSerializer {
        func perform<T>(_ op: @escaping () async -> T) async -> T {
            return await op()
        }
    }
    private let saveSerializer = SaveSerializer()

    // MARK: - Local fallback
    private func localKey(oemsId: String, date: String) -> String {
        "CKProgress:\(oemsId):\(date)"
    }

    private func saveLocal(_ p: CKProgress) {
        guard let cd = courseDate, !cd.isEmpty else { return }
        let key = localKey(oemsId: oemsId, date: cd)
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadLocal() -> CKProgress? {
        guard let cd = courseDate, !cd.isEmpty else { return nil }
        let key = localKey(oemsId: oemsId, date: cd)
        if let data = UserDefaults.standard.data(forKey: key),
           let p = try? JSONDecoder().decode(CKProgress.self, from: data) {
            return p
        }
        return nil
    }

    // MARK: - Public API

    /// Load (or create shell) progress for this attendee/date. Safe to call repeatedly.
    @MainActor
    func load(oemsId: String, courseDate: String?) async {
        self.oemsId = oemsId
        self.courseDate = courseDate

        // reset session state
        self.progress = CKProgress()
        self.currentRecord = nil
        self.currentRecordID = nil
        self.iCloudOK = false

        guard let cd = courseDate, !cd.isEmpty else {
            // No date → local only
            if let local = loadLocal() { self.progress = local }
            return
        }

        // Show local immediately if present
        if let local = loadLocal() {
            self.progress = local
        }

        await fetchLatestFromWorker()
    }

    /// Create a CKQuerySubscription (silent push) scoped to this `oemsId` + `courseDate` so
    /// records created/updated on the server notify the app. Safe to call repeatedly.
    private func ensureSubscriptionIfNeeded() async {
        guard iCloudOK, let cd = courseDate, !cd.isEmpty, !oemsId.isEmpty else { return }

        let subscriptionID = "ProgressSub:\(oemsId):\(cd.replacingOccurrences(of: "/", with: "-"))"
        let predicate = NSPredicate(format: "oemsId == %@ AND courseDate == %@", oemsId, cd)

        func createSubscription(in db: CKDatabase) async {
            // Check existing subscriptions first
            let exists: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                db.fetchAllSubscriptions { subs, err in
                    #if DEBUG
                    if let err { print("[CK] fetch subs err: \(err.localizedDescription)") }
                    #endif
                    if let subs = subs {
                        cont.resume(returning: subs.contains { $0.subscriptionID == subscriptionID })
                    } else {
                        cont.resume(returning: false)
                    }
                }
            }

            if exists { return }

            let sub = CKQuerySubscription(recordType: "Progress", predicate: predicate, subscriptionID: subscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate])
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true // silent push
            sub.notificationInfo = info

            _ = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                db.save(sub) { saved, err in
                    #if DEBUG
                    if let err { print("[CK] save subscription err: \(err.localizedDescription)") }
                    else { print("[CK] subscription saved: \(subscriptionID)") }
                    #endif
                    cont.resume(returning: (saved != nil))
                }
            }
        }

        // Attempt to create subscription in both public and private DBs
        await createSubscription(in: dbPublic)
        await createSubscription(in: dbPrivate)
    }

    /// Fetch the latest server-side record (public then private), merge into local progress, and update local cache.
    @MainActor
    func fetchLatestAndMerge() async {
        await fetchLatestFromWorker()

        guard iCloudOK, let cd = courseDate, !cd.isEmpty else { return }
        let rid = currentRecordID ?? recordID(oemsId: oemsId, courseDate: cd)
        // Try public then private
        var fetched: CKRecord? = await fetchRecord(id: rid, from: dbPublic)
        if fetched == nil { fetched = await fetchRecord(id: rid, from: dbPrivate) }

        if let serverRec = fetched {
            self.currentRecord = serverRec
            if let serverProgress = decode(serverRec) {
                // Merge server and local using similar rules: if local is newer, push; else adopt server
                if let local = loadLocal(), local.updatedAt > serverProgress.updatedAt {
                    self.progress = local
                    Task { await self.saveToCloud(local) }
                } else {
                    self.progress = serverProgress
                    saveLocal(serverProgress)
                }
            }
        }
    }

    /// Called by AppDelegate/Scene when a CK notification arrives. We don't rely on payload parsing; just fetch latest.
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        Task { await self.fetchLatestFromWorker() }
    }

    /// Markers
    @MainActor func markCheckIn() {
        mutate {
            $0.didCheckIn = true
            $0.checkInTime = Date()     // ⏱ record check-in moment
        }
    }
    /// Mark a specific quiz as completed and persist to cloud/local
    @MainActor func markQuizComplete(_ quizId: String) {
        mutate { p in
            if !p.completedQuizIDs.contains(quizId) {
                p.completedQuizIDs.append(quizId)
            }
        }
    }
    @MainActor func markQuizResult(_ quizId: String, result: String) {
        mutate { p in
            p.quizResults[quizId] = result
            if !p.completedQuizIDs.contains(quizId) {
                p.completedQuizIDs.append(quizId)
            }
        }
    }

    /// Mark a quiz result locally and attempt a forced save that ensures the local
    /// value for this quizId is applied to the server record (useful when a retake
    /// should overwrite an earlier server value). This performs a targeted fetch->merge
    /// and saves the merged record, preferring the local quiz result for the given quizId.
    @MainActor func markQuizResultAndForceSave(_ quizId: String, result: String) {
        // Update local state first (and persist locally)
        mutate { p in
            p.quizResults[quizId] = result
            if !p.completedQuizIDs.contains(quizId) {
                p.completedQuizIDs.append(quizId)
            }
        }

        // Fire-and-forget the forced save so callers don't await
        Task { await self.forceSaveQuizResult(quizId: quizId) }
    }

    /// Perform a focused fetch/merge/save that guarantees the local quizResults[quizId]
    /// value is encoded into the saved record. This helps in cases where optimistic
    /// lock conflicts keep an older server value present.
    private func forceSaveQuizResult(quizId: String) async {
        await saveToWorker(progress)
    }
    @MainActor func markQuizReviewId(_ quizId: String, reviewId: String) {
        mutate { p in
            p.quizReviewIds[quizId] = reviewId
        }
    }
    @MainActor func markSkills()   { mutate { $0.didOpenSkills = true } }
    @MainActor func markCheckOut() { mutate { $0.didCheckOut = true } }
    /// Call when the quiz is actually visible
    @MainActor func markQuiz()     { mutate { $0.didOpenQuiz    = true } }

    // MARK: - Internals

    private func recordID(oemsId: String, courseDate: String) -> CKRecord.ID {
        let dateKey = courseDate.replacingOccurrences(of: "/", with: "-")
        return CKRecord.ID(recordName: "Progress:\(oemsId):\(dateKey)")
    }

    @MainActor
    private func mutate(_ change: (inout CKProgress)->Void) {
        var next = progress
        change(&next)
        next.updatedAt = Date()
        progress = next
        // Always write locally
        saveLocal(next)
        Task { await self.saveToWorker(next) }
    }

    @MainActor
    private func fetchLatestFromWorker() async {
        guard let cd = courseDate, !cd.isEmpty, !oemsId.isEmpty else { return }

        do {
            guard let remote = try await apiClient.fetchProgress(
                studentId: workerStudentId,
                classSessionId: workerClassSessionId
            ) else { return }

            var merged = progress
            merged.didCheckIn = merged.didCheckIn || remote.didCheckIn
            merged.didCheckOut = merged.didCheckOut || remote.didCheckOut
            merged.didOpenSkills = merged.didOpenSkills || remote.didOpenSkills
            merged.didOpenQuiz = merged.didOpenQuiz || remote.didOpenQuiz
            merged.checkInTime = merged.checkInTime ?? remote.checkInAt
            merged.completedQuizIDs = Array(Set(merged.completedQuizIDs).union(remote.completedQuizIDs))
            for (quizId, result) in remote.quizResults {
                merged.quizResults[quizId] = result
            }
            if let remoteUpdatedAt = remote.updatedAt {
                merged.updatedAt = max(merged.updatedAt, remoteUpdatedAt)
            }

            if merged != progress {
                progress = merged
                saveLocal(merged)
            }
        } catch {
            #if DEBUG
            print("[ClassManagerAPI] fetch progress failed: \(error)")
            #endif
        }
    }

    private func saveToWorker(_ p: CKProgress) async {
        guard let cd = courseDate, !cd.isEmpty, !oemsId.isEmpty else { return }

        do {
            _ = try await apiClient.saveProgress(
                p,
                studentId: workerStudentId,
                classSessionId: workerClassSessionId,
                courseDate: cd
            )
        } catch {
            #if DEBUG
            print("[ClassManagerAPI] save progress failed: \(error)")
            #endif
        }
    }

    private var workerStudentId: String {
        oemsId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var workerClassSessionId: String {
        let raw = (courseDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "undated" : raw.replacingOccurrences(of: "/", with: "-")
    }

    // MARK: Cloud helpers

    /// True if: iCloud account available + can fetch user record id (container reachable).
    private func checkAccountAndContainer() async -> Bool {
        let accountOK: Bool = await withCheckedContinuation { cont in
            container.accountStatus { status, _ in
                cont.resume(returning: status == .available)
            }
        }
        guard accountOK else {
            #if DEBUG
            print("[CK] account not available")
            #endif
            return false
        }
        // Lightweight reachability: fetch user record id
        let userOK: Bool = await withCheckedContinuation { cont in
            container.fetchUserRecordID { id, error in
                if let error = error {
                    #if DEBUG
                    print("[CK] fetchUserRecordID error: \(error.localizedDescription)")
                    #endif
                }
                cont.resume(returning: (id != nil))
            }
        }
        return userOK
    }

    private func fetchRecord(id: CKRecord.ID, from db: CKDatabase) async -> CKRecord? {
        await withCheckedContinuation { cont in
            db.fetch(withRecordID: id) { rec, err in
                #if DEBUG
                if let err = err as? CKError, err.code != .unknownItem {
                    print("[CK] fetch err: \(err.localizedDescription)")
                } else if let err, (err as? CKError) == nil {
                    print("[CK] fetch err: \(err.localizedDescription)")
                }
                #endif
                cont.resume(returning: rec)
            }
        }
    }

    private func saveToCloud(_ p: CKProgress) async {
        guard iCloudOK,
              let cd = courseDate, !cd.isEmpty
        else { return }

        // Serialize all save sequences through the saveSerializer actor so we don't run overlapping
        // fetch->merge->save flows which produce optimistic-lock conflicts on the server.
        _ = await saveSerializer.perform { [weak self] () async -> Bool in
            guard let self = self else { return false }
            let rid = self.currentRecordID ?? self.recordID(oemsId: self.oemsId, courseDate: cd)
            self.currentRecordID = rid
            let rec = self.currentRecord ?? CKRecord(recordType: "Progress", recordID: rid)
            self.encode(p, into: rec)

            #if DEBUG
            print("[CK] saveToCloud: starting save sequence for recordName=\(rec.recordID.recordName)")
            #endif
            // Try public, then private
            if await self.save(rec, to: self.dbPublic) == false {
                #if DEBUG
                print("[CK] saveToCloud: public DB save failed; trying private DB")
                #endif
                _ = await self.save(rec, to: self.dbPrivate)
            }
            #if DEBUG
            print("[CK] saveToCloud: finished save sequence for recordName=\(rec.recordID.recordName)")
            #endif
            return true
        }
    }

    private func save(_ rec: CKRecord, to db: CKDatabase) async -> Bool {
        // Implement fetch -> merge -> save retry loop to handle optimistic-lock conflicts.
        let maxAttempts = 3
        var attempt = 0
        var toSave = rec

        while attempt < maxAttempts {
            attempt += 1

            #if DEBUG
            let dbName = (db === dbPublic) ? "public" : "private"
            print("[CK] save: attempt \(attempt) to save recordName=\(toSave.recordID.recordName) to DB=\(dbName)")
            #endif

            // Try a simple db.save and capture server error if any
            let (savedRec, ckError): (CKRecord?, CKError?) = await withCheckedContinuation { (cont: CheckedContinuation<(CKRecord?, CKError?), Never>) in
                db.save(toSave) { saved, err in
                    #if DEBUG
                    if let err { print("[CK] save err (attempt \(attempt)): \(err.localizedDescription)") }
                    #endif
                    cont.resume(returning: (saved, err as? CKError))
                }
            }

            if let saved = savedRec {
                #if DEBUG
                print("[CK] save: successful save on attempt \(attempt) to DB")
                #endif
                self.currentRecord = saved
                return true
            }

            // If we have a CKError, handle conflict cases by fetching the authoritative server record
            if let ckErr = ckError {
                switch ckErr.code {
                case .serverRecordChanged:
                    #if DEBUG
                    print("[CK] serverRecordChanged — fetching latest server record and merging (attempt \(attempt))")
                    #endif
                    // Prefer the serverRecord provided by CKError if present; otherwise fetch explicitly
                    if let serverRec = ckErr.serverRecord {
                        toSave = merge(local: toSave, server: serverRec)
                    } else if let fetched = await fetchRecord(id: toSave.recordID, from: db) {
                        toSave = merge(local: toSave, server: fetched)
                    } else {
                        #if DEBUG
                        print("[CK] serverRecordChanged but could not fetch server record — will retry by overwriting")
                        #endif
                        // Fall back to keeping toSave as-is and retry
                    }

                case .unknownItem:
                    #if DEBUG
                    print("[CK] unknownItem — server missing record, recreating and retrying (attempt \(attempt))")
                    #endif
                    // Recreate a fresh record with the same ID and copy fields
                    let newRec = CKRecord(recordType: toSave.recordType, recordID: toSave.recordID)
                    for key in toSave.allKeys() {
                        newRec[key] = toSave[key]
                    }
                    toSave = newRec

                default:
                    #if DEBUG
                    print("[CK] unhandled CKError.code=\(ckErr.code) — \(ckErr.localizedDescription)")
                    #endif
                    // Unrecoverable or unexpected error — stop retrying
                    return false
                }
            } else {
                // Non-CKError / unknown error — stop retrying
                return false
            }

            // Backoff before retrying (exponential-ish)
            let backoffSeconds = 0.25 * pow(2.0, Double(attempt - 1))
            let backoff = UInt64(backoffSeconds * Double(NSEC_PER_SEC))
            try? await Task.sleep(nanoseconds: backoff)
        }

        // All attempts exhausted
        return false
    }

    /// Merge policy for server vs local CKRecord. Local values take precedence for
    /// quiz-specific keys; booleans are combined (true if either is true); arrays are unioned.
    private func merge(local: CKRecord, server: CKRecord) -> CKRecord {
        // Decode both records into CKProgress to perform a logical merge, then re-encode
        if let serverProgress = decode(server) {
            var merged = serverProgress
            if let localProgress = decode(local) {
                // Booleans: either side true -> true
                merged.didCheckIn = serverProgress.didCheckIn || localProgress.didCheckIn
                merged.didCheckOut = serverProgress.didCheckOut || localProgress.didCheckOut
                merged.didOpenSkills = serverProgress.didOpenSkills || localProgress.didOpenSkills
                merged.didOpenQuiz = serverProgress.didOpenQuiz || localProgress.didOpenQuiz

                // updatedAt: take the most recent
                merged.updatedAt = max(serverProgress.updatedAt, localProgress.updatedAt)

                // checkInTime: prefer local if present
                merged.checkInTime = localProgress.checkInTime ?? serverProgress.checkInTime

                // completedQuizIDs: union
                let union = Set(serverProgress.completedQuizIDs).union(localProgress.completedQuizIDs)
                merged.completedQuizIDs = Array(union)

                // quizResults: overlay local onto server (local wins)
                var combinedResults = serverProgress.quizResults
                for (k, v) in localProgress.quizResults { combinedResults[k] = v }
                merged.quizResults = combinedResults

                // quizReviewIds: overlay local onto server
                var combinedReviews = serverProgress.quizReviewIds
                for (k, v) in localProgress.quizReviewIds { combinedReviews[k] = v }
                merged.quizReviewIds = combinedReviews
            }

            // Create a new record based on server's recordID to preserve server metadata
            let out = CKRecord(recordType: server.recordType, recordID: server.recordID)
            // Encode merged into out
            encode(merged, into: out)
            return out
        }

        // If decoding failed, fall back to local
        return local
    }

    // MARK: Encode/Decode

    private func encode(_ p: CKProgress, into rec: CKRecord) {
        rec["didCheckIn"]    = p.didCheckIn as CKRecordValue
        rec["didCheckOut"]   = p.didCheckOut as CKRecordValue
        rec["didOpenSkills"] = p.didOpenSkills as CKRecordValue
        rec["didOpenQuiz"]   = p.didOpenQuiz as CKRecordValue
        rec["updatedAt"]     = p.updatedAt as CKRecordValue
        // Persist completed quiz IDs as an array of strings
        if !p.completedQuizIDs.isEmpty {
            rec["completedQuizIDs"] = p.completedQuizIDs as CKRecordValue
        }
        if !p.quizResults.isEmpty {
            if let data = try? JSONEncoder().encode(p.quizResults), let json = String(data: data, encoding: .utf8) {
                rec["quizResultsJSON"] = json as CKRecordValue
            }
        }
        if !p.quizReviewIds.isEmpty {
            if let data = try? JSONEncoder().encode(p.quizReviewIds), let json = String(data: data, encoding: .utf8) {
                rec["quizReviewIdsJSON"] = json as CKRecordValue
            }
        }
        // Identity (handy for dashboards/queries)
        if !oemsId.isEmpty                 { rec["oemsId"] = oemsId as CKRecordValue }
        if let d = courseDate, !d.isEmpty  { rec["courseDate"] = d as CKRecordValue }
        if let t = p.checkInTime { rec["checkInTime"] = t as CKRecordValue }
    }

    private func decode(_ rec: CKRecord) -> CKProgress? {
        var p = CKProgress()
        p.didCheckIn    = rec["didCheckIn"]    as? Bool ?? false
        p.didCheckOut   = rec["didCheckOut"]   as? Bool ?? false
        p.didOpenSkills = rec["didOpenSkills"] as? Bool ?? false
        p.didOpenQuiz   = rec["didOpenQuiz"]   as? Bool ?? false
        p.updatedAt     = rec["updatedAt"]     as? Date ?? Date()
        p.checkInTime = rec["checkInTime"] as? Date
        if let arr = rec["completedQuizIDs"] as? [String] {
            p.completedQuizIDs = arr
        }
        if let json = rec["quizResultsJSON"] as? String, let data = json.data(using: .utf8), let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            p.quizResults = dict
        }
        if let json = rec["quizReviewIdsJSON"] as? String, let data = json.data(using: .utf8), let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            p.quizReviewIds = dict
        }
        return p
    }
}
