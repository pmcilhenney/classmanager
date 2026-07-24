import SwiftUI
import WebKit

struct SkillsWebView: View {
    let url: URL
    var onSubmitted: (() -> Void)? = nil
    @State private var isLoading = true

    var body: some View {
        ZStack {
            WebView(url: url, isLoading: $isLoading, onSubmitted: onSubmitted)
                .ignoresSafeArea(edges: .bottom)

            if isLoading {
                LoadingSpinnerView()
                    .transition(.opacity)
            }
        }
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onSubmitted: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(initialURL: url, isLoading: $isLoading, onSubmitted: onSubmitted)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        isLoading = true
        let request = URLRequest(url: url)
        context.coordinator.loadedURL = url
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.loadedURL != url {
            isLoading = true
            let request = URLRequest(url: url)
            context.coordinator.loadedURL = url
            webView.load(request)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var loadedURL: URL
        var onSubmitted: (() -> Void)?
        private var didNotifySubmitted = false

        init(initialURL: URL, isLoading: Binding<Bool>, onSubmitted: (() -> Void)?) {
            loadedURL = initialURL
            _isLoading = isLoading
            self.onSubmitted = onSubmitted
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            notifyIfSubmitted(webView.url)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            notifyIfSubmitted(webView.url)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            notifyIfSubmitted(navigationAction.request.url)
            decisionHandler(.allow)
        }

        private func notifyIfSubmitted(_ url: URL?) {
            guard !didNotifySubmitted, let url else { return }
            let text = (url.absoluteString + " " + url.path + " " + (url.query ?? "")).lowercased()
            let submitted = text.contains("submissionid=")
                || text.contains("submission_id=")
                || text.contains("thank")
                || text.contains("success")
                || text.contains("submitted")
            guard submitted else { return }
            didNotifySubmitted = true
            DispatchQueue.main.async { [onSubmitted] in
                onSubmitted?()
            }
        }
    }
}
