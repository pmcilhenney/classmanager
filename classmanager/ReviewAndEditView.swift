import SwiftUI

struct ReviewAndEditView: View {
    let original: RosterAttendee
    let onDismiss: () -> Void
    let onAccept: (RosterAttendee) -> Void
    let onSaveEdits: (RosterAttendee) -> Void

    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var oems: String
    @State private var courseType: String

    init(
        original: RosterAttendee,
        onDismiss: @escaping () -> Void,
        onAccept: @escaping (RosterAttendee) -> Void,
        onSaveEdits: @escaping (RosterAttendee) -> Void
    ) {
        self.original = original
        self.onDismiss = onDismiss
        self.onAccept = onAccept
        self.onSaveEdits = onSaveEdits
        _firstName = State(initialValue: original.firstName)
        _lastName  = State(initialValue: original.lastName)
        _email     = State(initialValue: original.email)
        _oems      = State(initialValue: original.oemsId)
        _courseType = State(initialValue: original.courseType)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Attendee")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("NJ OEMS ID", text: $oems)
                    TextField("Course Type", text: $courseType)
                }
            }
            .navigationTitle("Review Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Edits") {
                        onSaveEdits(makeAttendee())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAccept(makeAttendee())
                } label: {
                    Text("Accept")
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

    private func makeAttendee() -> RosterAttendee {
        RosterAttendee(
            submissionId: original.submissionId,
            firstName: firstName,
            lastName: lastName,
            email: email,
            oemsId: oems,
            courseType: courseType,
            courseDate: original.courseDate,
            courseId: original.courseId,
            ceuValue: original.ceuValue,
            productCategories: original.productCategories,
            dob: original.dob,
            courseImageURL: original.courseImageURL,
            courseLocation: original.courseLocation  // FIX: Add courseLocation!
        )
    }
}
