// RegistrationOption.swift
import Foundation

// elsewhere in your project:
struct RegistrationOption: Identifiable, Codable, Hashable {
    var id: String { courseType + "|" + dateRaw }   // or datePretty – anything stable
    let courseType: String           // e.g. "Refresher A", "Refresher C (8AM - 5PM)" pre-clean
    let datePretty: String           // "Thursday, Nov 13, 2025 08:00-17:00"
    let dateRaw: String              // "MM/DD/YYYY" (parsed from appointment.date)
    var courseId: String? = nil
    var ceuValue: String? = nil
    var productCategories: [String]? = nil
    var courseImageURL: String? = nil
    var courseLocation: String? = nil
}
