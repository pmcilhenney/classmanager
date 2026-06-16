//
//  FieldMap.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/7/25.
//

import Foundation

struct FieldMap: Codable, Equatable {
    var formId: String

    // Prefer a single fullname control when present; otherwise first/last
    var fullnameQID: String?
    var firstNameQID: String?
    var lastNameQID: String?

    var emailQID: String?
    var oemsQID: String?
    var courseTypeQID: String?
    var courseDateQID: String?

    // For T&A posts (IN / OUT)
    var inOutQID: String?
}
