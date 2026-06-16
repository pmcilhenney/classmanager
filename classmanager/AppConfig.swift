import Foundation

/// Single source of truth for configuration pulled from Info.plist
struct AppConfig {
    // Branding
    let logoAsset: String

    // JotForm
    let jotformApiKey: String
    let checkinFormId: String
    let checkoutFormId: String
    let skillsFormId: String

    let courseLookupFormId: String
    let registrationFormId: String

    // 🔹 NEW: Elective CEU verification form
    let electiveFormId: String

    // FlexiQuiz...
    let flexiApiKey: String
    let flexiSharedSecret: String
    let flexiIssuer: String
    let flexiAudience: String
    let flexiEmailDomain: String
    let flexiMap: [String:String]

    // MARK: - Loader

    /// Load all keys from Info.plist (the app’s main bundle)
    static func fromPlist() -> AppConfig {
        let b = Bundle.main

        func s(_ key: String) -> String {
            (b.object(forInfoDictionaryKey: key) as? String) ?? ""
        }

        // Build the Flexi map (only keep non-empty)
        var map: [String:String] = [:]
        let courseKeys = ["RefresherA", "RefresherB", "RefresherC"]
        for ck in courseKeys {
            let key = "FLEXIQUIZ_MAP_\(ck)"
            let val = s(key)
            if !val.isEmpty { map[ck.replacingOccurrences(of: "Refresher", with: "Refresher ")] = val }
            // Also allow exact keys (no space) as a fallback
            if !val.isEmpty { map[ck] = val }
        }

        return AppConfig(
            logoAsset:              s("DEPT_LOGO_ASSET_NAME"),

            jotformApiKey:          s("JOTFORM_API_KEY"),
            checkinFormId:          s("JOTFORM_CHECKIN_FORM_ID"),
            checkoutFormId:         s("JOTFORM_CHECKOUT_FORM_ID"),
            skillsFormId:           s("SKILLS_VALIDATOR_FORM_ID"),
            courseLookupFormId:     s("JOTFORM_COURSE_LOOKUP_FORM_ID"),
            registrationFormId:     s("JOTFORM_REGISTRATION_FORM"),
            electiveFormId:         s("Elective_Form_ID"),          // 👈 uses your KV

            flexiApiKey:            s("FLEXIQUIZ_API_KEY"),
            flexiSharedSecret:      s("FLEXIQUIZ_SSO_SHARED_SECRET"),
            flexiIssuer:            s("FLEXIQUIZ_SSO_ISS"),
            flexiAudience:          s("FLEXIQUIZ_SSO_AUD"),
            flexiEmailDomain:       s("FLEXIQUIZ_SSO_EMAIL_DOMAIN"),
            flexiMap:               map
        )
    }
}
