import Foundation
import Combine
import SwiftUI

/// ViewModel for MainMenuView - coordinates all actions and state
@MainActor
final class MainMenuViewModel: ObservableObject {
    
    // MARK: - Published State
    
    // Navigation
    @Published var showSkills: Bool = false
    @Published var skillsURL: URL?
    @Published var showQuizWorkspace: Bool = false

    // UI state
    @Published var busy: Bool = false
    @Published var toast: String?

    // Elective form presentation state
    @Published var electiveFormURL: URL? = nil
    @Published var showingElectiveForm: Bool = false
    @Published var electiveFormTitle: String = ""

    // NEW: Check-In/Out embedded form state
    @Published var showingCheckInOut: Bool = false
    @Published var checkInOutURL: URL?
    @Published var didCheckIn: Bool = false
    @Published var didCheckOut: Bool = false

    // Course Materials state
    @Published var materials: [(title: String, url: URL)] = []
    @Published var showingMaterials: Bool = false
    @Published var materialCandidates: [([String: Any], String)] = []
    @Published var showingMaterialsPicker: Bool = false

    // Currently selected PDF
    @Published var selectedMaterialURL: URL? = nil
    @Published var showingPDF: Bool = false

    // Time & Attendance / CloudKit state
    @Published var courseId: String = ""
    @Published var isPosting: Bool = false
    @Published var returnToScanner = false
    
    // View modes
    @Published var showingMaterialsList = false
    
    // PDF viewing
    @Published var selectedPDFURL: URL?
    @Published var selectedPDFTitle: String = ""
    
    
    // MARK: - Dependencies
    
    private let config: AppConfig
    private let attendee: RosterAttendee
    private let jotform: JotFormClient
    let progressStore: CKProgressStore
    let materialsManager: CourseMaterialsManager
    
    // MARK: - Initialization
    
    init(config: AppConfig, attendee: RosterAttendee, jotform: JotFormClient, flexi: FlexiQuizClient, progressStore: CKProgressStore) {
        self.config = config
        self.attendee = attendee
        self.jotform = jotform
        self.progressStore = progressStore
        
        // Initialize materials manager
        let materialsFormId = (Bundle.main.object(forInfoDictionaryKey: "COURSE_MATERIALS_ID") as? String) ?? ""
        self.materialsManager = CourseMaterialsManager(
            jotformApiKey: config.jotformApiKey,
            materialsFormId: materialsFormId
        )
        
        // Observe materials manager changes
        setupMaterialsObserver()
    }
    
    // MARK: - Materials Handling
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupMaterialsObserver() {
        // Sync materials and show list when loaded
        materialsManager.$materials
            .sink(receiveValue: { [weak self] (materials: [(title: String, url: URL)]) in
                self?.materials = materials
                if !materials.isEmpty {
                    self?.showingMaterialsList = true
                    self?.showingMaterialsPicker = false
                }
            })
            .store(in: &cancellables)
        
        // Sync candidates and show picker when available
        materialsManager.$materialCandidates
            .sink(receiveValue: { [weak self] (candidates: [([String: Any], String)]) in
                self?.materialCandidates = candidates
                if !candidates.isEmpty {
                    self?.showingMaterialsPicker = true
                    self?.showingMaterialsList = false
                }
            })
            .store(in: &cancellables)
        
        // Mirror loading state
        materialsManager.$isLoading
            .assign(to: &$busy)
        
        // Mirror error messages
        materialsManager.$errorMessage
            .compactMap { $0 }
            .assign(to: &$toast)
    }
    
    func loadCourseMaterials() {
        // Reset view states
        showingPDF = false
        showSkills = false
        showQuizWorkspace = false
        
        Task {
            await materialsManager.loadMaterials(for: attendee.courseType)
        }
    }
    
    func selectMaterialsCandidate(_ answers: [String: Any]) {
        materialsManager.selectCandidate(answers)
    }
    
    func openPDF(url: URL, title: String) {
        selectedPDFURL = url
        selectedPDFTitle = title
        showingMaterialsList = false
        showingPDF = true
    }
    
    func closePDF() {
        showingPDF = false
        selectedPDFURL = nil
        showingMaterialsList = true
    }
    
    // MARK: - Check In/Out
    
    func checkIn() {
        performCheckInOut("Check-In", formId: config.checkinFormId)
    }
    
    func checkOut() {
        performCheckInOut("Check-Out", formId: config.checkoutFormId)
    }
    
    private func performCheckInOut(_ action: String, formId: String) {
        busy = true
        isPosting = true
        
        Task {
            defer {
                busy = false
                isPosting = false
            }
            
            let df = DateFormatter()
            df.locale = .init(identifier: "en_US_POSIX")
            df.dateFormat = "MM/dd/yyyy HH:mm"
            let now = df.string(from: Date())
            
            var fields: [String: String] = [
                "3":  attendee.firstName,
                "5":  attendee.lastName,
                "6":  attendee.oemsId,
                "8":  cleanCourseName(attendee.courseType),
                "12": action,
                "10": now
            ]
            
            if let d = attendee.courseDate, !d.isEmpty {
                fields["16"] = d
            }
            if !courseId.isEmpty {
                fields["7"] = courseId
            }
            
            do {
                _ = try await jotform.postTimeAttendance(formId: formId, fields: fields)
                toast = "\(action) posted successfully."
                
                if action == "Check-In" {
                    progressStore.markCheckIn()
                    didCheckIn = true
                } else {
                    progressStore.markCheckOut()
                    didCheckOut = true
                }
            } catch {
                toast = "Failed to post \(action)."
            }
        }
    }
    
    // MARK: - Skills Validation
    
    func openSkills() {
        busy = true
        showQuizWorkspace = false
        showingMaterialsList = false
        showingMaterialsPicker = false
        showingPDF = false
        
        Task {
            defer { busy = false }
            
            guard !config.skillsFormId.isEmpty else {
                toast = "Missing Skills Form ID in configuration."
                return
            }
            
            guard var comps = URLComponents(string: "https://form.jotform.com/\(config.skillsFormId)") else {
                return
            }
            
            var items: [URLQueryItem] = []
            
            func add(_ name: String, _ value: String?) {
                guard let v = value, !v.isEmpty else { return }
                items.append(URLQueryItem(name: name, value: v))
            }
            
            add("name[first]", attendee.firstName)
            add("name[last]", attendee.lastName)
            add("oemsId", attendee.oemsId)
            if let courseDate = attendee.courseDate {
                add("courseDate", courseDate)
            }
            add("courseTitle", cleanCourseName(attendee.courseType))
            if !courseId.isEmpty {
                add("7", courseId)
            }
            
            comps.queryItems = items
            skillsURL = comps.url
            showSkills = true
            progressStore.markSkills()
        }
    }
    
    // MARK: - Quiz Workspace
    
    func openQuiz() {
        showQuizWorkspace = true
        showSkills = false
        showingMaterialsList = false
        showingMaterialsPicker = false
        showingPDF = false
        progressStore.markQuiz()
    }
    
    // MARK: - Helpers
    
    private func cleanCourseName(_ s: String) -> String {
        if let range = s.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) {
            return String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}
