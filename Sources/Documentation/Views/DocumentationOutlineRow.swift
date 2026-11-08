//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationOutlineRow.swift
//  Documentation
//
//  One row of the help outline, with a disclosure triangle when it has
//  entries under it. Whether a row is open is kept in the library rather
//  than by the outline itself, so a help link can open the rows above its
//  topic. A row's children are type-erased because the row contains itself.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// An outline row and, when it is open, the rows under it.
struct DocumentationOutlineRow: View {
    /// The row's entry.
    let entry: DocumentationEntry
    /// The help the row belongs to.
    let library: DocumentationLibrary

    var body: some View {
        if let children = entry.children {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(children) { child in
                    AnyView(DocumentationOutlineRow(entry: child, library: library))
                }
            } label: {
                DocumentationLabel(entry: entry)
            }
            .tag(Optional(entry.id))
        } else {
            DocumentationLabel(entry: entry)
                .tag(Optional(entry.id))
        }
    }

    private var isExpanded: Binding<Bool> {
        Binding {
            library.expanded.contains(entry.id)
        } set: { isOpen in
            if isOpen { library.expanded.insert(entry.id) } else { library.expanded.remove(entry.id) }
        }
    }
}

// MARK: - Previews

#Preview("Outline") {
    @Previewable @State var library = DocumentationLibrary.sample
    List(selection: $library.selection) {
        ForEach(library.index.entries) { DocumentationOutlineRow(entry: $0, library: library) }
    }
    .frame(width: 280, height: 400)
}
