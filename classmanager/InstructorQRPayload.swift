import Foundation

enum InstructorQRPayload {
    static func personId(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           components.host?.lowercased() == "records.gcemstrainingacademy.org",
           components.path == "/person-access",
           let personId = components.queryItems?.first(where: { $0.name == "person_id" })?.value,
           !personId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return personId.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}
