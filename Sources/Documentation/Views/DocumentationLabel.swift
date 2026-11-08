//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationLabel.swift
//  Documentation
//
//  An entry's title and icon, as the outline and the search results show
//  it. An entry without a symbol of its own gets one for its kind: a folder
//  for a group, a page for a page, a number sign for a section. A topic not
//  yet written is drawn dimmed.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// An entry's title and icon.
struct DocumentationLabel: View {
    /// The entry.
    let entry: DocumentationEntry
    /// The titles of the entries above it, shown under the title in search results.
    var path: [String] = []

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                if !path.isEmpty {
                    Text(path.joined(separator: " › "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: symbol)
        }
        .foregroundStyle(isUnwritten ? .secondary : .primary)
    }

    private var symbol: String {
        if let symbol = entry.symbol { return symbol }
        if entry.anchor != nil { return "number" }
        if entry.hasPage { return "doc.text" }
        return entry.children != nil ? "folder" : "doc"
    }

    /// A topic with neither a page nor entries under it.
    private var isUnwritten: Bool {
        !entry.hasPage && entry.children == nil
    }
}

// MARK: - Previews

#Preview("Kinds") {
    List {
        DocumentationLabel(entry: DocumentationEntry(id: "g", title: "Background", children: []))
        DocumentationLabel(entry: DocumentationEntry(id: "p", title: "Nonrandom Mating", file: "a.html"))
        DocumentationLabel(entry: DocumentationEntry(id: "s", title: "Wahlund Effects", file: "a.html", anchor: "w"))
        DocumentationLabel(entry: DocumentationEntry(id: "u", title: "Population Graphs"))
        DocumentationLabel(entry: DocumentationEntry(id: "r", title: "Selfing", file: "a.html", anchor: "s"),
                           path: ["Background", "Nonrandom Mating"])
    }
    .frame(width: 280, height: 260)
}
