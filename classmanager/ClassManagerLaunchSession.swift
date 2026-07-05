import Foundation

enum ClassManagerLaunchSession {
    private static let lastQRScanKey = "classmanager.lastSuccessfulQRScanAt"
    private static let expirationInterval: TimeInterval = 12 * 60 * 60

    private static var easternCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return calendar
    }

    static func markScan(at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastQRScanKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: lastQRScanKey)
    }

    static func shouldResetActiveSession(now: Date = Date()) -> Bool {
        guard let lastScan = UserDefaults.standard.object(forKey: lastQRScanKey) as? Date else {
            return false
        }
        if now.timeIntervalSince(lastScan) >= expirationInterval {
            return true
        }
        return !easternCalendar.isDate(lastScan, inSameDayAs: now)
    }
}
