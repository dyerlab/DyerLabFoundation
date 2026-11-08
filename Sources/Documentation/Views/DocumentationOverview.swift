//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationOverview.swift
//  Documentation
//
//  The page for a group that has no page of its own: its title and summary,
//  then each entry under it with its summary, as a DocC topic group lists
//  its members. Choosing one shows it.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A group's entries, each with its summary.
struct DocumentationOverview: View {
    /// The group.
    let entry: DocumentationEntry
    /// The help it belongs to.
    let library: DocumentationLibrary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.title)
                    .font(.largeTitle.bold())
                if let summary = entry.summary {
                    Text(summary)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Divider()
                ForEach(entry.children ?? []) { child in
                    Button { library.show(child.id) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            DocumentationLabel(entry: child)
                                .font(.headline)
                            Text(child.summary ?? (child.hasPage ? "" : "Not written yet."))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

// MARK: - Previews

#Preview("Group") {
    let library = DocumentationLibrary.sample
    if let entry = library.index.entry("background") {
        DocumentationOverview(entry: entry, library: library)
            .frame(width: 700, height: 450)
    }
}
