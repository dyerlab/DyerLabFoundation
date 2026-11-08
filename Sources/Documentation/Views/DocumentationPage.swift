//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationPage.swift
//  Documentation
//
//  The help browser's main pane: the selected entry's page, its group's
//  overview when it has no page, or a note that the topic isn't written
//  yet. A bundled page that also has an online version offers it from the
//  toolbar, and a page shown from the web says so, since it needs a network
//  connection.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The selected help entry's page.
struct DocumentationPage: View {
    /// The help being browsed.
    let library: DocumentationLibrary

    var body: some View {
        if let entry = library.selectedEntry {
            content(for: entry)
                .navigationTitle(entry.title)
        } else if let error = library.error {
            ContentUnavailableView("No Help Available", systemImage: "questionmark.circle",
                                   description: Text(error.localizedDescription))
        } else {
            ContentUnavailableView("Choose a Topic", systemImage: "book",
                                   description: Text("Pick a topic in the sidebar, or search for one."))
        }
    }

    @ViewBuilder
    private func content(for entry: DocumentationEntry) -> some View {
        if let page = library.page(of: entry) {
            DocumentationWebView(page: page, anchor: entry.anchor, readAccess: library.folder)
                .toolbar { onlineItem(for: entry, page: page) }
        } else if entry.children != nil {
            DocumentationOverview(entry: entry, library: library)
        } else {
            ContentUnavailableView(entry.title, systemImage: "doc",
                                   description: Text(entry.summary.map { "\($0)\n\n" } ?? ""
                                                     + "This topic hasn't been written yet."))
        }
    }

    @ToolbarContentBuilder
    private func onlineItem(for entry: DocumentationEntry, page: URL) -> some ToolbarContent {
        if let url = entry.url {
            ToolbarItem {
                if page.isFileURL {
                    Link(destination: url) {
                        Label("View Online", systemImage: "safari")
                    }
                    .help("Open the full page in your browser")
                } else {
                    Label("Online", systemImage: "network")
                        .help("This page is read from the web and needs a network connection.")
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Page") {
    let library = DocumentationLibrary.sample
    NavigationStack {
        DocumentationPage(library: library)
    }
    .frame(width: 700, height: 500)
}
