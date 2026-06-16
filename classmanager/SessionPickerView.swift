import SwiftUI

/// Project-level model assumed:
/// struct RegistrationOption: Identifiable, Hashable {
///     var id: String { courseType + "|" + dateRaw }
///     let courseType: String   // e.g., "Refresher A (8AM - 5PM)" or already cleaned
///     let datePretty: String   // e.g., "Thursday, Nov 13, 2025 08:00-17:00"
///     let dateRaw: String      // "MM/DD/YYYY"
/// }

struct SessionPickerView: View {
    @Binding var isPresented: Bool
    let options: [RegistrationOption]
    let title: String
    let subtitle: String?
    /// If true: show only sessions whose dateRaw == today (America/New_York).
    /// If no sessions match today, we fall back to showing all options.
    let onlyShowToday: Bool
    let onPick: (RegistrationOption) -> Void

    var body: some View {
        NavigationStack {
            List {
                let shown = optionsToShow()
                if shown.isEmpty {
                    Text("No sessions found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(shown, id: \.id) { opt in
                        Button {
                            onPick(opt)
                            isPresented = false
                        } label: {
                            HStack {
                                Text(cleanCourseName(opt.courseType))
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(opt.datePretty)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(2)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                if let subtitle {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(title).font(.headline)
                            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filtering

    private func optionsToShow() -> [RegistrationOption] {
        guard onlyShowToday else { return options }
        let today = todayMMDDYYYY()
        let todays = options.filter { $0.dateRaw == today }
        return todays.isEmpty ? options : todays
    }

    // MARK: - Local helpers (scoped here to avoid collisions)

    private func todayMMDDYYYY() -> String {
        let tz = TimeZone(identifier: "America/New_York") ?? .current
        let df = DateFormatter()
        df.locale = .init(identifier: "en_US_POSIX")
        df.timeZone = tz
        df.dateFormat = "MM/dd/yyyy"
        return df.string(from: Date())
    }

    /// Remove trailing parenthetical, e.g., "Refresher C (8AM - 5PM)" -> "Refresher C"
    private func cleanCourseName(_ s: String) -> String {
        if let r = s.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            return String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}
