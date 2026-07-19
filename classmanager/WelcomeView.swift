import SwiftUI
import Foundation
import SafariServices

// MARK: - Layout helpers

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HeightReader<Content: View>: View {
    let content: () -> Content
    var body: some View {
        content()
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: HeightPreferenceKey.self, value: proxy.size.height)
                }
            )
    }
}

// MARK: - Local helpers

fileprivate func mmddyyyy(_ d: Date) -> String {
    let tz = TimeZone(identifier: "America/New_York") ?? .current
    let df = DateFormatter(); df.timeZone = tz; df.locale = .init(identifier: "en_US_POSIX")
    df.dateFormat = "MM/dd/yyyy"
    return df.string(from: d)
}

/// Remove trailing parenthetical, e.g., "Refresher C (8AM - 5PM)" -> "Refresher C"
/// BUT preserve leading course abbreviations like "(PEPP)" in "(PEPP) Pediatric Education..."
fileprivate func cleanCourseName(_ s: String) -> String {
    if let r = s.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
        let before = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        let after = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        if after.isEmpty && before.isEmpty {
            return s
        }
        if before.isEmpty || before.count < 5 {
            return s
        }
        return before
    }
    return s.trimmingCharacters(in: .whitespaces)
}

// MARK: - View

struct WelcomeView: View {
    let config: AppConfig
    let jotform: JotFormClient
    let flexi: FlexiQuizClient
    @Environment(\.scenePhase) private var scenePhase

    @State private var scanning = false
    @State private var fetched: RosterAttendee?
    @State private var showReview = false
    @State private var navigateToMain = false
    @State private var acceptedAttendee: RosterAttendee?
    @State private var instructorSession: ClassManagerAPIClient.InstructorScanResponse?
    @State private var errorText: String?
    @State private var busy = false

    // Session selection
    @State private var showSessionPicker = false
    @State private var sessionOptions: [RegistrationOption] = []
    @State private var isScanningBusy = false
    @State private var pendingNotificationRoute: ClassManagerNotificationRoute?

    // 2nd-pass booster
    @State private var lastSubmissionId: String = ""
    @State private var lastPickedOption: RegistrationOption?

    // Registration-specific state
    @State private var registrationProductMap: [String: [String: Any]] = [:]
    @State private var lastScanWasRegistration: Bool = false
    
    // Upcoming events
    @StateObject private var eventsManager: UpcomingEventsManager
    @State private var showRegistrationSheet = false

    @State private var maxEventCardHeight: CGFloat = 0

    init(config: AppConfig, jotform: JotFormClient, flexi: FlexiQuizClient) {
        self.config = config
        self.jotform = jotform
        self.flexi = flexi
        _eventsManager = StateObject(wrappedValue: UpcomingEventsManager(jotformApiKey: config.jotformApiKey))
    }

    var body: some View {
        Group {
            if let instructorSession {
                InstructorDashboardView(
                    config: config,
                    jotform: jotform,
                    flexi: flexi,
                    instructor: instructorSession.instructor,
                    initialCourse: instructorSession.defaultCourse,
                    courses: instructorSession.courses,
                    initialAttendance: instructorSession.attendance,
                    initialNotificationRoute: pendingNotificationRoute
                )
            } else if navigateToMain, let att = acceptedAttendee {
                // Main 2-panel view
                MainMenuView(
                    config: config,
                    attendee: att,
                    jotform: jotform,
                    flexi: flexi,
                    onRequestLaunchReset: resetActiveSessionForNewClass,
                    initialNotificationRoute: pendingNotificationRoute
                )
            } else {
                // Welcome / scanning UI
                ScrollView {
                    VStack(spacing: 24) {
                        if let img = UIImage(named: config.logoAsset) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .accessibilityHidden(true)
                                .padding(.top, 20)
                        }

                        Text("Welcome to the GCEMS Academy")
                            .font(.title).bold()

                        Text("Tap the button below to scan your QR code and get started.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button {
                            scanning = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 24, weight: .semibold))
                                Text("Scan QR Code")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 50)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.accentColor)
                            )
                            .foregroundColor(.white)
                        }
                        .padding(.top, 8)
                        
                        // MARK: - Upcoming Events Section
                        if !eventsManager.events.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Upcoming Training")
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(eventsManager.events) { event in
                                            HeightReader {
                                                EventCard(event: event) {
                                                    showRegistrationSheet = true
                                                }
                                                .background(Color.clear)
                                            }
                                            .frame(height: maxEventCardHeight > 0 ? maxEventCardHeight : nil)
                                        }
                                    }
                                    .onPreferenceChange(HeightPreferenceKey.self) { value in
                                        if value > maxEventCardHeight {
                                            maxEventCardHeight = value
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 16)
                        } else if eventsManager.isLoading {
                            LoadingSpinnerView()
                                .padding()
                        }
                    }
                    .padding(.bottom, 40)
                }
                .overlay { if busy { LoadingSpinnerView() } }
                .onAppear {
                    Task {
                        await eventsManager.loadUpcomingEvents(limit: 5)
                    }
                }
                .onChange(of: eventsManager.events.map { $0.id }) { _ in
                    maxEventCardHeight = 0
                }
            }
        }
        .sheet(isPresented: $scanning) {
            QRScannerView { code in
                scanning = false
                Task { await handleScan(code) }
            }
        }
        .sheet(isPresented: $showSessionPicker) {
            SessionPickerView(
                isPresented: $showSessionPicker,
                options: sessionOptions,
                title: "Select Course",
                subtitle: lastScanWasRegistration ? "Choose which course to register for today." : "Choose which refresher date to use.",
                onlyShowToday: false,
                onPick: { option in
                    lastPickedOption = option
                    Task { await finalizeSelection() }
                }
            )
        }
        .sheet(isPresented: $showReview) {
            if let attendee = fetched {
                ReviewAndEditView(
                    original: attendee,
                    onDismiss: { showReview = false },
                    onAccept: { accepted in
                        ClassManagerLaunchSession.markScan()
                        acceptedAttendee = accepted
                        showReview = false
                        navigateToMain = true
                    },
                    onSaveEdits: { _ in }
                )
            }
        }
        .sheet(isPresented: $showRegistrationSheet) {
            RegistrationWebSheet(url: URL(string: "https://pci.jotform.com/form/251265925097060")!)
        }
        .alert(errorText ?? "", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        }
        .onAppear(perform: expireActiveSessionIfNeeded)
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                expireActiveSessionIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .classManagerNotificationTapped)) { notification in
            guard let route = ClassManagerNotificationRoute(userInfo: notification.userInfo ?? [:]) else { return }
            handleTappedNotification(route)
        }
    }

    // MARK: - Scan handler

    private func resetActiveSessionForNewClass() {
        scanning = false
        fetched = nil
        showReview = false
        navigateToMain = false
        acceptedAttendee = nil
        instructorSession = nil
        errorText = nil
        busy = false
        showSessionPicker = false
        sessionOptions = []
        isScanningBusy = false
        lastSubmissionId = ""
        lastPickedOption = nil
        registrationProductMap = [:]
        lastScanWasRegistration = false
        pendingNotificationRoute = nil
    }

    private func expireActiveSessionIfNeeded() {
        guard ClassManagerLaunchSession.shouldResetActiveSession() else { return }
        ClassManagerLaunchSession.clear()
        resetActiveSessionForNewClass()
    }

    private func handleScan(_ qrString: String) async {
        let submissionId = qrString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submissionId.isEmpty, !isScanningBusy else { return }

        if let personId = InstructorQRPayload.personId(from: submissionId) {
            await handleInstructorScan(personId: personId)
            return
        }

        isScanningBusy = true
        await MainActor.run {
            errorText = nil
            sessionOptions = []
            fetched = nil
            lastPickedOption = nil
            showReview = false
            showSessionPicker = false
            busy = true
        }

        defer {
            Task { @MainActor in
                busy = false
                isScanningBusy = false
            }
        }

        do {
            let lookup = try await ClassManagerAPIClient.shared.lookupSession(submissionId: submissionId)
            let attendee = lookup.attendee
            lastSubmissionId = submissionId
            ClassManagerLaunchSession.markScan()

            if let route = pendingNotificationRoute, route.matches(attendee: attendee) {
                await MainActor.run {
                    self.fetched = attendee
                    self.acceptedAttendee = attendee
                    self.showReview = false
                    self.showSessionPicker = false
                    self.navigateToMain = true
                }
                return
            } else if pendingNotificationRoute != nil {
                await MainActor.run {
                    pendingNotificationRoute = nil
                }
            }

            if lookup.options.count > 1 {
                await MainActor.run {
                    self.fetched = attendee
                    self.registrationProductMap = [:]
                    self.sessionOptions = lookup.options
                    self.lastScanWasRegistration = lookup.formType == "registration"
                    self.showSessionPicker = true
                }
            } else {
                await MainActor.run {
                    self.fetched = attendee
                    self.showReview = true
                }
            }
        } catch {
            await MainActor.run {
                errorText = "Could not load registration data. Please try again."
            }
        }
    }

    private func handleInstructorScan(personId: String) async {
        guard !isScanningBusy else { return }

        isScanningBusy = true
        await MainActor.run {
            errorText = nil
            busy = true
        }
        defer {
            Task { @MainActor in
                busy = false
                isScanningBusy = false
            }
        }

        do {
            let session = try await ClassManagerAPIClient.shared.scanInstructor(personId: personId)
            await MainActor.run {
                ClassManagerLaunchSession.markScan()
                instructorSession = session
                acceptedAttendee = nil
                navigateToMain = false
            }
        } catch {
            await MainActor.run {
                errorText = "Could not start instructor dashboard."
            }
        }
    }

    private func handleTappedNotification(_ route: ClassManagerNotificationRoute) {
        guard route.isStudentExamRoute else { return }

        if route.isFresh, let acceptedAttendee, route.matches(attendee: acceptedAttendee) {
            pendingNotificationRoute = route
            navigateToMain = true
            return
        }

        pendingNotificationRoute = route
        navigateToMain = false
        acceptedAttendee = nil
        fetched = nil
        showReview = false
        showSessionPicker = false
        scanning = true
    }

    // MARK: - Second pass after user picks a session

    private func finalizeSelection() async {
        guard !lastSubmissionId.isEmpty, let picked = lastPickedOption else { return }
        
        await MainActor.run { busy = true }
        defer { Task { @MainActor in busy = false } }

        var attendee = fetched ?? RosterAttendee(
            submissionId: lastSubmissionId,
            firstName: "",
            lastName: "",
            email: "",
            oemsId: "",
            courseType: picked.courseType,
            courseDate: picked.dateRaw,
            courseId: nil,
            ceuValue: nil,
            productCategories: nil,
            dob: nil,
            courseImageURL: nil,
            courseLocation: nil
        )

        attendee.courseType = picked.courseType
        attendee.courseDate = picked.dateRaw
        attendee.courseId = picked.courseId
        attendee.ceuValue = picked.ceuValue
        attendee.productCategories = picked.productCategories
        attendee.courseImageURL = picked.courseImageURL
        attendee.courseLocation = picked.courseLocation

        await MainActor.run {
            self.fetched = attendee
            self.showReview = true
        }
    }

    // MARK: - Registration product parsing

    private func parseRegistrationProducts(from rawObj: [String: Any]) -> [(RegistrationOption, [String: Any])] {
        guard
            let content = rawObj["content"] as? [String: Any],
            let answers = content["answers"] as? [String: Any],
            let qid39 = answers["39"] as? [String: Any],
            let products = qid39["products"] as? [[String: Any]]
        else { return [] }

        var out: [(RegistrationOption, [String: Any])] = []

        for prod in products {
            let name: String
            if let n = prod["name"] as? String, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = n
            } else if let t = prod["title"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = t
            } else if let l = prod["label"] as? String, !l.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = l
            } else if let txt = prod["text"] as? String, !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = txt
            } else {
                name = "Unnamed Course"
            }

            let description = (prod["description"] as? String) ?? ""
            let (dateStr, _, courseId, _) = parseDescriptionFields(from: description)
            let pretty = description.trimmingCharacters(in: .whitespacesAndNewlines)
            let dateRaw = dateStr ?? ""

            let opt = RegistrationOption(
                courseType: cleanCourseName(name),
                datePretty: pretty,
                dateRaw: dateRaw
            )
            out.append((opt, prod))
        }

        return out
    }

    // MARK: - Refresher appointment parsing

    private func parseRefresherAppointmentOptions(from rawObj: [String: Any]) -> [RegistrationOption] {
        guard
            let content = rawObj["content"] as? [String: Any],
            let answers = content["answers"] as? [String: Any]
        else { return [] }

        var out: [RegistrationOption] = []

        // Q60, Q74, Q77 = Refresher A, B, C appointments
        let appointments = [
            ("60", "Refresher A"),
            ("74", "Refresher B"),
            ("77", "Refresher C")
        ]

        for (qid, label) in appointments {
            if let field = answers[qid] as? [String: Any],
               let rawDate = field["answer"] as? String,
               !rawDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                let dateOnly = extractDatePart(rawDate)
                let opt = RegistrationOption(
                    courseType: label,
                    datePretty: rawDate,
                    dateRaw: dateOnly ?? rawDate
                )
                out.append(opt)
            }
        }

        return out
    }

    private func extractDatePart(_ s: String) -> String? {
        // Extract "MM/DD/YYYY" from strings like "January 15, 2026 (08:00-17:00)"
        if let match = s.range(of: #"\d{1,2}/\d{1,2}/\d{4}"#, options: .regularExpression) {
            return String(s[match])
        }
        
        // Try to parse long-form dates
        if let parsed = parseDateStringToMMDDYYYY(s) {
            return parsed
        }
        
        return nil
    }

    // MARK: - Description field parsing

    private func parseDescriptionFields(from desc: String) -> (String?, String?, String?, String?) {
        var date: String?
        var time: String?
        var id: String?
        var ceu: String?

        let lines = desc.components(separatedBy: .newlines)
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if line.starts(with: "Date:") {
                let after = line.replacingOccurrences(of: "Date:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = parseDateStringToMMDDYYYY(after) {
                    date = parsed
                }
            } else if line.starts(with: "Time:") {
                time = line.replacingOccurrences(of: "Time:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.starts(with: "Course ID:") {
                id = line.replacingOccurrences(of: "Course ID:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.range(of: #"^CEU|CEUs?:"#, options: .regularExpression) != nil {
                if let colon = line.firstIndex(of: ":") {
                    let val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !val.isEmpty { ceu = val }
                }
            }
        }

        return (date, time, id, ceu)
    }

    private func parseDateStringToMMDDYYYY(_ s: String) -> String? {
        var candidate = s
        if let idx = candidate.firstIndex(of: "(") { candidate = String(candidate[..<idx]) }
        candidate = candidate.replacingOccurrences(of: "&", with: ",")

        let yearRegex = try? NSRegularExpression(pattern: "(19|20)\\d{2}")
        let monthDayRegex = try? NSRegularExpression(pattern: "(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2}", options: .caseInsensitive)

        if let yrMatch = yearRegex?.firstMatch(in: candidate, options: [], range: NSRange(candidate.startIndex..., in: candidate)),
           let monthMatch = monthDayRegex?.firstMatch(in: candidate, options: [], range: NSRange(candidate.startIndex..., in: candidate)) {
            let yr = (candidate as NSString).substring(with: yrMatch.range)
            let md = (candidate as NSString).substring(with: monthMatch.range)
            candidate = "\(md), \(yr)"
        }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let patterns = ["MMMM d, yyyy", "MMM d, yyyy", "MMMM d yyyy", "MMM d yyyy"]
        
        for p in patterns {
            df.dateFormat = p
            if let d = df.date(from: candidate.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return mmddyyyy(d)
            }
        }

        return nil
    }
}

// MARK: - Event Card Component

struct EventCard: View {
    let event: UpcomingEvent
    let onRegister: () -> Void

    private func twoLineDateString(from formatted: String) -> String? {
        // Try to parse common formats like "MMMM d, yyyy" or "MMM d, yyyy" and output:
        // "EEEE\nMMMM d yyyy" (no comma)
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        let inputFormats = ["MMMM d, yyyy", "MMM d, yyyy", "MMMM d yyyy", "MMM d yyyy", "M/d/yyyy", "MM/dd/yyyy"]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        for fmt in inputFormats {
            df.dateFormat = fmt
            if let date = df.date(from: trimmed) {
                let weekdayFmt = DateFormatter()
                weekdayFmt.locale = df.locale
                weekdayFmt.timeZone = df.timeZone
                weekdayFmt.dateFormat = "EEEE"
                let dateFmt = DateFormatter()
                dateFmt.locale = df.locale
                dateFmt.timeZone = df.timeZone
                dateFmt.dateFormat = "MMMM d yyyy"
                let weekday = weekdayFmt.string(from: date)
                let day = dateFmt.string(from: date)
                return "\(weekday)\n\(day)"
            }
        }
        // Fallback: if there's a comma, split into two lines and remove the comma
        if let commaIndex = trimmed.firstIndex(of: ",") {
            let first = String(trimmed[..<commaIndex]).trimmingCharacters(in: .whitespaces)
            let second = String(trimmed[trimmed.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
            if !first.isEmpty, !second.isEmpty {
                return "\(first)\n\(second)"
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Course Icon
            if let imageURLString = event.imageURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        LoadingSpinnerView()
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accentColor.opacity(0.1))
                            Image(systemName: "book.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                        }
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // Fallback icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(0.1))
                    Image(systemName: "book.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
            
            // Course Name
            Text(event.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 200)
            
            // Date
            Group {
                if let twoLineDate = twoLineDateString(from: event.formattedDate) {
                    Text(twoLineDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else {
                    Text(event.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(width: 200)
            
            // Register Button
            Button(action: onRegister) {
                Text("Register")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .frame(width: 220)
    }
}

// MARK: - Registration Web Sheet

struct RegistrationWebSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
