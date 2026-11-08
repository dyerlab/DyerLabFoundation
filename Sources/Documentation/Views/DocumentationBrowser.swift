//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationBrowser.swift
//  Documentation
//
//  An app's help, laid out like the browser DocC documentation is read in:
//  the outline with search on the left and the page on the right. Choosing
//  an entry from the search results opens the outline rows above it, so
//  clearing the search leaves the outline showing where it is.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A help browser: an outline with search beside the selected page.
public struct DocumentationBrowser: View {
    /// The help being browsed.
    public let library: DocumentationLibrary

    /// Creates a browser.
    ///
    /// - Parameter library: The help to browse.
    public init(library: DocumentationLibrary) {
        self.library = library
    }

    /// The browser.
    public var body: some View {
        NavigationSplitView {
            DocumentationSidebar(library: library)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 380)
        } detail: {
            DocumentationPage(library: library)
        }
        .onChange(of: library.selection) { _, id in
            if let id { library.expanded.formUnion(library.index.ancestors(of: id)) }
        }
    }
}

// MARK: - Previews

#Preview("Sample help") {
    DocumentationBrowser(library: .sample)
        .frame(width: 1000, height: 650)
}
