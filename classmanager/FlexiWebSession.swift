import WebKit

enum FlexiWebSession {
    /// Shared pool so FlexiQuiz cookies/sessions persist (and fewer blank loads)
    static let sharedPool = WKProcessPool()
}
