//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationWebView+Coordinator.swift
//  Documentation
//
//  Follows a help page's navigation: scrolls to the anchor once the page has
//  loaded, keeps links within the page or the help folder in the view, and
//  sends every other link to the user's browser.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI
import WebKit

extension DocumentationWebView {

    /// The web view's navigation delegate.
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        /// The page loaded or loading.
        var page: URL?
        /// The anchor to scroll to.
        var anchor: String?
        /// The folder a bundled page may read from.
        var readAccess: URL?
        /// Opens links that leave the help.
        var openURL: OpenURLAction?

        /// Scrolls to the anchor, if there is one.
        func scroll(_ webView: WKWebView) {
            guard let anchor else {
                webView.callAsyncJavaScript("window.scrollTo(0, 0)", arguments: [:], in: nil, in: .page)
                return
            }
            webView.callAsyncJavaScript("document.getElementById(id)?.scrollIntoView({ block: 'start' })",
                                        arguments: ["id": anchor], in: nil, in: .page)
        }

        /// Scrolls to the anchor once a page has loaded.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if anchor != nil { scroll(webView) }
        }

        /// Keeps the help's own links in the view and opens the rest in the browser.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
                return .allow
            }
            if isWithinHelp(url, current: webView.url) { return .allow }
            openURL?(url)
            return .cancel
        }

        /// Whether a link stays on the current page or within the help folder.
        private func isWithinHelp(_ url: URL, current: URL?) -> Bool {
            if let current, Self.document(url) == Self.document(current) { return true }
            guard url.isFileURL, let readAccess else { return false }
            return url.standardizedFileURL.path.hasPrefix(readAccess.standardizedFileURL.path)
        }

        /// A URL without its fragment.
        private static func document(_ url: URL) -> String {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.fragment = nil
            return components?.string ?? url.absoluteString
        }
    }
}
