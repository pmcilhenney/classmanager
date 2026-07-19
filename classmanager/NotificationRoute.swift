import Foundation

extension Notification.Name {
    static let classManagerNotificationTapped = Notification.Name("ClassManagerNotificationTapped")
}

struct ClassManagerNotificationRoute: Equatable {
    static let maxDirectRouteAge: TimeInterval = 6 * 60 * 60

    let type: String
    let event: String?
    let studentId: String?
    let classSessionId: String?
    let quizId: String?
    let responseId: String?
    let sentAt: Date

    init?(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return nil }
        self.type = type
        self.event = userInfo["event"] as? String
        self.studentId = userInfo["studentId"] as? String
        self.classSessionId = userInfo["classSessionId"] as? String
        self.quizId = userInfo["quizId"] as? String
        self.responseId = userInfo["responseId"] as? String
        self.sentAt = Self.date(from: userInfo["sentAt"] as? String)
            ?? Self.date(from: userInfo["completedAt"] as? String)
            ?? Date()
    }

    var isFresh: Bool {
        abs(sentAt.timeIntervalSinceNow) <= Self.maxDirectRouteAge
    }

    var isInstructorDashboardUpdate: Bool {
        type == "classmanager.instructor_dashboard_update"
    }

    var isStudentExamRoute: Bool {
        type == "classmanager.final_exam_result"
    }

    var isStudentCprRoute: Bool {
        type == "classmanager.cpr_card_update"
    }

    func matches(attendee: RosterAttendee) -> Bool {
        guard let studentId, let classSessionId else { return false }
        return studentId == ClassManagerAPIClient.studentId(for: attendee)
            && classSessionId == ClassManagerAPIClient.classSessionId(for: attendee.courseDate ?? attendee.submissionId)
    }

    private static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
