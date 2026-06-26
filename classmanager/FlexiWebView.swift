//
//  FlexiQuizWebView.swift
//  classmanager
//

import SwiftUI
import WebKit

struct LegacyFlexiQuizWebView: View {
    let quiz: QuizInfo
    let attendee: RosterAttendee
    let onComplete: () -> Void
    let onBack: () -> Void
    
    @State private var isLoading = true
    @State private var hasAutoFilled = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back to Quizzes")
                    }
                    .font(.system(size: 16, weight: .medium))
                }
                
                Spacer()
                
                Text(quiz.title)
                    .font(.headline)
                
                Spacer()
                
                Button(action: onComplete) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            ZStack {
                LegacyFlexiQuizWebViewRepresentable(
                    url: quiz.url,
                    attendee: attendee,
                    isLoading: $isLoading,
                    hasAutoFilled: $hasAutoFilled
                )
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading quiz...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// Simple generic WebView used by multiple workspace views
struct FlexiWebView: View {
    let url: URL
    @Binding var lastURL: URL?
    @Binding var loading: Bool
    var onResultDetected: (() -> Void)?

    var body: some View {
        FlexiSimpleWebViewRepresentable(
            url: url,
            lastURL: $lastURL,
            isLoading: $loading,
            onResultDetected: onResultDetected
        )
            .edgesIgnoringSafeArea(.all)
    }
}

struct FlexiSimpleWebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var lastURL: URL?
    @Binding var isLoading: Bool
    var onResultDetected: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // If the incoming URL is different, load it
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: FlexiSimpleWebViewRepresentable
        private var hasReportedResult = false

        init(_ parent: FlexiSimpleWebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                if webView.url != nil {
                    self.parent.isLoading = false
                }
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.lastURL = webView.url
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.lastURL = webView.url
            }
            detectResults(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        private func detectResults(_ webView: WKWebView) {
            guard !hasReportedResult else { return }
            let detectResultsJS = #"""
            (function() {
                try {
                    var marker = "6e0a9b0f6f6d5a0d2d3d2c88c97e7b1a";
                    var html = (document.documentElement && document.documentElement.outerHTML) ? document.documentElement.outerHTML : '';
                    var url = (window.location && window.location.href) ? window.location.href : '';
                    var lowerUrl = url.toLowerCase();
                    var markerFound = (html.indexOf(marker) !== -1) || (url.indexOf(marker) !== -1) || lowerUrl.indexOf('/sc/rt') !== -1;
                    return JSON.stringify({found: markerFound});
                } catch(e) {
                    return JSON.stringify({found: false});
                }
            })();
            """#

            webView.evaluateJavaScript(detectResultsJS) { result, _ in
                guard
                    let json = result as? String,
                    let data = json.data(using: .utf8),
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let found = object["found"] as? Bool,
                    found
                else { return }

                DispatchQueue.main.async {
                    guard !self.hasReportedResult else { return }
                    self.hasReportedResult = true
                    self.parent.isLoading = false
                    self.parent.onResultDetected?()
                }
            }
        }
    }
}

struct LegacyFlexiQuizWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let attendee: RosterAttendee
    @Binding var isLoading: Bool
    @Binding var hasAutoFilled: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LegacyFlexiQuizWebViewRepresentable

        init(_ parent: LegacyFlexiQuizWebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.getElementById('registerParticipantButton') != null") { result, _ in
                if let isRegPage = result as? Bool, isRegPage, !self.parent.hasAutoFilled {
                    self.autoFillRegistration(webView)
                } else {
                    DispatchQueue.main.async {
                        self.parent.isLoading = false
                    }
                }
            }
        }
        
        private func autoFillRegistration(_ webView: WKWebView) {
            let js = """
            (function() {
                try {
                    document.getElementById('62efdd5c-b397-4c79-86f2-849d9572a9e5').value = '\(parent.attendee.firstName)';
                    document.getElementById('835aa3f1-e567-4d8e-a7e4-69a7feb5078f').value = '\(parent.attendee.lastName)';
                    document.getElementById('12a627f7-72ac-4274-a068-055868eb9968').value = '\(parent.attendee.email)';
                    document.getElementById('f8701da2-4473-48b4-8e11-231eb9ae0481').value = '\(parent.attendee.oemsId)';
                    setTimeout(function() {
                        document.getElementById('registerParticipantButton').click();
                    }, 500);
                    return 'SUCCESS';
                } catch(e) {
                    return 'ERROR: ' + e.message;
                }
            })();
            """
            
            webView.evaluateJavaScript(js) { _, _ in
                DispatchQueue.main.async {
                    self.parent.hasAutoFilled = true
                    self.parent.isLoading = false
                }
            }
        }
    }
}
