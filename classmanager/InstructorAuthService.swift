//
//  InstructorAuthService.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/14/25.
//
//
//  InstructorAuthService.swift
//  classmanager
//

import Foundation

/// Auths an instructor against a JotForm roster by 6-digit NJ OEMS ID.
/// Reads API key from Info.plist key: "jotform_api".
struct InstructorAuthService {

    // MARK: - Public model

    struct Instructor {
        let fullName: String
        let email: String
        let oemsId: String   // the 6-digit instructor ID from QID 15
    }

    // MARK: - Errors

    enum AuthError: Error, LocalizedError {
        case missingAPIKey
        case badURL
        case transport(Error)
        case badResponse(code: Int)
        case decodeFailed
        case invalidInput
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing JotForm API key. Please contact an administrator."
            case .badURL:
                return "Invalid JotForm URL."
            case .transport(let err):
                return "Network error: \(err.localizedDescription)"
            case .badResponse(let code):
                return "JotForm HTTP \(code)."
            case .decodeFailed:
                return "Could not parse JotForm response."
            case .invalidInput:
                return "Please enter your 6-digit Instructor ID."
            case .notAuthorized:
                return "Instructor ID not found. Please check and try again."
            }
        }
    }

    // MARK: - Config

    /// Your JotForm form ID that holds the instructor roster
    private static let formId = "242266064536154"   // ✅ per your request

    /// API key from Info.plist ("jotform_api")
    private static var apiKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "JOTFORM_API_KEY") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Public API

    /// Looks up the given 6-digit instructor ID (QID 15) in the form.
    /// On success returns Instructor(firstName, email, oemsId).
    static func authenticate(instructorId raw: String) async throws -> Instructor {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AuthError.invalidInput }
        guard let apiKey = apiKey else { throw AuthError.missingAPIKey }

        let urlString = "https://api.jotform.com/form/\(formId)/submissions?apiKey=\(apiKey)&limit=1000"
        guard let url = URL(string: urlString) else { throw AuthError.badURL }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.httpMethod = "GET"

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.badResponse(code: -1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw AuthError.badResponse(code: http.statusCode)
        }

        let payload: InstructorAuthJotformListResponse
        do {
            payload = try JSONDecoder().decode(InstructorAuthJotformListResponse.self, from: data)
        } catch {
            throw AuthError.decodeFailed
        }

        // Scan all submissions; match on QID 15
        for submission in payload.content {
            guard
                let idValue = submission.answers["15"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                !idValue.isEmpty
            else { continue }

            if idValue == trimmed {
                let fullName = submission.answers["3"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let email    = submission.answers["5"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                return Instructor(
                    fullName: fullName,
                    email: email,
                    oemsId: idValue
                )
            }
        }

        throw AuthError.notAuthorized
    }
}

// MARK: - Minimal JotForm decoding models for this auth

fileprivate struct InstructorAuthJotformListResponse: Decodable {
    let content: [InstructorAuthSubmission]
}

fileprivate struct InstructorAuthSubmission: Decodable {
    let id: String
    let answers: [String: InstructorAuthAnswer]
}

fileprivate struct InstructorAuthAnswer: Decodable {
    let name: String?
    let text: String?
    let answer: InstructorAuthAnswerValue?

    /// Prefer `answer` as a string; fall back to `text`
    var stringValue: String? {
        if let v = answer?.stringValue, !v.isEmpty { return v }
        if let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { return t }
        return nil
    }
}

fileprivate enum InstructorAuthAnswerValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: String])
    case array([String])
    case unknown

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()

        if let s = try? c.decode(String.self) {
            self = .string(s); return
        }
        if let n = try? c.decode(Double.self) {
            self = .number(n); return
        }
        if let b = try? c.decode(Bool.self) {
            self = .bool(b); return
        }
        if let o = try? c.decode([String: String].self) {
            self = .object(o); return
        }
        if let a = try? c.decode([String].self) {
            self = .array(a); return
        }

        self = .unknown
    }

    var stringValue: String? {
        switch self {
        case .string(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t

        case .number(let n):
            return String(n)

        case .bool(let b):
            return b ? "true" : "false"

        case .array(let arr):
            return arr.first?.trimmingCharacters(in: .whitespacesAndNewlines)

        case .object(let dict):
            // Special handling for JotForm control_fullname:
            // we expect keys like prefix / first / middle / last / suffix.
            if dict.keys.contains("first") || dict.keys.contains("last") {
                let parts = [
                    dict["prefix"],
                    dict["first"],
                    dict["middle"],
                    dict["last"],
                    dict["suffix"]
                ]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                if !parts.isEmpty {
                    return parts.joined(separator: " ")
                }
            }

            // Fallback: first non-empty value for other object-type answers
            if let first = dict.values.first(where: {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) {
                return first
            }
            return nil

        case .unknown:
            return nil
        }
    }
}
