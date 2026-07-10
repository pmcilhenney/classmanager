import Foundation

enum AppDebugLog {
    static func log(_ message: @autoclosure () -> Any) {
        #if DEBUG
        print(message())
        #endif
    }
}
