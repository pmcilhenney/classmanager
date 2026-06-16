//
//  Student.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/29/25.
//
import Foundation

struct Student: Identifiable, Codable {
    var id = UUID()

    // Identity
    var firstName: String
    var lastName: String
    var email: String
    var phone: String
    var dobPretty: String?
    var dobISO: String?

    // OEMS
    var njOemsId: String?

    // Address
    var addressLine1: String
    var addressLine2: String
    var city: String
    var state: String
    var postal: String

    // Course Info (2.0)
    var courseName: String?
    var courseDate: String?
    var courseTime: String?
    var courseId: String?
    var ceuValue: String?
    var connectedCategories: [String]?
    var courseDescription: String?
    var courseImageURL: String?  // NEW: Course image URL from JotForm product
    var courseLocation: String?  // NEW: Course location from registration (QID 46)

    // Registration source (optional)
    var submissionId: String?
    var formId: String?
}
