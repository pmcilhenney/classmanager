
//
//  Created by Patrick McIlhenney on 11/8/25.
//

//  AppointmentParsing.swift
//  classmanager
//
//  Parse JotForm appointment widgets (Q60/Q74/Q77).
//  Extracts: clean date "MM/DD/YYYY" + nice button label.

import Foundation
import Combine

/// Return a clean "MM/DD/YYYY" from the appointment answer dict (e.g. "2025-11-13 08:00").
func appointmentDateForQID(_ answers: [String: Any], qid: String) -> String? {
    guard let obj = answers[qid] as? [String: Any] else { return nil }

    // Prefer the structured answer dictionary
    if let ans = obj["answer"] as? [String: Any],
       let raw = ans["date"] as? String {
        // raw = "YYYY-MM-DD HH:mm"
        let datePart = raw.split(separator: " ").first.map(String.init) ?? raw
        return normalizeDateString(datePart) // -> "MM/DD/YYYY"
    }

    // Fallbacks
    if let s = obj["prettyFormat"] as? String, let d = extractMMDDYYYY(from: s) { return d }
    if let t = obj["text"] as? String, let d = extractMMDDYYYY(from: t) { return d }
    return nil
}

/// Build the button title = "<cleanText> — <prettyFormat>"
/// cleanText = `text` with any parenthetical "(…)" removed.
func appointmentButtonTitleForQID(_ answers: [String: Any], qid: String) -> String? {
    guard let obj = answers[qid] as? [String: Any] else { return nil }
    let rawText = (obj["text"] as? String) ?? ""
    let pretty  = (obj["prettyFormat"] as? String) ?? ""

    let cleanText = rawText.replacingOccurrences(of: #"\s*\(.*?\)"#,
                                                 with: "",
                                                 options: .regularExpression)

    let left = cleanText.isEmpty ? "Session" : cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
    let right = pretty.trimmingCharacters(in: .whitespacesAndNewlines)

    return right.isEmpty ? left : "\(left) — \(right)"
}

// MARK: - Small date helpers

/// Accepts "YYYY-MM-DD" or "MM/DD/YYYY" and returns "MM/DD/YYYY".
func normalizeDateString(_ raw: String) -> String {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    // Already M/D/YYYY or MM/DD/YYYY → pad to 2/2/4
    if let m = s.range(of: #"(?<!\d)(\d{1,2})/(\d{1,2})/(\d{4})(?!\d)"#, options: .regularExpression) {
        let sub = String(s[m])
        let parts = sub.split(separator: "/").map { String($0) }
        if parts.count == 3,
           let mm = Int(parts[0]), let dd = Int(parts[1]), let yyyy = Int(parts[2]) {
            return String(format: "%02d/%02d/%04d", mm, dd, yyyy)
        }
    }

    // YYYY-MM-DD
    if let m = s.range(of: #"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"#, options: .regularExpression) {
        let sub = String(s[m])
        let parts = sub.split(separator: "-").map { String($0) }
        if parts.count == 3,
           let yyyy = Int(parts[0]), let mm = Int(parts[1]), let dd = Int(parts[2]) {
            return String(format: "%02d/%02d/%04d", mm, dd, yyyy)
        }
    }
    return s
}

/// Try to pull MM/DD/YYYY out of a free-form string
func extractMMDDYYYY(from raw: String) -> String? {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.range(of: #"(?<!\d)(\d{1,2})/(\d{1,2})/(\d{4})(?!\d)"#, options: .regularExpression) != nil {
        return normalizeDateString(s)
    }
    if let ymd = s.range(of: #"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"#, options: .regularExpression) {
        return normalizeDateString(String(s[ymd]))
    }
    return nil
}
