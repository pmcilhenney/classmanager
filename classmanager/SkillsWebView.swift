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
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: Coordinator.messageHandlerName)
        contentController.addUserScript(WKUserScript(source: Coordinator.jotformSubmissionObserverScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.scrollView.keyboardDismissMode = .interactive
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

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.messageHandlerName)
        uiView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        static let messageHandlerName = "classmanagerJotform"
        static let jotformSubmissionObserverScript = """
        (function() {
          if (window.__classManagerJotformObserverInstalled) { return; }
          window.__classManagerJotformObserverInstalled = true;

          var didNotify = false;
          function normalizedText() {
            return ((document.body && document.body.innerText) || "").replace(/\\s+/g, " ").toLowerCase();
          }
          function looksSubmitted() {
            var href = String(window.location.href || "").toLowerCase();
            var text = normalizedText();
            return href.indexOf("/submit/") !== -1 ||
              href.indexOf("/thank") !== -1 ||
              href.indexOf("submit=success") !== -1 ||
              href.indexOf("submission_status=success") !== -1 ||
              text.indexOf("thank you") !== -1 ||
              text.indexOf("submission has been received") !== -1 ||
              text.indexOf("your submission has been received") !== -1;
          }
          function notify(reason) {
            if (didNotify || !looksSubmitted()) { return; }
            didNotify = true;
            try {
              window.webkit.messageHandlers.classmanagerJotform.postMessage({
                type: "classmanager.jotform.submitted",
                reason: reason,
                href: window.location.href,
                title: document.title || "",
                at: new Date().toISOString()
              });
            } catch (_) {}
          }
          function schedule(reason) {
            setTimeout(function() { notify(reason + ":1000"); }, 1000);
            setTimeout(function() { notify(reason + ":2500"); }, 2500);
            setTimeout(function() { notify(reason + ":5000"); }, 5000);
          }
          document.addEventListener("submit", function() { schedule("form-submit"); }, true);
          document.addEventListener("click", function(event) {
            var target = event.target;
            var text = "";
            while (target && target !== document.body) {
              text = String((target.innerText || target.value || target.getAttribute("aria-label") || "")).toLowerCase();
              if (text.indexOf("submit") !== -1) {
                schedule("submit-click");
                break;
              }
              target = target.parentElement;
            }
          }, true);
          if (document.body) {
            new MutationObserver(function() { notify("mutation"); }).observe(document.body, {
              childList: true,
              subtree: true,
              characterData: true
            });
          }
          schedule("initial");
        })();
        """

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

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.messageHandlerName else { return }
            notifySubmitted()
        }

        private func notifyIfSubmitted(_ url: URL?) {
            guard !didNotifySubmitted, let url else { return }
            let host = (url.host ?? "").lowercased()
            let path = url.path.lowercased()
            let query = (url.query ?? "").lowercased()
            let isJotform = host.contains("jotform.com")
            let submitted = isJotform && (
                path.contains("/submit/")
                    || path.contains("/thank")
                    || path.contains("/thank-you")
                    || query.contains("submit=success")
                    || query.contains("submission_status=success")
            )
            guard submitted else { return }
            notifySubmitted()
        }

        private func notifySubmitted() {
            guard !didNotifySubmitted else { return }
            didNotifySubmitted = true
            DispatchQueue.main.async { [onSubmitted] in
                onSubmitted?()
            }
        }
    }
}
