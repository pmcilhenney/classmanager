import Foundation

// Intentionally minimal. All DTOs (RegistrationBundle, RegistrationOption, TARecord)
// and core logic now live in JotFormClient.swift to avoid duplicate-type errors.

extension JotFormClient {
    // If you want to keep an extension file in the project, you can add
    // tiny convenience wrappers here that call into the main client.
    //
    // For example:
    //
    // func registrationOptionsOnly(submissionId: String) async throws -> [RegistrationOption] {
    //     let bundle = try await fetchRegistrationBundle(
    //         submissionId: submissionId,
    //         registrationFormIdForDob: "",
    //         courseLookupFormId: ""
    //     )
    //     return bundle.options
    // }
}
