//
//  TARecord.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/7/25.
//

import Foundation

/// Single source of truth for the Time & Attendance payload (QIDs are from your T&A form).
/// Keep this file; do not redeclare TARecord anywhere else.
struct TARecord {
    // Q3 First Name, Q5 Last Name, Q6 OEMS ID
    let q3_firstName:  String
    let q5_lastName:   String
    let q6_oemsId:     String

    // Q7 Course ID (optional), Q8 Course Type (Refresher A/B/C)
    let q7_courseId:   String?
    let q8_courseType: String

    // Q12 In/Out ("Check-In" / "Check-Out")
    let q12_inOut:     String

    // Q10 Date/Time (MM/dd/yyyy HH:mm), Q16 Course Date (MM/dd/yyyy), Q22 DOB (optional)
    let q10_date:      String
    let q16_courseDate:String?
    let q22_dob:       String?
}

extension TARecord {
    /// Convert to JotForm submission field map: submission[qid]=value
    var asFields: [String:String] {
        var f: [String:String] = [
            "3":  q3_firstName,
            "5":  q5_lastName,
            "6":  q6_oemsId,
            "8":  q8_courseType,
            "12": q12_inOut,
            "10": q10_date
        ]
        if let v = q7_courseId,    !v.isEmpty { f["7"]  = v }
        if let v = q16_courseDate, !v.isEmpty { f["16"] = v }
        if let v = q22_dob,        !v.isEmpty { f["22"] = v }
        return f
    }

    /// Convenience constructor from your Attendee + extras.
    /// - Parameters:
    ///   - attendee: Your selected attendee (must already have courseType and courseDate filled if applicable)
    ///   - inOut: "Check-In" or "Check-Out"
    ///   - nowString: "MM/dd/yyyy HH:mm" for Q10
    ///   - courseId: optional Course ID to include in Q7
    ///   - dob: optional DOB to include in Q22
    static func make(
        attendee: RosterAttendee,
        inOut: String,
        nowString: String,
        courseId: String? = nil,
        dob: String? = nil
    ) -> TARecord {
        TARecord(
            q3_firstName:   attendee.firstName,
            q5_lastName:    attendee.lastName,
            q6_oemsId:      attendee.oemsId,
            q7_courseId:    courseId,
            q8_courseType:  attendee.courseType,
            q12_inOut:      inOut,
            q10_date:       nowString,
            q16_courseDate: attendee.courseDate,
            q22_dob:        dob ?? attendee.dob
        )
    }
}
