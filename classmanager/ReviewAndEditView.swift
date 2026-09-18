import SwiftUI

struct ReviewAndEditView: View {
    let original: RosterAttendee
    let onDismiss: () -> Void
    let onAccept: (RosterAttendee) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Attendee")) {
                    LabeledContent("Name", value: original.fullName)
                    LabeledContent("Email", value: original.email)
                    LabeledContent("NJ OEMS ID", value: original.oemsId)
                    LabeledContent("Course", value: original.courseType)
                }
            }
            .navigationTitle("Review Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Rescan Badge", action: onDismiss)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAccept(original)
                } label: {
                    Text("Confirm My Registration")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.95))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding()
                }
            }
        }
    }

}
