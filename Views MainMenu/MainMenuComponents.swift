import SwiftUI

// MARK: - Chip Component

struct Chip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(.systemGray6)))
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let title: String
    let done: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                if done {
                    ZStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .accessibilityLabel("Completed")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - User Info Header Component

struct UserInfoHeader: View {
    let attendee: RosterAttendee
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.accentColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(attendee.firstName) \(attendee.lastName)")
                    .font(.headline)
                
                HStack(spacing: 6) {
                    if !attendee.oemsId.isEmpty {
                        Chip(text: "OEMS: \(attendee.oemsId)")
                    }
                    if let date = attendee.courseDate {
                        Chip(text: date)
                    }
                }
                if !attendee.courseType.isEmpty {
                    Chip(text: cleanCourseName(attendee.courseType))
                }
            }
        }
    }
    
    private func cleanCourseName(_ s: String) -> String {
        if let range = s.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            return String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Empty State Component

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.and.hand.point.up.left.filled")
                .font(.system(size: 48))
                .foregroundColor(.accentColor.opacity(0.7))
            
            Text("Select an action from the left menu")
                .font(.title3.weight(.semibold))
            
            Text("You can check in/out, validate skills, or open the mini-quiz workspace.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
    }
}

// MARK: - Scan QR Button Component

struct ScanQRButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                Text("Scan New QR Code")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.accentColor)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Course Materials Button Component

struct CourseMaterialsButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "books.vertical")
                Text("Course Materials")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor)
            )
            .foregroundColor(.white)
        }
    }
}

// MARK: - Preview Providers

#if DEBUG
struct Chip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            Chip(text: "OEMS: 123456")
            Chip(text: "12/07/2025")
            Chip(text: "EMT Refresher A")
        }
        .padding()
    }
}

struct ActionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            ActionButton(title: "Check In", done: false) {}
            ActionButton(title: "Check Out", done: true) {}
        }
        .padding()
    }
}
#endif
