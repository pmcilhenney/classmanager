//
//  FlexiQuizClient.swift
//  classmanager
//
//  End-to-end: user lookup/create, quiz assignment, SSO URL (+ POST bridge)
//

import Foundation
import CryptoKit

final class FlexiQuizClient {

    // MARK: - Config

    struct Config {
        let apiBase: String           // e.g. "https://www.flexiquiz.com/api"
        let apiKey: String            // X-API-KEY
        let ssoSharedSecret: String   // FLEXIQUIZ_SSO_SHARED_SECRET
        let emailDomain: String       // e.g. "gcems.org"
        let flexiMap: [String:String] // RefresherA/B/C -> quiz UUID

        static func fromInfoPlist() -> Config {
            let apiBase = (Bundle.main.object(forInfoDictionaryKey: "FLEXIQUIZ_API_BASE") as? String) ?? "https://www.flexiquiz.com/api"
            let apiKey  = (Bundle.main.object(forInfoDictionaryKey: "FLEXIQUIZ_API_KEY") as? String) ?? ""
            let secret  = (Bundle.main.object(forInfoDictionaryKey: "FLEXIQUIZ_SSO_SHARED_SECRET") as? String) ?? ""
            let domain  = (Bundle.main.object(forInfoDictionaryKey: "FLEXIQUIZ_EMAIL_DOMAIN") as? String) ?? "example.com"
            var map: [String:String] = [:]
            if let a = Bundle.main.object(forInfoDictionaryKey: "FLEXIQUIZ_MAP_RefresherA") as? String { map["RefresherA"] = a }
            if let b = Bundle.main.object(forInfoDictionaryKey: "FLEXIQUIZ_MAP_RefresherB") as? String { map["RefresherB"] = b }
            if let c = Bundle.main.object(forInfoDictionaryKey: "FLEXIQUIZ_MAP_RefresherC") as? String { map["RefresherC"] = c }
            return Config(apiBase: apiBase, apiKey: apiKey, ssoSharedSecret: secret, emailDomain: domain, flexiMap: map)
        }
    }

    // MARK: - Model

    struct User: Decodable { let user_id: String }

    // MARK: - State

    private let cfg: Config
    private let session: URLSession = .shared

    init(config: Config) { self.cfg = config }

    // MARK: - Public helpers

    /// Your course-type -> quiz-id map
    func quizId(for courseType: String) -> String? {
        let lc = courseType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch lc {
        case "refresher a", "emt refresher a":
            return cfg.flexiMap["RefresherA"]
        case "refresher b", "emt refresher b":
            return cfg.flexiMap["RefresherB"]
        case "refresher c", "emt refresher c":
            return cfg.flexiMap["RefresherC"]
        default:
            return nil
        }
    }

    /// Ensure user exists and has the quiz assigned. Returns the FlexiQuiz user_id.
    @discardableResult
    func ensureUserAndAssignQuiz(
        email: String,
        firstName: String,
        lastName: String,
        oemsId: String,
        quizId: String
    ) async throws -> String {

        // 1) Find
        if let id = try? await findUserId(userName: email) {
            // 2) Assign quiz
            try await assignQuiz(userId: id, quizId: quizId)
            return id
        }

        // 3) Create (password = lastName + OEMS)
        let pwd = lastName + oemsId
        let newId = try await createUser(
            userName: email,
            password: pwd,
            email: email,
            firstName: firstName,
            lastName: lastName
        )

        // 4) Assign quiz
        try await assignQuiz(userId: newId, quizId: quizId)
        return newId
    }

    // MARK: - Core API

    /// POST /v1/users/find  (form-encoded)
    func findUserId(userName: String) async throws -> String? {
        let url = try makeURL(path: "/v1/users/find")
        let body = form(["user_name": userName])
        let req = try makePOST(url: url, body: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw fxError("No HTTP response") }

        #if DEBUG
        print("[FlexiQuiz:findUserId] \(http.statusCode)")
        if http.statusCode >= 300, let s = String(data: data, encoding: .utf8) { print(s) }
        #endif

        guard http.statusCode == 200 else { return nil }

        if contentTypeIsJSON(http) {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
               let id  = obj["user_id"] as? String,
               !id.isEmpty {
                return id
            }
            return nil
        } else {
            // Some tenants return HTML on 200 for "not found"—treat as nil.
            return nil
        }
    }

    /// POST /v1/users  (form-encoded) -> { "user_id": "..." }
    func createUser(
        userName: String,
        password: String,
        email: String,
        firstName: String,
        lastName: String
    ) async throws -> String {
        let url = try makeURL(path: "/v1/users")
        let body = form([
            "user_name": userName,
            "password": password,
            "user_type": "respondent",
            "email_address": email,
            "first_name": firstName,
            "last_name": lastName,
            "suspended": "false",
            "manage_users": "false",
            "manage_groups": "false",
            "edit_quizzes": "false",
            "send_welcome_email": "true"
        ])
        let req = try makePOST(url: url, body: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw fxError("No HTTP response") }

        #if DEBUG
        print("[FlexiQuiz:createUser] \(http.statusCode)")
        if http.statusCode >= 300, let s = String(data: data, encoding: .utf8) { print(s) }
        #endif

        guard http.statusCode == 200 else {
            throw fxError("Create failed (\(http.statusCode))")
        }
        guard contentTypeIsJSON(http) else {
            // Some tenants reply HTML on success; try to sniff a UUID in body.
            if let s = String(data: data, encoding: .utf8),
               let uuid = firstUUID(in: s) {
                return uuid
            }
            throw fxError("Create returned non-JSON")
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
           let id  = obj["user_id"] as? String,
           !id.isEmpty {
            return id
        }
        throw fxError("Create returned no user_id")
    }

    /// POST /v1/users/{userId}/quizzes  (form-encoded)
    func assignQuiz(userId: String, quizId: String) async throws {
        let url = try makeURL(path: "/v1/users/\(userId)/quizzes")
        let body = form(["quiz_id": quizId])
        let req = try makePOST(url: url, body: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw fxError("No HTTP response") }

        #if DEBUG
        print("[FlexiQuiz:assignQuiz] \(http.statusCode)")
        if http.statusCode >= 300, let s = String(data: data, encoding: .utf8) { print(s) }
        #endif

        guard (200...299).contains(http.statusCode) else {
            // Some tenants send 200 HTML; others may echo a 409-ish scenario via 200 text.
            // Keep strict here so real failures surface.
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw fxError("Assign failed (\(http.statusCode)) \(msg)")
        }
        // Treat 2xx as success regardless of JSON/HTML body.
    }

    /// Returns the latest response_report_url for this user+quiz if one exists.
    func latestResponseReportURL(email: String, quizId: String) async -> URL? {
        guard let userId = try? await findUserId(userName: email) else { return nil }

        let url: URL
        do {
            url = try makeURL(path: "/v1/users/\(userId)/responses")
        } catch {
            #if DEBUG
            print("[FlexiQuiz:latestResponseReportURL] Bad URL: \(error)")
            #endif
            return nil
        }

        let body = form([
            "quiz_id": quizId,
            "limit": "1",
            "order": "desc"
        ])

        let req: URLRequest
        do {
            req = try makePOST(url: url, body: body)
        } catch {
            #if DEBUG
            print("[FlexiQuiz:latestResponseReportURL] Failed to make POST request: \(error)")
            #endif
            return nil
        }

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            #if DEBUG
            print("[FlexiQuiz:latestResponseReportURL] Network error: \(error)")
            #endif
            return nil
        }

        guard let http = resp as? HTTPURLResponse else {
            #if DEBUG
            print("[FlexiQuiz:latestResponseReportURL] No HTTP response")
            #endif
            return nil
        }

        #if DEBUG
        print("[FlexiQuiz:latestResponseReportURL] \(http.statusCode)")
        #endif

        guard (200...299).contains(http.statusCode) else { return nil }
        guard contentTypeIsJSON(http) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let firstResponse: Any?

        if let dict = json as? [String: Any], let content = dict["content"] as? [Any], !content.isEmpty {
            firstResponse = content[0]
        } else if let arr = json as? [Any], !arr.isEmpty {
            firstResponse = arr[0]
        } else {
            return nil
        }

        if let respDict = firstResponse as? [String: Any],
           let urlString = respDict["response_report_url"] as? String,
           let url = URL(string: urlString) {
            return url
        }

        return nil
    }

    // MARK: - SSO (JWT -> URL)

    /// Build a one-time SSO URL (GET). If your tenant rejects GET, use ssoAutoPostBridgeURL.
    func ssoURL(userName: String, quizId: String?) -> URL? {
        guard !cfg.ssoSharedSecret.isEmpty else { return nil }

        let header: [String: Any] = ["alg": "HS256", "typ": "JWT"]
        let exp = Int(Date().addingTimeInterval(5 * 60).timeIntervalSince1970) // exp in seconds
        let payload: [String: Any] = ["user_name": userName, "exp": exp]

        func base64URLEncode(_ data: Data) -> String {
            var s = data.base64EncodedString()
            s = s.replacingOccurrences(of: "+", with: "-")
                 .replacingOccurrences(of: "/", with: "_")
                 .replacingOccurrences(of: "=", with: "")
            return s
        }
        func jsonB64(_ obj: [String: Any]) -> String? {
            guard let d = try? JSONSerialization.data(withJSONObject: obj, options: []) else { return nil }
            return base64URLEncode(d)
        }

        guard
            let headerB64 = jsonB64(header),
            let payloadB64 = jsonB64(payload)
        else { return nil }

        let signingInput = "\(headerB64).\(payloadB64)"
        let key = SymmetricKey(data: Data(cfg.ssoSharedSecret.utf8))
        let sig = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let sigB64 = base64URLEncode(Data(sig))
        let jwt = "\(signingInput).\(sigB64)"

        var comps = URLComponents(string: "https://www.flexiquiz.com/account/auth")!
        var items = [
            URLQueryItem(name: "cla", value: "t"),
            URLQueryItem(name: "jwt", value: jwt),
            URLQueryItem(name: "cb", value: String(Int(Date().timeIntervalSince1970))) // cache-buster
        ]
        if let q = quizId, !q.isEmpty { items.append(URLQueryItem(name: "quiz_id", value: q)) }
        comps.queryItems = items
        return comps.url
    }

    /// POST bridge (data: URL) that auto-submits JWT to /account/auth.
    /// Use this if GET-based SSO yields 400/500 on your tenant.
    func ssoAutoPostBridgeURL(userName: String, quizId: String?) -> URL? {
        guard let getURL = ssoURL(userName: userName, quizId: quizId),
              let comps = URLComponents(url: getURL, resolvingAgainstBaseURL: false),
              let jwt = comps.queryItems?.first(where: { $0.name == "jwt" })?.value
        else { return nil }

        let quizParam = comps.queryItems?.first(where: { $0.name == "quiz_id" })?.value ?? ""
        let quizField = quizParam.isEmpty ? "" : "<input type=\"hidden\" name=\"quiz_id\" value=\"\(quizParam)\">"
        let cb = String(Int(Date().timeIntervalSince1970))

        let html = """
        <html><body>
        <form id="f" action="https://www.flexiquiz.com/account/auth?cla=t&cb=\(cb)" method="post">
          <input type="hidden" name="jwt" value="\(jwt)">
          \(quizField)
        </form>
        <script>document.getElementById('f').submit();</script>
        </body></html>
        """
        let b64 = Data(html.utf8).base64EncodedString()
        return URL(string: "data:text/html;base64,\(b64)")
    }

    // MARK: - Internals

    private func makeURL(path: String) throws -> URL {
        var base = cfg.apiBase
        if base.hasSuffix("/") { base.removeLast() }
        var p = path
        if !p.hasPrefix("/") { p = "/\(p)" }
        guard let url = URL(string: base + p) else { throw fxError("Bad URL") }
        return url
    }

    private func makePOST(url: URL, body: Data) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(cfg.apiKey, forHTTPHeaderField: "X-API-KEY")
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = body
        // Extra safety for some infra: do not reuse cached responses
        req.cachePolicy = .reloadIgnoringLocalCacheData
        return req
    }

    private func form(_ dict: [String:String]) -> Data {
        let enc: (String) -> String = { s in
            var cs = CharacterSet.urlQueryAllowed
            cs.remove("+"); cs.remove("&"); cs.remove("=")
            return s.addingPercentEncoding(withAllowedCharacters: cs) ?? s
        }
        let body = dict.map { "\(enc($0.key))=\(enc($0.value))" }
                       .joined(separator: "&")
        return Data(body.utf8)
    }

    private func contentTypeIsJSON(_ http: HTTPURLResponse) -> Bool {
        (http.value(forHTTPHeaderField: "Content-Type") ?? "")
            .lowercased().contains("application/json")
    }

    private func firstUUID(in s: String) -> String? {
        // crude UUID finder for HTML responses
        let pattern = #"[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"#
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        if let m = r.firstMatch(in: s, options: [], range: range),
           let rr = Range(m.range, in: s) {
            return String(s[rr])
        }
        return nil
    }

    private func fxError(_ msg: String) -> NSError {
        NSError(domain: "FlexiQuiz", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
    
    // Add near the bottom of FlexiQuizClient, before the final closing brace:

    /// All-in-one flow with graceful fallbacks:
    /// - Try find
    /// - If not found, try create; if 500, assume "exists" and keep going
    /// - Try assign (ignore non-200 silently)
    /// - Always try to return an SSO URL (or bridge) so UX is uninterrupted.
    func prepareQuizAndMakeSSOURL(
        email: String,
        firstName: String,
        lastName: String,
        oemsId: String,
        courseType: String
    ) async -> URL? {
        let quizId = self.quizId(for: courseType) ?? ""
        // We can still SSO without quiz_id; user lands at account page.
        // Prefer quiz_id when available.
        do {
            // 1) Try to find
            if let userId = try? await findUserId(userName: email), let url = ssoURL(userName: email, quizId: quizId) {
                // Best-effort assign; don't block SSO on errors
                _ = try? await assignQuiz(userId: userId, quizId: quizId)
                return url
            }

            // 2) Not found → try create
            do {
                let pwd = lastName + oemsId
                let userId = try await createUser(
                    userName: email,
                    password: pwd,
                    email: email,
                    firstName: firstName,
                    lastName: lastName
                )
                _ = try? await assignQuiz(userId: userId, quizId: quizId)
                return ssoURL(userName: email, quizId: quizId)
            } catch {
                // 500 path: assume user exists, continue with SSO
                if let url = ssoURL(userName: email, quizId: quizId) { return url }
                return nil
            }
        }
        // Any unhandled error → still try SSO
        return ssoURL(userName: email, quizId: quizId)
    }

    /// Optional: some tenants are picky with GET vs POST; this gives you a tiny "auto-POST" page.
    /// Use when standard ssoURL shows blank for you (WKWebView + third-party cookies).
    func ssoBridgeDataURL(userName: String, quizId: String?) -> URL? {
        guard let url = ssoURL(userName: userName, quizId: quizId),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let jwt = comps.queryItems?.first(where: {$0.name == "jwt"})?.value
        else { return nil }

        let qid = comps.queryItems?.first(where: {$0.name == "quiz_id"})?.value ?? ""
        let qField = qid.isEmpty ? "" : "<input type='hidden' name='quiz_id' value='\(qid)'>"
        let html = """
        <html><body>
          <form id="f" action="https://www.flexiquiz.com/account/auth?cla=t" method="post">
            <input type="hidden" name="jwt" value="\(jwt)">
            \(qField)
          </form>
          <script>document.getElementById('f').submit();</script>
        </body></html>
        """
        let b64 = Data(html.utf8).base64EncodedString()
        return URL(string: "data:text/html;base64," + b64)
    }
}

