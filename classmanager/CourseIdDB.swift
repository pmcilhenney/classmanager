import Foundation

/// Lightweight local lookup for mapping a course date + type to a Course ID.
///
/// MainMenuView calls `CourseIdDB.lookup(date:type:)` on appear to prefill the
/// course ID chip. Replace the in-memory map below with your real data source
/// (e.g. a persisted store, JSON file, or network fetch) as needed.
struct CourseIdDB {
    /// Internal in-memory map of (normalizedDate, normalizedCourseType) -> Course ID
    /// - Note: Keys are lowercased and trimmed; date strings should match the
    ///         same formatting used elsewhere in the app (e.g. "MM/dd/yyyy").
    private static let map: [String: [String: String]] = [
        // Example entries. You can add/remove as needed.
        // "MM/dd/yyyy": [ "refresher a": "COURSE-A-001" ]
        "01/15/2025": [
            "refresher a": "COURSE-A-001",
            "refresher b": "COURSE-B-002"
        ],
        "02/10/2025": [
            "refresher c": "COURSE-C-010"
        ]
    ]

    /// Returns a Course ID for the given date and course type, if available.
    /// - Parameters:
    ///   - date: A date string (e.g. "MM/dd/yyyy"). If nil/empty, returns nil.
    ///   - type: A course type string (e.g. "Refresher A (Something)").
    /// - Returns: A Course ID string or nil if no match is found.
    static func lookup(date: String?, type: String) -> String? {
        guard let rawDate = date?.trimmingCharacters(in: .whitespacesAndNewlines), !rawDate.isEmpty else {
            return nil
        }

        let normalizedDate = rawDate
        let normalizedType = cleanCourseName(type).lowercased()

        // Exact date match first
        if let typeMap = map[normalizedDate], let id = typeMap[normalizedType] {
            return id
        }

        // Optional: fallback by type only (latest available date for that type)
        // If you don't want this, remove this block.
        for (_, typeMap) in map {
            if let id = typeMap[normalizedType] {
                return id
            }
        }

        return nil
    }

    /// Matches MainMenuView.cleanCourseName behavior: strips parentheses and trims whitespace.
    private static func cleanCourseName(_ s: String) -> String {
        if let range = s.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            return String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}
