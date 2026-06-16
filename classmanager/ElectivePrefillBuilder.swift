//
//  ElectivePrefillBuilder.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/29/25.
//
import Foundation
import CoreLocation

// MARK: - ElectiveMeta model (context for elective course)
struct ElectiveMeta {
    let courseTitle: String
    let courseId: String
    let ceuValue: String?
    let courseStart: String?
    let courseEnd: String?
    let date: String?
    let birthdate: String?
}

// MARK: - Location → Address helper
private final class ElectiveLocationAddressProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((String?) -> Void)?

    func getCurrentAddress(completion: @escaping (String?) -> Void) {
        self.completion = completion
        manager.delegate = self

        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            completion?(nil)
            return
        }

        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let self = self else { return }
            let p = placemarks?.first

            var parts: [String] = []
            if let street = p?.thoroughfare { parts.append(street) }
            if let city = p?.locality { parts.append(city) }
            if let state = p?.administrativeArea { parts.append(state) }
            if let zip = p?.postalCode { parts.append(zip) }

            let addr = parts.joined(separator: ", ")
            self.completion?(addr.isEmpty ? nil : addr)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil)
    }
}

// MARK: - Build prefilled URL for Elective Form
struct ElectivePrefillBuilder {
    @MainActor
    static func makePrefillURL(
        for attendee: RosterAttendee,
        jotform: JotFormClient,
        lastURL: URL?
    ) async throws -> URL {
        let config = AppConfig.fromPlist()

        // Build meta from attendee and current date
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MM/dd/yyyy"
        let today = df.string(from: Date())

        let meta = ElectiveMeta(
            courseTitle: attendee.courseType,
            courseId: attendee.courseId ?? "",
            ceuValue: attendee.ceuValue,
            courseStart: nil,
            courseEnd: nil,
            date: today,
            birthdate: attendee.dob
        )

        guard let url = makeURL(config: config, attendee: attendee, meta: meta) else {
            throw URLError(.badURL)
        }
        return url
    }

    static func makeURL(
        config: AppConfig,
        attendee: RosterAttendee,
        meta: ElectiveMeta
        
    ) -> URL? {

        var comps = URLComponents(string: "https://form.jotform.com/\(config.electiveFormId)")
        var items: [URLQueryItem] = []

        // Name fields
        items.append(URLQueryItem(name: "name[first]", value: attendee.firstName))
        items.append(URLQueryItem(name: "name[last]",  value: attendee.lastName))

        // Email
        items.append(URLQueryItem(name: "email", value: attendee.email))

        // OEMS ID
        items.append(URLQueryItem(name: "typeA", value: attendee.oemsId))

        // Course title & ID
        items.append(URLQueryItem(name: "courseTitle", value: meta.courseTitle))
        items.append(URLQueryItem(name: "courseId",    value: meta.courseId))

        // CEU Value (Q12 "ceuValue")
        if let c = meta.ceuValue, !c.isEmpty {
            items.append(URLQueryItem(name: "ceuValue", value: c))
        }

        // Status (Q8 "status") – hard-coded to "2"
        items.append(URLQueryItem(name: "status", value: "2"))

        // Course Location (Q13 "courseLocation")
        items.append(URLQueryItem(name: "courseLocation", value: attendee.courseLocation))

        // Optional dates – JotForm date widgets need [month]/[day]/[year]
        if let b = meta.birthdate {
            addDateQueryItems(baseName: "birthdate", raw: b, to: &items)
        }
        if let d = meta.date {
            addDateQueryItems(baseName: "date", raw: d, to: &items)
        }

        // Leave courseStart / courseEnd as plain text (if you’re using them)
        if let s = meta.courseStart {
            items.append(URLQueryItem(name: "courseStart", value: s))
        }
        if let e = meta.courseEnd {
            items.append(URLQueryItem(name: "courseEnd", value: e))
        }

        // Flag so JotForm can hide fields when loaded from the app
        items.append(URLQueryItem(name: "prefillapp", value: "1"))
        comps?.queryItems = items

        return comps?.url
    }

        // MARK: - Helper: push JotForm date[month]/[day]/[year] style params
        private static func addDateQueryItems(
            baseName: String,
            raw: String,
            to items: inout [URLQueryItem]
        ) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return }

            func push(m: String, d: String, y: String) {
                items.append(URLQueryItem(name: "\(baseName)[month]", value: m))
                items.append(URLQueryItem(name: "\(baseName)[day]",   value: d))
                items.append(URLQueryItem(name: "\(baseName)[year]",  value: y))
            }

            // Try simple MM/DD/YYYY or MM-DD-YYYY or YYYY-MM-DD
            let separators: [Character] = ["/", "-"]
            if let sep = separators.first(where: { trimmed.contains($0) }) {
                let parts = trimmed.split(separator: sep).map { String($0) }
                if parts.count == 3 {
                    if parts[0].count == 4 {
                        // YYYY-MM-DD
                        let y = parts[0]
                        let m = parts[1]
                        let d = parts[2]
                        push(m: m, d: d, y: y)
                        return
                    } else {
                        // MM-DD-YYYY or MM/DD/YYYY
                        let m = parts[0]
                        let d = parts[1]
                        let y = parts[2]
                        push(m: m, d: d, y: y)
                        return
                    }
                }
            }

            // Try "Month d, yyyy" (e.g. January 1, 2026)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMMM d, yyyy"
            if let date = formatter.date(from: trimmed) {
                let cal = Calendar(identifier: .gregorian)
                let comps = cal.dateComponents([.year, .month, .day], from: date)
                if let y = comps.year, let m = comps.month, let d = comps.day {
                    push(
                        m: String(format: "%02d", m),
                        d: String(format: "%02d", d),
                        y: String(y)
                    )
                    return
                }
            }

            // If we can't parse, we silently skip
        }
        
    }
    

