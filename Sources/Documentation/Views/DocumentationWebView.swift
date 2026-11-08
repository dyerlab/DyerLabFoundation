//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationWebView.swift
//  Documentation
//
//  The `WKWebView` that shows a help page. It reloads only when the page
//  changes; moving to another section of the same page scrolls to its
//  anchor instead, so the outline's sections feel like one document. Links
//  within the help stay in the view, and links anywhere else open in the
//  user's browser. The platform files add the `NSViewRepresentable` and
//  `UIViewRepresentable` conformances.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI
import WebKit

/// Shows one help page, scrolled to an anchor.
@MainActor
struct DocumentationWebView {
    /// The page, without an anchor.
    let page: URL
    /// The element id to scroll to.
    let anchor: String?
    /// The folder a bundled page may read from, such as its images.
    let readAccess: URL?

    /// Makes the object that follows the view's navigation.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Makes the web view and loads the page.
    func makeWebView(coordinator: Coordinator) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = coordinator
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    /// Brings the web view to this page and anchor.
    func update(_ webView: WKWebView, coordinator: Coordinator, openURL: OpenURLAction) {
        coordinator.openURL = openURL
        coordinator.readAccess = readAccess
        if coordinator.page != page {
            coordinator.page = page
            coordinator.anchor = anchor
            if page.isFileURL {
                webView.loadFileURL(page, allowingReadAccessTo: readAccess ?? page.deletingLastPathComponent())
            } else {
                webView.load(URLRequest(url: page))
            }
        } else if coordinator.anchor != anchor {
            coordinator.anchor = anchor
            coordinator.scroll(webView)
        }
    }
}

// MARK: - Previews

#Preview("Sample page") {
    let library = DocumentationLibrary.sample
    if let entry = library.index.entry("sample.selfing"), let page = library.page(of: entry) {
        DocumentationWebView(page: page, anchor: entry.anchor, readAccess: library.folder)
            .frame(width: 700, height: 500)
    }
}
