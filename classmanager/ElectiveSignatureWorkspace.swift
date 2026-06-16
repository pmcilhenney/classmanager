//
//  ElectiveSignatureWorkspace.swift
//  classmanager
//
//  FIXED VERSION - Compatible with current FlexiWebView
//

import SwiftUI
import WebKit

struct ElectiveSignatureWorkspace: View {
    let attendee: RosterAttendee
    let jotform: JotFormClient
    let onDone: () -> Void
    
    @State private var currentURL: URL? = nil
    @State private var isLoading = false
    @State private var toast: String? = nil
    
    var body: some View {
        ZStack {
            if let url = currentURL {
                FlexiWebView(
                    url: url,
                    lastURL: $currentURL,
                    loading: $isLoading
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                ProgressView("Preparing elective form…")
            }

            if let t = toast {
                VStack {
                    Spacer()
                    Text(t)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Elective Signature")
        .onAppear {
            buildURL()
        }
    }
    
    private func buildURL() {
        isLoading = true
        
        Task { @MainActor in
            do {
                let builder = ElectivePrefillBuilder()
                let url = try await ElectivePrefillBuilder.makePrefillURL(for: attendee, jotform: jotform, lastURL: currentURL)
                currentURL = url
                isLoading = false
            } catch {
                toast = "Error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

