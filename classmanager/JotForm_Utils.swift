import Foundation

/// Small, safe helpers used across the app.
/// NOTE: do NOT define `nowForQ10()` here — it lives on `JotFormClient`.
enum JotFormUtils {

    /// Returns the date-only portion of strings like "MM/DD/YYYY HH:mm" -> "MM/DD/YYYY"
    static func extractDatePart(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sp = trimmed.firstIndex(of: " ") { return String(trimmed[..<sp]) }
        return trimmed
    }

    /// URL-encodes a string for x-www-form-urlencoded bodies
    static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}
