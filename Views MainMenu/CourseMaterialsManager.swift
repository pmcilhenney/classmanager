import Foundation
import Combine

/// Manages loading and parsing course materials from JotForm
@MainActor
final class CourseMaterialsManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var materials: [(title: String, url: URL)] = []
    @Published var materialCandidates: [([String: Any], String)] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    // Elective extras (optional fields on the same materials form)
    @Published var electiveSkillsURL: URL? = nil
    @Published var electiveQuizURLs: [URL] = []
    
    // MARK: - Dependencies
    
    private let jotformApiKey: String
    private let materialsFormId: String
    
    init(jotformApiKey: String, materialsFormId: String) {
        self.jotformApiKey = jotformApiKey
        self.materialsFormId = materialsFormId
    }
    
    // MARK: - Public Methods
    
    /// Load course materials for a given course name
    func loadMaterials(for courseType: String) async {
        isLoading = true
        errorMessage = nil
        materials = []
        materialCandidates = []
        electiveSkillsURL = nil
        electiveQuizURLs = []
        
        defer { isLoading = false }
        
        guard !materialsFormId.isEmpty else {
            errorMessage = "Missing COURSE_MATERIALS_ID in configuration."
            return
        }
        
        guard !jotformApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Missing JotForm API key."
            return
        }
        
        let wantName = canonicalName(courseType)
        
        #if DEBUG
        print("[Materials] Looking for course: '\(courseType)' -> canonical: '\(wantName)'")
        #endif
        
        let base = "https://api.jotform.com"
        guard let url = URL(string: "\(base)/form/\(materialsFormId)/submissions?apiKey=\(jotformApiKey)&limit=1000") else {
            errorMessage = "Invalid API URL."
            return
        }
        
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = "Failed to fetch materials from JotForm."
                return
            }
            
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = root["content"] as? [[String: Any]] else {
                errorMessage = "Invalid response from JotForm."
                return
            }
            
            #if DEBUG
            print("[Materials] Found \(content.count) total submissions")
            #endif
            
            let result = findMatchingSubmission(wantName: wantName, submissions: content)
            
            switch result {
            case .exactMatch(let answers):
                let items = materialsFromAnswers(answers)
                
                #if DEBUG
                print("[Materials] Extracted \(items.count) PDF(s)")
                for (idx, item) in items.enumerated() {
                    print("[Materials]   [\(idx)]: '\(item.0)' -> \(item.1)")
                }
                #endif
                
                if items.isEmpty {
                    errorMessage = "No PDF files attached to this course."
                } else {
                    materials = items
                }
                // Extract elective extras (QID 5 = skillsUrl, QID 6 = quizUrl)
                let (skills, quizzes) = electiveExtrasFromAnswers(answers)
                electiveSkillsURL = skills
                electiveQuizURLs = quizzes
                
            case .multipleCandidates(let candidates):
                #if DEBUG
                print("[Materials] No exact match found. Candidates: \(candidates.count)")
                for (idx, cand) in candidates.enumerated() {
                    print("[Materials]   Candidate #\(idx): \(cand.1)")
                }
                #endif
                
                if candidates.isEmpty {
                    errorMessage = "No materials found for '\(courseType)'."
                } else {
                    materialCandidates = candidates
                }
            }
            
        } catch {
            #if DEBUG
            print("[Materials] Error: \(error)")
            #endif
            errorMessage = "Failed to load materials: \(error.localizedDescription)"
        }
    }
    
    /// Select a specific candidate when multiple matches were found
    func selectCandidate(_ answers: [String: Any]) {
        let items = materialsFromAnswers(answers)
        
        #if DEBUG
        print("[Materials] User selected course, found \(items.count) PDF(s)")
        #endif
        
        materialCandidates = []
        
        if items.isEmpty {
            errorMessage = "No PDF files attached to this course."
        } else {
            materials = items
        }
        // Also extract elective extras from the selected candidate
        let (skills, quizzes) = electiveExtrasFromAnswers(answers)
        electiveSkillsURL = skills
        electiveQuizURLs = quizzes
    }

    // MARK: - Elective extras parsing
    private func electiveExtrasFromAnswers(_ answers: [String: Any]) -> (URL?, [URL]) {
        // QID 5 -> skillsUrl, QID 6 -> quizUrl
        func extractURLs(fromField field: Any?) -> [URL] {
            guard let f = field else { return [] }
            // field may be a dictionary with "answer" key, or a raw string/array
            if let dict = f as? [String: Any] {
                if let arr = dict["answer"] as? [String] {
                    return arr.compactMap { URL(string: $0) }
                }
                if let s = dict["answer"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // support comma/newline-separated lists
                    let parts = s.split(whereSeparator: { $0 == "," || $0.isNewline }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    return parts.compactMap { URL(string: $0) }
                }
            } else if let arr = f as? [String] {
                return arr.compactMap { URL(string: $0) }
            } else if let s = f as? String {
                if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
                let parts = s.split(whereSeparator: { $0 == "," || $0.isNewline }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return parts.compactMap { URL(string: $0) }
            }
            // Fallback: try to find by name keys
            for (_, v) in answers {
                if let dict = v as? [String: Any], let name = dict["name"] as? String {
                    if name.lowercased().contains("skillsurl") || name.lowercased().contains("skill") {
                        if let s = dict["answer"] as? String, let u = URL(string: s) { return [u] }
                    }
                    if name.lowercased().contains("quizurl") || name.lowercased().contains("quiz") {
                        if let s = dict["answer"] as? String { return s.split(separator: ",").compactMap { URL(string: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) } }
                    }
                }
            }
            return []
        }

        let skillsField = answers["5"] ?? answers["skillsUrl"]
        let quizField = answers["6"] ?? answers["quizUrl"]

        let skillsURLs = extractURLs(fromField: skillsField)
        let quizURLs = extractURLs(fromField: quizField)

        return (skillsURLs.first, quizURLs)
    }
    
    // MARK: - Private Methods
    
    private enum MatchResult {
        case exactMatch([String: Any])
        case multipleCandidates([([String: Any], String)])
    }
    
    private func findMatchingSubmission(wantName: String, submissions: [[String: Any]]) -> MatchResult {
        var bestAnswers: [String: Any]? = nil
        var candidates: [([String: Any], String)] = []
        
        for (idx, submission) in submissions.enumerated() {
            // JotForm submissions API returns answers in different possible locations
            var answers: [String: Any]? = nil
            
            if let bag = submission["answers"] as? [String: Any] {
                answers = bag
            } else if let bag = submission["content"] as? [String: Any],
                      let ans = bag["answers"] as? [String: Any] {
                answers = ans
            }
            
            guard let ans = answers else {
                #if DEBUG
                print("[Materials] Submission #\(idx) has no parseable answers, keys: \(Array(submission.keys))")
                #endif
                continue
            }
            
            let rawTitle = titleFromAnswers(ans)
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !title.isEmpty else {
                #if DEBUG
                print("[Materials] Submission #\(idx) has empty title")
                #endif
                continue
            }
            
            let have = canonicalName(title)
            
            #if DEBUG
            print("[Materials] Submission #\(idx): '\(title)' -> canonical: '\(have)'")
            #endif
            
            if fuzzyMatch(want: wantName, have: have) {
                bestAnswers = ans
                break
            }
            
            candidates.append((ans, title))
        }
        
        if let best = bestAnswers {
            return .exactMatch(best)
        } else {
            return .multipleCandidates(candidates)
        }
    }
    
    private func fuzzyMatch(want: String, have: String) -> Bool {
        let ta = Set(want.split(separator: " ").map(String.init))
        let tb = Set(have.split(separator: " ").map(String.init))
        let overlap = ta.intersection(tb)
        
        #if DEBUG
        print("[Materials]   want tokens: \(ta)")
        print("[Materials]   have tokens: \(tb)")
        print("[Materials]   overlap: \(overlap) (count: \(overlap.count))")
        #endif
        
        let shorter = ta.count <= tb.count ? ta : tb
        let longer  = ta.count  > tb.count ? ta : tb
        let isSubset = shorter.isSubset(of: longer)
        
        if isSubset {
            #if DEBUG
            print("[Materials]   ✓ MATCH via subset")
            #endif
            return true
        }
        
        if overlap.count >= 2 {
            #if DEBUG
            print("[Materials]   ✓ MATCH via overlap (2+ tokens)")
            #endif
            return true
        }
        
        if want.count >= 4 && have.count >= 4 {
            let startsWith = have.hasPrefix(String(want.prefix(4))) || want.hasPrefix(String(have.prefix(4)))
            let endsWith = have.hasSuffix(String(want.suffix(4))) || want.hasSuffix(String(have.suffix(4)))
            
            if startsWith || endsWith {
                #if DEBUG
                print("[Materials]   ✓ MATCH via prefix/suffix")
                #endif
                return true
            }
        }
        
        return false
    }
    
    /// Extract course title from QID 3 answers
    private func titleFromAnswers(_ answers: [String: Any]) -> String {
        #if DEBUG
        print("[Materials] titleFromAnswers: keys=\(Array(answers.keys))")
        #endif
        
        // QID 3 is courseName
        if let field = answers["3"] as? [String: Any] {
            #if DEBUG
            print("[Materials] Found QID 3: \(field)")
            #endif
            
            if let s = field["answer"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return s
            }
            if let t = field["text"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return t
            }
        }
        
        // Fallback: search by field name
        for (qid, v) in answers {
            if let dict = v as? [String: Any],
               let name = dict["name"] as? String,
               name == "courseName" {
                #if DEBUG
                print("[Materials] Found courseName field at QID \(qid): \(dict)")
                #endif
                
                if let s = dict["answer"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return s
                }
                if let t = dict["text"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return t
                }
            }
        }
        
        return ""
    }
    
    /// Extract PDF URLs from QID 4 (courseMaterials file upload field)
    private func materialsFromAnswers(_ answers: [String: Any]) -> [(String, URL)] {
        var result: [(String, URL)] = []
        
        #if DEBUG
        print("[Materials] materialsFromAnswers: keys=\(Array(answers.keys))")
        #endif
        
        // QID 4 is courseMaterials
        var field: [String: Any]? = answers["4"] as? [String: Any]
        
        if field == nil {
            // Fallback by field name
            for (qid, v) in answers {
                if let dict = v as? [String: Any],
                   let name = dict["name"] as? String,
                   name == "courseMaterials" {
                    #if DEBUG
                    print("[Materials] Found courseMaterials field at QID \(qid)")
                    #endif
                    field = dict
                    break
                }
            }
        }
        
        guard let f = field else {
            #if DEBUG
            print("[Materials] No field found for QID 4 or courseMaterials")
            #endif
            return result
        }
        
        #if DEBUG
        print("[Materials] Field QID 4 content: \(f)")
        #endif
        
        // Handle array of URLs
        if let arr = f["answer"] as? [String] {
            #if DEBUG
            print("[Materials] Found answer array with \(arr.count) items")
            #endif
            
            for s in arr {
                if let u = URL(string: s) {
                    let filename = u.lastPathComponent.removingPercentEncoding ?? u.lastPathComponent
                    result.append((filename, u))
                    
                    #if DEBUG
                    print("[Materials] Added PDF: '\(filename)' -> \(u)")
                    #endif
                }
            }
        } else if let s = f["answer"] as? String {
            #if DEBUG
            print("[Materials] Found single answer string: \(s)")
            #endif
            
            if let u = URL(string: s) {
                let filename = u.lastPathComponent.removingPercentEncoding ?? u.lastPathComponent
                result.append((filename, u))
            }
        } else {
            #if DEBUG
            print("[Materials] Answer field is neither array nor string, type: \(type(of: f["answer"]))")
            #endif
        }
        
        return result
    }
    
    private func canonicalName(_ s: String) -> String {
        let lower = s.lowercased()
        let cleaned = lower.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        let tokens = cleaned.split(separator: " ").map(String.init)
        let filtered = tokens.filter { !["emt", "course", "class", "training", "session"].contains($0) }
        return filtered.joined(separator: " ")
    }
}
