//
//  CFAICommentGenerator.swift
//  classmanager
//
//  AI comment generation using Cloudflare Workers AI
//

import Foundation

actor CFAICommentGenerator {
    
    // Your Cloudflare Worker URL
    private static let workerURL = "https://alertsapp.gcemstrainingacademy.org/aicomments"
    
    /// Generate a positive performance comment using Cloudflare AI
    static func generateComment(
        studentName: String,
        courseTitle: String,
        context: String = "completion"
    ) async -> String {
        
        print("[CFAICommentGenerator] 🚀 Starting AI comment generation")
        print("[CFAICommentGenerator] Student: \(studentName)")
        print("[CFAICommentGenerator] Course: \(courseTitle)")
        print("[CFAICommentGenerator] Context: \(context)")
        print("[CFAICommentGenerator] Worker URL: \(workerURL)")
        
        do {
            let comment = try await callCloudflareAI(
                studentName: studentName,
                courseTitle: courseTitle,
                context: context
            )
            print("[CFAICommentGenerator] ✅ AI generation successful!")
            print("[CFAICommentGenerator] Generated: \(comment)")
            return comment
        } catch {
            print("[CFAICommentGenerator] ❌ Error occurred: \(error)")
            print("[CFAICommentGenerator] ⚠️  Using template fallback")
            let fallback = generateTemplateComment(studentName: studentName, courseTitle: courseTitle)
            print("[CFAICommentGenerator] Fallback: \(fallback)")
            return fallback
        }
    }
    
    /// Call Cloudflare Worker AI endpoint
    private static func callCloudflareAI(
        studentName: String,
        courseTitle: String,
        context: String
    ) async throws -> String {
        
        print("[CFAICommentGenerator] 📡 Calling Cloudflare Worker API...")
        
        guard let url = URL(string: workerURL) else {
            print("[CFAICommentGenerator] ❌ Invalid worker URL: \(workerURL)")
            throw NSError(domain: "CFAICommentGenerator", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid worker URL"
            ])
        }
        
        print("[CFAICommentGenerator] ✓ URL validated: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let requestBody: [String: Any] = [
            "studentName": studentName,
            "courseTitle": courseTitle,
            "context": context
        ]
        
        print("[CFAICommentGenerator] 📦 Request body: \(requestBody)")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[CFAICommentGenerator] 🌐 Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[CFAICommentGenerator] ❌ Not an HTTP response")
            throw NSError(domain: "CFAICommentGenerator", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response from server"
            ])
        }
        
        print("[CFAICommentGenerator] 📨 HTTP Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("[CFAICommentGenerator] ❌ Bad status code: \(httpResponse.statusCode)")
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[CFAICommentGenerator] Response: \(responseStr)")
            }
            throw NSError(domain: "CFAICommentGenerator", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response from server"
            ])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        print("[CFAICommentGenerator] 📋 JSON response: \(json ?? [:])")
        
        guard let success = json?["success"] as? Bool, success else {
            let errorMsg = json?["error"] as? String ?? "Unknown error"
            print("[CFAICommentGenerator] ❌ API returned error: \(errorMsg)")
            throw NSError(domain: "CFAICommentGenerator", code: 3, userInfo: [
                NSLocalizedDescriptionKey: errorMsg
            ])
        }
        
        guard let comment = json?["comment"] as? String else {
            print("[CFAICommentGenerator] ❌ No comment in response")
            throw NSError(domain: "CFAICommentGenerator", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "No comment in response"
            ])
        }
        
        let usedFallback = json?["usedFallback"] as? Bool ?? false
        if usedFallback {
            let reason = json?["reason"] as? String ?? "unknown"
            print("[CFAICommentGenerator] ⚠️  Server used fallback. Reason: \(reason)")
        } else {
            print("[CFAICommentGenerator] ✅ AI-generated comment received")
        }
        
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[CFAICommentGenerator] 💬 Final comment: \(trimmed)")
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
        maxRetries: Int = 2
    ) async -> String {
        
        print("[CFAICommentGenerator] 🔄 Starting with retry logic (max: \(maxRetries) attempts)")
        
        for attempt in 0..<maxRetries {
            print("[CFAICommentGenerator] 🔄 Attempt \(attempt + 1)/\(maxRetries)")
            
            let comment = await generateComment(
                studentName: studentName,
                courseTitle: courseTitle,
                context: context
            )
            
            // Validate that comment includes required elements
            let hasName = comment.contains(studentName)
            let hasCourse = comment.localizedCaseInsensitiveContains(courseTitle) ||
                           comment.localizedCaseInsensitiveContains(cleanCourseName(courseTitle))
            
            print("[CFAICommentGenerator] 🔍 Validation - Has name: \(hasName), Has course: \(hasCourse)")
            
            if hasName && hasCourse {
                print("[CFAICommentGenerator] ✅ Comment validated successfully!")
                return comment
            }
            
            print("[CFAICommentGenerator] ⚠️  Attempt \(attempt + 1) failed validation, retrying...")
        }
        
        // Final fallback - guaranteed to include name and course
        print("[CFAICommentGenerator] ⚠️  All attempts exhausted, using guaranteed fallback")
        let fallback = "\(studentName) successfully completed \(courseTitle) with excellent participation and engagement. Their professional attitude and dedication to learning were exemplary throughout the course."
        print("[CFAICommentGenerator] 💬 Final fallback: \(fallback)")
        return fallback
    }
}
