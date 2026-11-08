//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationSidebar.swift
//  Documentation
//
//  The help browser's sidebar, like the documentation browser DocC content
//  is read in: the outline with its disclosure triangles, or, while there is
//  search text, a flat list of the matching entries with where each sits in
//  the outline. The bundled pages are read for the search in the background
//  when the sidebar first appears.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The help outline and search.
struct DocumentationSidebar: View {
    /// The help being browsed.
    @Bindable var library: DocumentationLibrary

    var body: some View {
        List(selection: $library.selection) {
            if library.query.isEmpty {
                ForEach(library.index.entries) { DocumentationOutlineRow(entry: $0, library: library) }
            } else {
                ForEach(library.results) { result in
                    DocumentationLabel(entry: result.entry, path: result.path)
                        .tag(Optional(result.id))
                }
            }
        }
        .overlay {
            if !library.query.isEmpty && library.results.isEmpty {
                ContentUnavailableView.search(text: library.query)
            }
        }
        .searchable(text: $library.query, placement: .sidebar, prompt: "Search Help")
        .task { await library.loadSearchText() }
    }
}

// MARK: - Previews

#Preview("Outline") {
    NavigationSplitView {
        DocumentationSidebar(library: .sample)
    } detail: {
        Text("Detail")
    }
    .frame(width: 700, height: 450)
}
