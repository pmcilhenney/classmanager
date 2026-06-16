import Foundation

// MARK: - JotForm API client (single source of truth)

final class JotFormClient {

    // MARK: Namespaced DTOs to avoid collisions
    struct TARecord {
        let q3_firstName:  String
        let q5_lastName:   String
        let q6_oemsId:     String
        let q7_courseId:   String?     // optional
        let q8_courseType: String
        let q12_inOut:     String      // "Check-In" / "Check-Out"
        let q10_date:      String      // "MM/dd/yyyy HH:mm"
        let q16_courseDate:String?     // optional "MM/dd/yyyy"
        let q22_dob:       String?     // optional
    }

    // MARK: - Instance

    let apiKey: String
    private let session: URLSession = .shared
    private let base = "https://api.jotform.com"

    init(apiKey: String) {
        self.apiKey = apiKey
    }
}

// MARK: - Course ID lookup (by date + fuzzy name)
extension JotFormClient {

    /// Look up Course ID in the lookup form (251715517762056) by:
    ///  - exact date match (MM/DD/YYYY), and
    ///  - fuzzy name match (e.g., "EMT Refresher A" ~= "Refresher A")
    ///
    /// Assumes the lookup form uses:
    ///   Q3  = Course Name
    ///   Q10 = Date (may be "MM/DD/YYYY" or "YYYY-MM-DD HH:mm")
    ///   Q5  = Course ID
    ///
    /// - Returns: course ID string if found, else nil
    func findCourseIdByDateAndNameFuzzy(
        lookupFormId: String,
        targetDateMMDDYYYY: String,
        targetName: String
    ) async throws -> String? {

        // Pull a big page; bump if you store many rows
        let urlStr = "\(base)/form/\(lookupFormId)/submissions?apiKey=\(apiKey)&limit=2000"
        guard let url = URL(string: urlStr) else { return nil }

        let (data, resp) = try await session.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = root["content"] as? [[String: Any]]
        else { return nil }

        // Normalize inputs
        let wantDate = Self.normalizeDateToMMDDYYYY(targetDateMMDDYYYY)
        let wantName = Self.canonicalName(targetName)

        for sub in content {
            guard
                let bag = sub["content"] as? [String: Any],
                let answers = bag["answers"] as? [String: Any],
                let cid = Self.answerString(answers, qid: "5"), !cid.isEmpty
            else { continue }

            let nameRaw = Self.answerString(answers, qid: "3") ?? ""
            let dateRaw = Self.answerString(answers, qid: "10") ?? ""

            let haveDate = Self.normalizeDateToMMDDYYYY(dateRaw)
            let haveName = Self.canonicalName(nameRaw)

            // Strong filter by date first
            guard haveDate == wantDate else { continue }

            // Fuzzy match by name (token-based; tolerates "EMT", "Course", etc.)
            if Self.fuzzyNamesMatch(a: haveName, b: wantName) {
                return cid
            }
        }
        return nil
    }

    // MARK: - Local helpers (duplicated here to avoid access-level issues)
    private static func answerString(_ answers: [String: Any], qid: String) -> String? {
        guard let a = answers[qid] as? [String: Any] else { return nil }
        if let s = a["answer"] as? String { return s }
        if let dict = a["answer"] as? [String: Any], let s = dict["date"] as? String { return s } // date controls
        if let arr = a["answer"] as? [String] { return arr.joined(separator: ", ") }
        if let t = a["text"] as? String { return t }
        return nil
    }

    /// Accepts "MM/DD/YYYY", "YYYY-MM-DD HH:mm", "YYYY-MM-DD", etc. -> "MM/DD/YYYY"
    private static func normalizeDateToMMDDYYYY(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Already MM/DD/YYYY?
        if s.range(of: #"^\d{2}/\d{2}/\d{4}$"#, options: .regularExpression) != nil {
            return s
        }
        // "YYYY-MM-DD HH:mm" or "YYYY-MM-DD"
        if let datePart = s.split(separator: " ").first {
            let ymd = String(datePart)
            if ymd.count == 10, ymd.contains("-") {
                let comps = ymd.split(separator: "-")
                if comps.count == 3 {
                    let y = comps[0], m = comps[1], d = comps[2]
                    return "\(m)/\(d)/\(y)"
                }
            }
        }
        return s // fallback
    }

    /// Canonicalize names for fuzzy matching.
    /// - Lowercase
    /// - Remove non-alphanumerics
    /// - Drop common filler tokens: emt, course, class, training, session
    /// - Keep the letter A/B/C signal
    private static func canonicalName(_ s: String) -> String {
        let lower = s.lowercased()
        let cleaned = lower.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        let tokens = cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { !["emt", "course", "class", "training", "session"].contains($0) }

        // Rejoin to a single comparable string
        return tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Token-overlap fuzzy match; requires last significant token (often "a"/"b"/"c" or "refresher") to overlap.
    private static func fuzzyNamesMatch(a: String, b: String) -> Bool {
        if a == b { return true }
        let ta = Set(a.split(separator: " ").map(String.init))
        let tb = Set(b.split(separator: " ").map(String.init))
        // Require non-empty overlap and that at least one of ["refresher","a","b","c"] matches
        let overlap = ta.intersection(tb)
        if overlap.isEmpty { return false }
        if overlap.contains("refresher") { return true }
        // If "refresher" was stripped or missing, fall back to A/B/C marker
        let letters = ["a","b","c"]
        return !letters.filter { ta.contains($0) && tb.contains($0) }.isEmpty
    }
}

// MARK: - Public helpers needed by views

extension JotFormClient {

    /// Public wrapper so views can fetch the raw submission JSON.
    public func rawSubmissionObject(submissionId: String) async throws -> [String: Any] {
        try await rawSubmission(submissionId: submissionId)
    }

    /// Public wrapper for getting either `text` or `answer` for a field.
    public func textOrAnswerPublic(_ answers: [String: Any], qid: String) -> String? {
        textOrAnswer(answers, qid: qid)
    }

    /// Static helper for Time & Attendance Q10 format "MM/dd/yyyy HH:mm"
    public static func nowForQ10() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "MM/dd/yyyy HH:mm"
        return df.string(from: Date())
    }
}

// MARK: - PDF upload for Q23

extension JotFormClient {

    /// Submit attendance with a PDF attached to QID 23 (control_fileupload).
    /// `fields` are plain QID -> value ("3" -> "First name", etc.)
    func postTimeAttendanceWithPDF(
        formId: String,
        fields: [String: String],
        pdfData: Data,
        pdfFileName: String = "attendance.pdf"
    ) async throws {
        guard let url = URL(string: "\(base)/form/\(formId)/submissions") else {
            throw NSError(domain: "JotFormClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad URL for PDF upload"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // JotForm accepts API key via header "APIKEY" or ?apiKey=...
        request.setValue(apiKey, forHTTPHeaderField: "APIKEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        func appendFileField(name: String, filename: String, mimeType: String, fileData: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        // 1) Normal QID fields as submission[QID]
        for (qid, value) in fields {
            let fieldName = "submission[\(qid)]"
            appendField(name: fieldName, value: value)
        }

        // 2) PDF to upload field Q23
        // IMPORTANT: use [23][0] for a multi-file control_fileupload
        appendFileField(
            name: "submission[23][0]",
            filename: pdfFileName,
            mimeType: "application/pdf",
            fileData: pdfData
        )

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "JotFormClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }

        #if DEBUG
        print("[JotFormClient] upload PDF status \(http.statusCode)")
        if let s = String(data: data, encoding: .utf8) {
            print("[JotFormClient] response: \(s)")
        }
        #endif

        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "JotFormClient", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Upload failed (\(http.statusCode)): \(msg)"])
        }
    }
}

// MARK: - Time & Attendance submit

extension JotFormClient {

    @discardableResult
    func postTimeAttendance(formId: String, payload: JotFormClient.TARecord) async throws -> String {
        try await postTimeAttendance(formId: formId, fields: payload.asFields)
    }

    @discardableResult
    func postTimeAttendance(formId: String, fields: [String:String]) async throws -> String {
        guard let url = URL(string: "\(base)/form/\(formId)/submissions?apiKey=\(apiKey)") else {
            throw jfError("Bad URL for postTimeAttendance")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let body = fields.map { "submission[\($0.key)]=\(JotFormClient.encode($0.value))" }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw jfError("No HTTP response") }
        guard http.statusCode < 300 else {
            let msg = String(data: data, encoding: .utf8) ?? "(no body)"
            throw jfError("HTTP \(http.statusCode): \(msg)")
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
           let content = obj["content"] as? [String:Any],
           let sid = content["submissionID"] as? String {
            return sid
        }
        return ""
    }

    /// PUT fields back to an existing roster submission (by ID).
    public func updateRosterSubmission(submissionId: String, updates: [String:String]) async throws {
        guard let url = URL(string: "\(base)/submission/\(submissionId)") else { throw jfError("Bad URL for updateRosterSubmission") }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = updates.map { "submission[\($0.key)]=\(JotFormClient.encode($0.value))" }
            .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (_, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw jfError("Invalid response on update") }
    }
}

// MARK: - Refresher roster fetch (by bare submission ID)

extension JotFormClient {
    func fetchRefresherSubmission(submissionId: String) async throws -> RosterAttendee {
        let obj = try await rawSubmission(submissionId: submissionId)
        guard
            let content = obj["content"] as? [String: Any],
            let answers = content["answers"] as? [String: Any]
        else { throw jfError("Malformed submission payload") }

        return parseRefresherAttendee(submissionId: submissionId, answers: answers)
    }

    /// Fetch a registration-style submission (product-based) and convert to `Attendee`.
    /// This understands the newer schema produced by the registration form and uses
    /// `JotFormSubmissionParser` / `StudentParser` to extract fields.
    func fetchRegistrationAsAttendee(submissionId: String) async throws -> RosterAttendee {
        let obj = try await rawSubmission(submissionId: submissionId)

        // Marshal back to Data so the existing Student parser can be reused.
        let data = try JSONSerialization.data(withJSONObject: obj)
        guard let student = StudentParser().parseStudent(from: data) else {
            throw jfError("Could not parse registration submission")
        }

        // Map Student -> Attendee
        let dob: String? = {
            if let p = student.dobPretty, !p.isEmpty { return p }
            if let iso = student.dobISO, !iso.isEmpty { return JotFormClient.normalizeDateToMMDDYYYY(iso) }
            return nil
        }()

        #if DEBUG
        print("[JotFormClient] Student courseImageURL: \(student.courseImageURL ?? "nil")")
        print("[JotFormClient] Student courseId: \(student.courseId ?? "nil")")
        print("[JotFormClient] Student ceuValue: \(student.ceuValue ?? "nil")")
        print("[JotFormClient] Student courseLocation: \(student.courseLocation ?? "nil")")
        #endif

        return RosterAttendee(
            submissionId: student.submissionId ?? submissionId,
            firstName: student.firstName,
            lastName: student.lastName,
            email: student.email,
            oemsId: student.njOemsId ?? "",
            courseType: student.courseName ?? "",
            courseDate: student.courseDate,
            courseId: student.courseId,
            ceuValue: student.ceuValue,
            productCategories: student.connectedCategories,
            dob: dob,
            courseImageURL: student.courseImageURL,
            courseLocation: student.courseLocation
        )
    }
}

// MARK: - Private plumbing

private extension JotFormClient {

    func rawSubmission(submissionId: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(base)/submission/\(submissionId)?apiKey=\(apiKey)") else {
            throw jfError("Bad URL for rawSubmission")
        }
        let (data, resp) = try await session.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw jfError("Non-200 response") }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw jfError("Bad JSON")
        }
        return obj
    }

    func submissionsForForm(formId: String, limit: Int) async throws -> [[String: Any]] {
        guard let url = URL(string: "\(base)/form/\(formId)/submissions?apiKey=\(apiKey)&limit=\(limit)") else {
            throw jfError("Bad URL for submissionsForForm")
        }
        let (data, resp) = try await session.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw jfError("Non-200") }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]]
        else { throw jfError("No content array") }
        return content
    }

    func parseRefresherAttendee(submissionId: String, answers: [String: Any]) -> RosterAttendee {
        func s(_ qid: String) -> String { answerString(answers, qid: qid) }

        let first = s("32")
        let last  = s("33")
        let email = s("4")
        let oems  = s("6")

        var courseType = s("96") // checkbox label; else infer from appt fields
        if courseType.isEmpty {
            if !s("60").isEmpty { courseType = "Refresher A" }
            else if !s("74").isEmpty { courseType = "Refresher B" }
            else if !s("77").isEmpty { courseType = "Refresher C" }
        }

        let dateA = s("60"), dateB = s("74"), dateC = s("77")
        let coarseDate: String? = {
            if !dateA.isEmpty { return extractDatePart(dateA) }
            if !dateB.isEmpty { return extractDatePart(dateB) }
            if !dateC.isEmpty { return extractDatePart(dateC) }
            return nil
        }()

        return RosterAttendee(
            submissionId: submissionId,
            firstName: first,
            lastName: last,
            email: email,
            oemsId: oems,
            courseType: courseType,
            courseDate: coarseDate,
            courseId: nil,
            ceuValue: nil,
            productCategories: nil,
            dob: nil,
            courseImageURL: nil,
            courseLocation: nil
        )
    }

    func answerString(_ answers: [String: Any], qid: String) -> String {
        guard let a = answers[qid] as? [String: Any] else { return "" }
        if let s = a["answer"] as? String { return s }
        if let arr = a["answer"] as? [String] { return arr.joined(separator: ", ") }
        if let t = a["text"] as? String { return t }
        return ""
    }

    func textOrAnswer(_ answers: [String: Any], qid: String) -> String? {
        guard let a = answers[qid] as? [String: Any] else { return nil }
        if let t = a["text"] as? String, !t.isEmpty { return t }
        if let s = a["answer"] as? String, !s.isEmpty { return s }
        return nil
    }

    func extractDatePart(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sp = trimmed.firstIndex(of: " ") { return String(trimmed[..<sp]) }
        return trimmed
    }

    func jfError(_ msg: String) -> NSError {
        NSError(domain: "JotFormClient", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}

// MARK: - TARecord -> fields

private extension JotFormClient.TARecord {
    var asFields: [String:String] {
        var f: [String:String] = [
            "3":  q3_firstName,
            "5":  q5_lastName,
            "6":  q6_oemsId,
            "8":  q8_courseType,
            "12": q12_inOut,
            "10": q10_date
        ]
        if let v = q7_courseId,    !v.isEmpty { f["7"]  = v }
        if let v = q16_courseDate, !v.isEmpty { f["16"] = v }
        if let v = q22_dob,        !v.isEmpty { f["22"] = v }
        return f
    }
}
