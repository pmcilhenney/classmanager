//
//  SafariSheet.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/7/25.
//

import SwiftUI
import SafariServices

struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
