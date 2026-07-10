//
//  CFAICommentGenerator.swift
//  classmanager
//
//  AI comment generation using Cloudflare Workers AI
//

import Foundation

actor CFAICommentGenerator {
    private static func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        AppDebugLog.log(message())
        #endif
    }
    
    /// Generate a positive performance comment using Cloudflare AI
    static func generateComment(
        studentName: String,
        courseTitle: String,
        context: String = "completion",
        studentId: String? = nil,
        classSessionId: String? = nil
    ) async -> String {
        
        debugLog("[CFAICommentGenerator] Starting AI comment generation")
        debugLog("[CFAICommentGenerator] Student: \(studentName)")
        debugLog("[CFAICommentGenerator] Course: \(courseTitle)")
        debugLog("[CFAICommentGenerator] Context: \(context)")
        
        do {
            let comment = try await callCloudflareAI(
                studentName: studentName,
                courseTitle: courseTitle,
                context: context,
                studentId: studentId,
                classSessionId: classSessionId
            )
            debugLog("[CFAICommentGenerator] AI generation successful")
            debugLog("[CFAICommentGenerator] Generated: \(comment)")
            return comment
        } catch {
            debugLog("[CFAICommentGenerator] Error occurred: \(error)")
            debugLog("[CFAICommentGenerator] Using template fallback")
            let fallback = generateTemplateComment(studentName: studentName, courseTitle: courseTitle)
            debugLog("[CFAICommentGenerator] Fallback: \(fallback)")
            return fallback
        }
    }
    
    /// Call Cloudflare Worker AI endpoint
    private static func callCloudflareAI(
        studentName: String,
        courseTitle: String,
        context: String,
        studentId: String?,
        classSessionId: String?
    ) async throws -> String {
        
        debugLog("[CFAICommentGenerator] Calling Cloudflare Worker API")
        
        let url = classManagerAPIBaseURL().appendingPathComponent("aicomments")
        
        debugLog("[CFAICommentGenerator] URL validated: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        var requestBody: [String: Any] = [
            "studentName": studentName,
            "courseTitle": courseTitle,
            "context": context
        ]
        if let studentId, !studentId.isEmpty {
            requestBody["studentId"] = studentId
        }
        if let classSessionId, !classSessionId.isEmpty {
            requestBody["classSessionId"] = classSessionId
        }
        
        debugLog("[CFAICommentGenerator] Request body: \(requestBody)")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        debugLog("[CFAICommentGenerator] Sending request")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            debugLog("[CFAICommentGenerator] Not an HTTP response")
            throw NSError(domain: "CFAICommentGenerator", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response from server"
            ])
        }
        
        debugLog("[CFAICommentGenerator] HTTP Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            debugLog("[CFAICommentGenerator] Bad status code: \(httpResponse.statusCode)")
            if let responseStr = String(data: data, encoding: .utf8) {
                debugLog("[CFAICommentGenerator] Response: \(responseStr)")
            }
            throw NSError(domain: "CFAICommentGenerator", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response from server"
            ])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        debugLog("[CFAICommentGenerator] JSON response: \(json ?? [:])")
        
        guard let success = json?["success"] as? Bool, success else {
            let errorMsg = json?["error"] as? String ?? "Unknown error"
            debugLog("[CFAICommentGenerator] API returned error: \(errorMsg)")
            throw NSError(domain: "CFAICommentGenerator", code: 3, userInfo: [
                NSLocalizedDescriptionKey: errorMsg
            ])
        }
        
        guard let comment = json?["comment"] as? String else {
            debugLog("[CFAICommentGenerator] No comment in response")
            throw NSError(domain: "CFAICommentGenerator", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "No comment in response"
            ])
        }
        
        let usedFallback = json?["usedFallback"] as? Bool ?? false
        if usedFallback {
            let reason = json?["reason"] as? String ?? "unknown"
            debugLog("[CFAICommentGenerator] Server used fallback. Reason: \(reason)")
        } else {
            debugLog("[CFAICommentGenerator] AI-generated comment received")
        }
        
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        debugLog("[CFAICommentGenerator] Final comment: \(trimmed)")
        return trimmed
    }
    
    /// Template-based fallback (matches server templates)
    private static func generateTemplateComment(studentName: String, courseTitle: String) -> String {
        let templates: [String] = [
            "\(studentName) demonstrated excellent engagement throughout \(courseTitle). Their active participation and willingness to learn contributed positively to the class environment.",
            "\(studentName) showed strong commitment to learning in \(courseTitle). They participated actively and displayed a professional attitude throughout the course.",
            "\(studentName) completed \(courseTitle) with enthusiasm and dedication. Their consistent participation and positive approach to learning were commendable.",
            "\(studentName) exhibited outstanding participation in \(courseTitle). They engaged thoughtfully with course material and demonstrated a strong grasp of key concepts.",
            "\(studentName) was an engaged and attentive participant in \(courseTitle). Their professionalism and eagerness to learn made a positive impact on the class.",
            "\(studentName) successfully completed \(courseTitle) with excellent attendance and participation. Their dedication to learning and positive attitude were notable throughout the course."
        ]
        return templates.randomElement() ?? templates[0]
    }
    
    /// Clean course name helper
    private static func cleanCourseName(_ name: String) -> String {
        if let range = name.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            return String(name[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return name.trimmingCharacters(in: .whitespaces)
    }
    
    /// Generate comment with retry logic
    static func generateCommentWithRetry(
        studentName: String,
        courseTitle: String,
        context: String = "completion",
        studentId: String? = nil,
        classSessionId: String? = nil,
        maxRetries: Int = 2
    ) async -> String {
        
        debugLog("[CFAICommentGenerator] Starting with retry logic (max: \(maxRetries) attempts)")
        
        for attempt in 0..<maxRetries {
            debugLog("[CFAICommentGenerator] Attempt \(attempt + 1)/\(maxRetries)")
            
            let comment = await generateComment(
                studentName: studentName,
                courseTitle: courseTitle,
                context: context,
                studentId: studentId,
                classSessionId: classSessionId
            )
            
            // Validate that comment includes required elements
            let hasName = comment.contains(studentName)
            let hasCourse = comment.localizedCaseInsensitiveContains(courseTitle) ||
                           comment.localizedCaseInsensitiveContains(cleanCourseName(courseTitle))
            
            debugLog("[CFAICommentGenerator] Validation - Has name: \(hasName), Has course: \(hasCourse)")
            
            if hasName && hasCourse {
                debugLog("[CFAICommentGenerator] Comment validated successfully")
                return comment
            }
            
            debugLog("[CFAICommentGenerator] Generated comment failed validation, using local fallback")
            return guaranteedFallback(studentName: studentName, courseTitle: courseTitle)
        }
        
        // Final fallback - guaranteed to include name and course
        debugLog("[CFAICommentGenerator] All attempts exhausted, using guaranteed fallback")
        let fallback = guaranteedFallback(studentName: studentName, courseTitle: courseTitle)
        debugLog("[CFAICommentGenerator] Final fallback: \(fallback)")
        return fallback
    }

    private static func guaranteedFallback(studentName: String, courseTitle: String) -> String {
        "\(studentName) successfully completed \(courseTitle) with excellent participation and engagement. Their professional attitude and dedication to learning were exemplary throughout the course."
    }

    private static func classManagerAPIBaseURL() -> URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "CLASSMANAGER_API_BASE_URL") as? String,
           let url = URL(string: raw), !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }
        return URL(string: "https://classmanagerapp.gcemstrainingacademy.org")!
    }
}
