//
//  ElectiveCheckInOutView.swift
//  classmanager
//
//  Created for 2.0 - embedded JotForm for elective check-in/out
//

import SwiftUI
import WebKit

/// Displays an embedded JotForm for elective check-in or check-out.
/// The form is prefilled and the user completes it directly in the app.
struct ElectiveCheckInOutView: View {
    let url: URL
    let title: String
    let onDismiss: () -> Void

    @State private var isLoading = true
    @State private var hasSubmitted = false
    @State private var showSuccessMessage = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    if hasSubmitted {
                        Button {
                            onDismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Done")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                            )
                            .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // WebView
                ElectiveFormWebView(
                    url: url,
                    isLoading: $isLoading,
                    hasSubmitted: $hasSubmitted
                )
                .overlay(alignment: .top) {
                    if isLoading {
                        LoadingSpinnerView()
                            .padding(.top, 40)
                    }
                }
            }

            // Success overlay
            if showSuccessMessage {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Submitted Successfully!")
                        .font(.title2.weight(.semibold))

                    Text("Your \(title.lowercased()) has been recorded.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: hasSubmitted) { submitted in
            if submitted {
                // Show success message briefly
                withAnimation {
                    showSuccessMessage = true
                }

                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSuccessMessage = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - WebView Component

private struct ElectiveFormWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var hasSubmitted: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, hasSubmitted: $hasSubmitted)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var hasSubmitted: Bool

        init(isLoading: Binding<Bool>, hasSubmitted: Binding<Bool>) {
            self._isLoading = isLoading
            self._hasSubmitted = hasSubmitted
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = false

                // Check if we're on a thank-you page (JotForm submission complete)
                if let urlString = webView.url?.absoluteString {
                    if urlString.contains("thank-you") || urlString.contains("thankyou") || urlString.contains("submit") {
                        self.hasSubmitted = true
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation within JotForm
            decisionHandler(.allow)
        }
    }
}
