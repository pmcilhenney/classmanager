import Foundation
import UIKit

final class ClassManagerAPIClient {
    static let shared = ClassManagerAPIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = ClassManagerAPIClient.defaultBaseURL(),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func health() async throws -> HealthResponse {
        try await send(path: "/health", method: "GET")
    }

    func lookupSession(submissionId: String) async throws -> SessionLookupResponse {
        try await send(
            path: "/session/lookup",
            method: "POST",
            body: SessionLookupRequest(submissionId: submissionId)
        )
    }

    func authenticateInstructor(instructorId: String) async throws -> InstructorAuthService.Instructor {
        let response: InstructorAuthResponse = try await send(
            path: "/instructor/auth",
            method: "POST",
            body: InstructorAuthRequest(instructorId: instructorId)
        )
        return InstructorAuthService.Instructor(
            fullName: response.instructor.fullName,
            email: response.instructor.email,
            oemsId: response.instructor.oemsId
        )
    }

    func scanInstructor(personId: String) async throws -> InstructorScanResponse {
        try await send(
            path: "/instructor/scan",
            method: "POST",
            body: InstructorScanRequest(
                personId: personId,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
        )
    }

    func submitInstructorAttendance(
        personId: String,
        inOut: String,
        course: InstructorCourse,
        attestation: AttendanceAttestation
    ) async throws -> InstructorAttendanceSubmitResponse {
        let response: InstructorAttendanceSubmitResponse = try await send(
            path: "/instructor/attendance/submit",
            method: "POST",
            body: InstructorAttendanceSubmitRequest(
                personId: personId,
                inOut: inOut,
                course: course,
                attestation: attestation,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
        )
        return response
    }

    func fetchInstructorDashboard(
        limit: Int = 100,
        classSessionId: String? = nil,
        courseId: String? = nil
    ) async throws -> InstructorDashboardResponse {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let classSessionId, !classSessionId.isEmpty {
            queryItems.append(URLQueryItem(name: "classSessionId", value: classSessionId))
        }
        if let courseId, !courseId.isEmpty {
            queryItems.append(URLQueryItem(name: "courseId", value: courseId))
        }
        let response: InstructorDashboardResponse = try await send(
            path: "/instructor/dashboard",
            method: "GET",
            queryItems: queryItems
        )
        return response
    }

    func resetStudentProgress(
        personId: String,
        studentId: String,
        classSessionId: String,
        confirmation: String
    ) async throws -> StudentResetResponse {
        try await send(
            path: "/instructor/student/reset",
            method: "POST",
            body: StudentResetRequest(
                personId: personId,
                studentId: studentId,
                classSessionId: classSessionId,
                confirmation: confirmation,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
        )
    }

    @discardableResult
    func markSkillsOpened(
        studentId: String,
        classSessionId: String,
        instructorPersonId: String?
    ) async throws -> SkillsOpenedResponse {
        try await send(
            path: "/skills/opened",
            method: "POST",
            body: SkillsOpenedRequest(
                studentId: studentId,
                classSessionId: classSessionId,
                instructorPersonId: instructorPersonId,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
        )
    }

    @discardableResult
    func registerDeviceToken(_ token: String, apnsEnvironment: String) async throws -> DeviceRegistrationResponse {
        try await send(
            path: "/devices/register",
            method: "POST",
            body: DeviceRegistrationRequest(
                token: token,
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device",
                apnsEnvironment: apnsEnvironment,
                platform: "ios"
            )
        )
    }

    func assignQuiz(
        attendee: RosterAttendee,
        email: String,
        quizId: String
    ) async throws -> QuizAssignResponse {
        let studentId = attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? attendee.submissionId
            : attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines)
        let classSessionId = Self.classSessionId(for: attendee.courseDate ?? attendee.submissionId)
        return try await send(
            path: "/quiz/assign",
            method: "POST",
            body: QuizAssignRequest(
                email: email,
                quizId: quizId,
                firstName: attendee.firstName,
                lastName: attendee.lastName,
                oemsId: attendee.oemsId,
                studentId: studentId,
                classSessionId: classSessionId,
                sourceSubmissionId: attendee.submissionId,
                courseTitle: attendee.courseType,
                courseDate: attendee.courseDate,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
        )
    }

    func fetchQuizReview(
        attendee: RosterAttendee,
        quizId: String,
        email: String,
        questionRange: ClosedRange<Int>? = nil,
        includeInProgress: Bool = false
    ) async throws -> QuizReviewResponse {
        let studentId = attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? attendee.submissionId
            : attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines)
        let classSessionId = Self.classSessionId(for: attendee.courseDate ?? attendee.submissionId)
        var queryItems = [
            URLQueryItem(name: "email", value: email),
            URLQueryItem(name: "studentId", value: studentId),
            URLQueryItem(name: "classSessionId", value: classSessionId),
            URLQueryItem(name: "sourceSubmissionId", value: attendee.submissionId),
            URLQueryItem(name: "deviceId", value: UIDevice.current.identifierForVendor?.uuidString)
        ]
        if includeInProgress {
            queryItems.append(URLQueryItem(name: "includeInProgress", value: "1"))
        }
        if let questionRange {
            queryItems.append(URLQueryItem(name: "questionStart", value: String(questionRange.lowerBound)))
            queryItems.append(URLQueryItem(name: "questionEnd", value: String(questionRange.upperBound)))
        }
        return try await send(
            path: "/quiz/review/\(Self.pathEncode(quizId))",
            method: "GET",
            queryItems: queryItems
        )
    }

    @discardableResult
    func submitAttendance(
        formId: String,
        inOut: String,
        attendee: RosterAttendee,
        fields: [String: String],
        attestation: AttendanceAttestation? = nil
    ) async throws -> AttendanceSubmitResponse {
        let studentId = attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? attendee.submissionId
            : attendee.oemsId.trimmingCharacters(in: .whitespacesAndNewlines)
        let classSessionId = Self.classSessionId(for: attendee.courseDate ?? attendee.submissionId)
        return try await send(
            path: "/attendance/submit",
            method: "POST",
            body: AttendanceSubmitRequest(
                formId: formId,
                inOut: inOut,
                studentId: studentId,
                classSessionId: classSessionId,
                attendee: attendee,
                fields: fields,
                attestation: attestation,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
        )
    }

    func fetchProgress(studentId: String, classSessionId: String) async throws -> RemoteProgress? {
        let response: ProgressEnvelope = try await send(
            path: "/progress/\(Self.pathEncode(classSessionId))/\(Self.pathEncode(studentId))",
            method: "GET"
        )
        return response.progress
    }

    @discardableResult
    func saveProgress(
        _ progress: CKProgress,
        studentId: String,
        classSessionId: String,
        courseDate: String?
    ) async throws -> ProgressSaveResponse {
        let request = ProgressPatchRequest(
            didCheckIn: progress.didCheckIn,
            didCheckOut: progress.didCheckOut,
            didOpenSkills: progress.didOpenSkills,
            didOpenQuiz: progress.didOpenQuiz,
            checkInAt: progress.checkInTime.map(Self.isoString),
            deviceId: UIDevice.current.identifierForVendor?.uuidString,
            oemsId: studentId,
            courseDate: courseDate,
            courseTitle: "Class Session"
        )

        return try await send(
            path: "/progress/\(Self.pathEncode(classSessionId))/\(Self.pathEncode(studentId))",
            method: "PATCH",
            body: request
        )
    }

    private func send<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> T {
        var request = URLRequest(url: makeURL(path: path))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func send<T: Decodable>(
        path: String,
        method: String
    ) async throws -> T {
        var request = URLRequest(url: makeURL(path: path))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    private func send<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        var request = URLRequest(url: makeURL(path: path, queryItems: queryItems))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8)
            throw APIError.httpStatus(http.statusCode, text)
        }
        return try decoder.decode(T.self, from: data)
    }

    private static func defaultBaseURL() -> URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "CLASSMANAGER_API_BASE_URL") as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        return URL(string: "https://classmanagerapp.gcemstrainingacademy.org")!
    }

    private func makeURL(path: String) -> URL {
        makeURL(path: path, queryItems: [])
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = cleanPath
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url!
    }

    private static func pathEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private static func classSessionId(for value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "undated" : clean.replacingOccurrences(of: "/", with: "-")
    }

    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

extension ClassManagerAPIClient {
    struct HealthResponse: Decodable {
        let ok: Bool
        let service: String
        let environment: String
    }

    struct SessionLookupResponse: Decodable {
        let ok: Bool
        let submissionId: String
        let formId: String
        let formType: String
        let attendee: RosterAttendee
        let options: [RegistrationOption]
    }

    struct SessionLookupRequest: Encodable {
        let submissionId: String
    }

    struct InstructorAuthRequest: Encodable {
        let instructorId: String
    }

    struct InstructorAuthResponse: Decodable {
        let ok: Bool
        let instructor: InstructorPayload
    }

    struct DeviceRegistrationRequest: Encodable {
        let token: String
        let deviceId: String
        let apnsEnvironment: String
        let platform: String
    }

    struct DeviceRegistrationResponse: Decodable {
        let ok: Bool
        let updatedAt: String
    }

    struct InstructorPayload: Decodable {
        let fullName: String
        let email: String
        let oemsId: String
    }

    struct InstructorScanRequest: Encodable {
        let personId: String
        let deviceId: String?
    }

    struct InstructorScanResponse: Decodable {
        let ok: Bool
        let instructor: InstructorDashboardInstructor
        let defaultCourse: InstructorCourse?
        let courses: [InstructorCourse]
    }

    struct InstructorDashboardInstructor: Decodable, Identifiable, Hashable {
        let personId: String
        let fullName: String

        var id: String { personId }
    }

    struct InstructorCourse: Codable, Identifiable, Hashable {
        let id: String
        let classSessionId: String
        let courseId: String?
        let title: String
        let date: String
        let displayDate: String?
        let location: String?
        let expectedCount: Int
        let isToday: Bool
    }

    struct InstructorAttendanceSubmitRequest: Encodable {
        let personId: String
        let inOut: String
        let course: InstructorCourse
        let attestation: AttendanceAttestation
        let deviceId: String?
    }

    struct InstructorAttendanceSubmitResponse: Decodable {
        let ok: Bool
        let attendance: InstructorAttendance
        let updatedAt: String
        let warnings: [String]?
    }

    struct InstructorAttendance: Decodable, Hashable {
        let id: String
        let checkedInAt: String
        let checkedOutAt: String?
        let classSessionId: String?
        let courseId: String?
        let courseTitle: String?
        let courseDate: String?
    }

    struct InstructorDashboardResponse: Decodable {
        let ok: Bool
        let generatedAt: String
        let course: InstructorCourse?
        let courses: [InstructorCourse]?
        let students: [DashboardStudent]
        let quizResults: [DashboardQuizResult]
        let finalResults: [DashboardFinalResult]
        let skillsVerifications: [DashboardSkillsVerification]
    }

    struct DashboardStudent: Decodable, Identifiable, Hashable {
        let studentId: String
        let classSessionId: String
        let firstName: String
        let lastName: String
        let email: String?
        let oemsId: String?
        let courseTitle: String
        let courseDate: String?
        let courseId: String?
        let didCheckIn: Bool
        let didCheckOut: Bool
        let didOpenSkills: Bool
        let didOpenQuiz: Bool
        let expected: Bool?
        let checkInAt: String?
        let checkOutAt: String?
        let updatedAt: String?

        var id: String { "\(classSessionId):\(studentId)" }
        var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    struct DashboardQuizResult: Decodable, Identifiable, Hashable {
        let studentId: String?
        let classSessionId: String?
        let quizId: String?
        let resultText: String?
        let scoreText: String?
        let passed: Bool?
        let completedAt: String?
        let updatedAt: String?

        var id: String { [studentId, classSessionId, quizId, completedAt, updatedAt].compactMap { $0 }.joined(separator: ":") }
    }

    struct DashboardFinalResult: Decodable, Identifiable, Hashable {
        let studentId: String?
        let classSessionId: String?
        let quizId: String?
        let quizName: String?
        let responseId: String?
        let scoreText: String?
        let resultText: String?
        let passed: Bool?
        let percentageScore: Double?
        let points: Double?
        let availablePoints: Double?
        let completedAt: String?
        let updatedAt: String?

        var id: String { [studentId, classSessionId, quizId, responseId, completedAt].compactMap { $0 }.joined(separator: ":") }
    }

    struct DashboardSkillsVerification: Decodable, Identifiable, Hashable {
        let studentId: String?
        let classSessionId: String?
        let instructorPersonId: String?
        let openedAt: String?
        let completedAt: String?
        let updatedAt: String?

        var id: String { [studentId, classSessionId, openedAt].compactMap { $0 }.joined(separator: ":") }
    }

    struct StudentResetRequest: Encodable {
        let personId: String
        let studentId: String
        let classSessionId: String
        let confirmation: String
        let deviceId: String?
    }

    struct StudentResetResponse: Decodable {
        let ok: Bool
        let deleted: DeletedStudentProgress
    }

    struct DeletedStudentProgress: Decodable {
        let finalExamResults: Int
        let quizAttempts: Int
        let skillsVerifications: Int
        let progressRows: Int
    }

    struct SkillsOpenedRequest: Encodable {
        let studentId: String
        let classSessionId: String
        let instructorPersonId: String?
        let deviceId: String?
    }

    struct SkillsOpenedResponse: Decodable {
        let ok: Bool
        let updatedAt: String
    }

    struct AttendanceSubmitRequest: Encodable {
        let formId: String
        let inOut: String
        let studentId: String
        let classSessionId: String
        let attendee: RosterAttendee
        let fields: [String: String]
        let attestation: AttendanceAttestation?
        let deviceId: String?
    }

    struct AttendanceSubmitResponse: Decodable {
        let ok: Bool
        let formId: String
        let inOut: String
        let submissionId: String?
        let updatedAt: String
    }

    struct QuizAssignRequest: Encodable {
        let email: String
        let quizId: String
        let firstName: String
        let lastName: String
        let oemsId: String
        let studentId: String
        let classSessionId: String
        let sourceSubmissionId: String
        let courseTitle: String
        let courseDate: String?
        let deviceId: String?
    }

    struct QuizAssignResponse: Decodable {
        let ok: Bool
        let email: String
        let quizId: String
        let launchUrl: URL
        let flexiquizUserId: String?
        let warnings: [String]
    }

    struct QuizReviewResponse: Decodable {
        let ok: Bool
        let quizId: String
        let responseId: String?
        let resultText: String?
        let scoreText: String?
        let passed: Bool?
        let completedAt: String?
        let reportUrl: URL?
        let questions: [QuizReviewQuestion]
        let warnings: [String]
    }

    struct QuizReviewQuestion: Decodable, Identifiable {
        let questionId: String?
        let number: Int
        let prompt: String
        let choices: [String]?
        let studentAnswer: String?
        let correctAnswer: String?
        let isCorrect: Bool?
        let feedback: String?
        let points: String?

        var id: String {
            questionId ?? "\(number)-\(prompt)"
        }

        enum CodingKeys: String, CodingKey {
            case questionId = "id"
            case number
            case prompt
            case choices
            case studentAnswer
            case correctAnswer
            case isCorrect
            case feedback
            case points
        }
    }

    struct ProgressEnvelope: Decodable {
        let classSessionId: String
        let studentId: String
        let progress: RemoteProgress?
    }

    struct RemoteProgress: Decodable {
        let didCheckIn: Bool
        let didCheckOut: Bool
        let didOpenSkills: Bool
        let didOpenQuiz: Bool
        let checkInAt: Date?
        let updatedAt: Date?
        let completedQuizIDs: [String]
        let quizResults: [String: String]
        let finalExamResult: FinalExamResult?

        enum CodingKeys: String, CodingKey {
            case didCheckIn = "did_check_in"
            case didCheckOut = "did_check_out"
            case didOpenSkills = "did_open_skills"
            case didOpenQuiz = "did_open_quiz"
            case checkInAt = "check_in_at"
            case updatedAt = "updated_at"
            case completedQuizIDs = "completed_quiz_ids"
            case quizResults = "quiz_results"
            case finalExamResult = "final_exam_result"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            didCheckIn = try container.decodeFlexibleBool(forKey: .didCheckIn)
            didCheckOut = try container.decodeFlexibleBool(forKey: .didCheckOut)
            didOpenSkills = try container.decodeFlexibleBool(forKey: .didOpenSkills)
            didOpenQuiz = try container.decodeFlexibleBool(forKey: .didOpenQuiz)
            checkInAt = try container.decodeDateIfPresent(forKey: .checkInAt)
            updatedAt = try container.decodeDateIfPresent(forKey: .updatedAt)
            completedQuizIDs = try container.decodeIfPresent([String].self, forKey: .completedQuizIDs) ?? []
            quizResults = try container.decodeIfPresent([String: String].self, forKey: .quizResults) ?? [:]
            finalExamResult = try container.decodeIfPresent(FinalExamResult.self, forKey: .finalExamResult)
        }
    }

    struct FinalExamResult: Codable, Equatable {
        let quizId: String
        let quizName: String?
        let responseId: String?
        let scoreText: String?
        let resultText: String?
        let passed: Bool?
        let completedAt: String?
        let reportUrl: URL?
        let percentageScore: Double?
        let points: Double?
        let availablePoints: Double?
    }

    struct ProgressSaveResponse: Decodable {
        let ok: Bool
        let id: String
        let updatedAt: String
    }

    struct AttendanceLocation: Encodable {
        let latitude: Double?
        let longitude: Double?
        let horizontalAccuracy: Double?
        let address: String?
    }

    struct AttendanceAttestation: Encodable {
        let signatureDataUrl: String
        let signedAt: String
        let attestationText: String
        let location: AttendanceLocation?
    }

    struct ProgressPatchRequest: Encodable {
        let didCheckIn: Bool
        let didCheckOut: Bool
        let didOpenSkills: Bool
        let didOpenQuiz: Bool
        let checkInAt: String?
        let deviceId: String?
        let oemsId: String
        let courseDate: String?
        let courseTitle: String
    }

    struct WorkerErrorResponse: Decodable {
        let error: String
        let warnings: [String]?
    }

    enum APIError: Error, LocalizedError {
        case invalidResponse
        case httpStatus(Int, String?)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The server response was not valid."
            case .httpStatus(let status, let body):
                if let message = Self.message(for: status, body: body) {
                    return message
                }
                return "Server request failed with status \(status)."
            }
        }

        private static func message(for status: Int, body: String?) -> String? {
            guard let body,
                  let data = body.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(WorkerErrorResponse.self, from: data) else {
                return nil
            }
            switch payload.error {
            case "flexiquiz_quiz_not_assigned":
                return "FlexiQuiz did not assign this quiz to the student. Check the quiz assignment/API settings in FlexiQuiz."
            case "flexiquiz_quiz_unavailable":
                return "FlexiQuiz reports this quiz is not available."
            case "flexiquiz_user_not_confirmed":
                return "FlexiQuiz could not find or create the student account."
            case "flexiquiz_not_configured":
                return "FlexiQuiz is not configured on the classmanager server."
            default:
                return payload.error
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
            }
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBool(forKey key: Key) throws -> Bool {
        if let bool = try? decode(Bool.self, forKey: key) {
            return bool
        }
        if let int = try? decode(Int.self, forKey: key) {
            return int != 0
        }
        if let string = try? decode(String.self, forKey: key) {
            return string == "1" || string.lowercased() == "true"
        }
        return false
    }

    func decodeDateIfPresent(forKey key: Key) throws -> Date? {
        guard let string = try? decodeIfPresent(String.self, forKey: key), !string.isEmpty else {
            return nil
        }
        return ISO8601DateFormatter().date(from: string)
    }
}
