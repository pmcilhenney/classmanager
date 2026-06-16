import Foundation

// MARK: - Models

// NOTE: This is the single source of truth for RosterAttendee.
struct RosterAttendee: Identifiable, Codable, Equatable {
    var id: String { submissionId }
    let submissionId: String

    var firstName: String
    var lastName: String
    var email: String
    var oemsId: String

    /// Pretty label like "Refresher A" (selected after scan if multiple)
    var courseType: String
    /// "MM/DD/YYYY" string
    var courseDate: String?
    /// From lookup form (QID 5)
    var courseId: String?
    /// CEU value parsed from registration product description
    var ceuValue: String?
    /// Product connected categories (e.g. ["2002"]) from the registration product
    var productCategories: [String]?
    /// From OEMS lookup (QID 21)
    var dob: String?
    /// Course image URL from JotForm product (NEW) - store as String to avoid cross-file type mismatch
    var courseImageURL: String?
    /// Course location from registration (QID 46)
    var courseLocation: String?

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
}
