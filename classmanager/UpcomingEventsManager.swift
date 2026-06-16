//
//  UpcomingEventsManager.swift
//  classmanager
//
//  Fetches upcoming training events from the registration form
//

import Foundation
import SwiftUI
import Combine

// MARK: - Models

struct UpcomingEvent: Identifiable, Equatable {
    let id: String
    let courseName: String
    let dateString: String
    let date: Date
    let imageURL: String?
    
    var displayName: String {
        // Clean the course name (remove trailing parentheticals)
        cleanCourseName(courseName)
    }
    
    var formattedDate: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEEE, MMMM d, yyyy"
        return df.string(from: date)
    }
    
    private func cleanCourseName(_ s: String) -> String {
        if let r = s.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            let before = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            let after = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if after.isEmpty && before.isEmpty { return s }
            if before.isEmpty || before.count < 5 { return s }
            return before
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Manager

@MainActor
final class UpcomingEventsManager: ObservableObject {
    @Published var events: [UpcomingEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let jotformApiKey: String
    private let registrationFormId = "251265925097060"
    
    init(jotformApiKey: String) {
        self.jotformApiKey = jotformApiKey
    }
    
    func loadUpcomingEvents(limit: Int = 5) async {
        isLoading = true
        errorMessage = nil
        events = []
        
        defer { isLoading = false }
        
        guard !jotformApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Missing JotForm API key."
            return
        }
        
        let base = "https://api.jotform.com"
        // Use submissions endpoint with limit=1 to get one submission containing all products
        guard let url = URL(string: "\(base)/form/\(registrationFormId)/submissions?apiKey=\(jotformApiKey)&limit=1&orderby=id") else {
            errorMessage = "Invalid API URL."
            return
        }
        
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = "Failed to fetch form data."
                return
            }
            
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = root["content"] as? [[String: Any]],
                  let firstSubmission = content.first,
                  let answers = firstSubmission["answers"] as? [String: Any],
                  let qid39 = answers["39"] as? [String: Any],
                  let productsDict = qid39["products"] as? [String: [String: Any]] else {
                errorMessage = "Invalid response structure."
                return
            }
            
            #if DEBUG
            print("[UpcomingEvents] Found \(productsDict.count) total products")
            #endif
            
            // Parse all products and extract dates
            var allEvents: [UpcomingEvent] = []
            let now = Date()
            
            for (_, product) in productsDict {
                // Skip products that are disabled="hide" or invisible="Yes"
                if let disabled = product["disabled"] as? String, disabled == "hide" {
                    continue
                }
                if let invisible = product["invisible"] as? String, invisible == "Yes" {
                    continue
                }
                
                guard let name = product["name"] as? String, !name.isEmpty else {
                    continue
                }
                
                let description = (product["description"] as? String) ?? ""
                
                // Parse date from description
                guard let parsedDate = parseDate(from: description) else {
                    #if DEBUG
                    print("[UpcomingEvents] Could not parse date from: \(name) - desc: \(description)")
                    #endif
                    continue
                }
                
                // Only include future events
                guard parsedDate > now else {
                    #if DEBUG
                    print("[UpcomingEvents] Skipping past event: \(name) - \(parsedDate)")
                    #endif
                    continue
                }
                
                // Extract image URL from images field
                var imageURL: String?
                if let imagesStr = product["images"] as? String {
                    // Images field is a JSON string like '["https://..."]'
                    // Remove escaped slashes first
                    let cleanedStr = imagesStr.replacingOccurrences(of: "\\/", with: "/")
                    if let data = cleanedStr.data(using: .utf8),
                       let arr = try? JSONSerialization.jsonObject(with: data) as? [String],
                       let firstImage = arr.first {
                        imageURL = firstImage
                    }
                }
                
                // Generate unique ID from product data
                let eventId = (product["pid"] as? String) ?? (product["paymentUUID"] as? String) ?? UUID().uuidString
                
                let event = UpcomingEvent(
                    id: eventId,
                    courseName: name,
                    dateString: description,
                    date: parsedDate,
                    imageURL: imageURL
                )
                
                allEvents.append(event)
                
                #if DEBUG
                print("[UpcomingEvents] Added event: \(name) - \(parsedDate) - image: \(imageURL ?? "none")")
                #endif
            }
            
            // Sort by date (earliest first) and take the requested limit
            let sortedEvents = allEvents.sorted { $0.date < $1.date }
            events = Array(sortedEvents.prefix(limit))
            
            #if DEBUG
            print("[UpcomingEvents] Returning \(events.count) upcoming events")
            #endif
            
        } catch {
            #if DEBUG
            print("[UpcomingEvents] Error: \(error)")
            #endif
            errorMessage = "Failed to load events: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Date Parsing
    
    private func parseDate(from description: String) -> Date? {
        // Look for patterns like:
        // "Date: January 15, 2026 Time: 08:00-17:00 Course ID: 167314 CEUs: 8.0"
        // "Date: December 12, 2025 \r\nTime: 08:00-17:00\r\nCourse ID: 166112\r\nCEUs: 8.0"
        // "December 1, 2, & 3, 2025 (8am-5pm)\r\nCourse ID: 165530"
        
        // Strategy 1: Look for "Date: " prefix
        let lines = description.components(separatedBy: .newlines)
        var dateString: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("date:") {
                dateString = trimmed.replacingOccurrences(of: "Date:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                // Remove anything after " Time:" to isolate just the date
                if let timeRange = dateString?.range(of: " Time:", options: .caseInsensitive) {
                    dateString = String(dateString![..<timeRange.lowerBound])
                }
                break
            }
        }
        
        // Strategy 2: Regex for date patterns at start of string
        if dateString == nil {
            // Look for "Month Day, Year" at the beginning
            if let match = description.range(of: #"^(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}"#, options: .regularExpression) {
                dateString = String(description[match])
            }
            // Look for "Month Day, Day, & Day, Year" (multi-day format)
            else if let match = description.range(of: #"^(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}[,\s&\d]+\d{4}"#, options: .regularExpression) {
                let matched = String(description[match])
                // Extract just the first date and year
                if let firstDateMatch = matched.range(of: #"(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}"#, options: .regularExpression),
                   let yearMatch = matched.range(of: #"\d{4}"#, options: .regularExpression) {
                    let firstDate = String(matched[firstDateMatch])
                    let year = String(matched[yearMatch])
                    dateString = "\(firstDate), \(year)"
                }
            }
        }
        
        guard let dateStr = dateString else {
            return nil
        }
        
        #if DEBUG
        print("[UpcomingEvents] Parsing date string: '\(dateStr)'")
        #endif
        
        // Try to parse with multiple formats
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        
        let formats = [
            "MMMM d, yyyy",      // "January 15, 2026"
            "MMM d, yyyy",       // "Jan 15, 2026"
            "MM/dd/yyyy",        // "01/15/2026"
            "M/d/yyyy",          // "1/15/2026"
            "MMMM dd, yyyy",     // "January 01, 2026"
            "MMM dd, yyyy"       // "Jan 01, 2026"
        ]
        
        for format in formats {
            df.dateFormat = format
            if let date = df.date(from: dateStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                #if DEBUG
                print("[UpcomingEvents] Successfully parsed with format: \(format)")
                #endif
                return date
            }
        }
        
        #if DEBUG
        print("[UpcomingEvents] Failed to parse date: '\(dateStr)'")
        #endif
        
        return nil
    }
}

