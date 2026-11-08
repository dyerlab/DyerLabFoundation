//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TableExportMenu.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The copy and export items for a results table, for a context menu or a toolbar menu.
public struct TableExportMenu: View {
    /// Called with the output the user chose.
    public let export: (TableExportOutput) -> Void
    /// The outputs to offer.
    public let outputs: [TableExportOutput]

    /// Creates the menu items.
    ///
    /// - Parameters:
    ///   - outputs: The outputs to offer; every one by default.
    ///   - export: Called with the output the user chose.
    public init(outputs: [TableExportOutput] = TableExportOutput.allCases,
                export: @escaping (TableExportOutput) -> Void) {
        self.outputs = outputs
        self.export = export
    }

    /// The menu items.
    public var body: some View {
        item("Copy R Chunk", .chunkToClipboard)
        item("Copy R Code", .codeToClipboard)
        item("Copy Markdown Table", .markdownToClipboard)
        item("Copy Data", .dataToClipboard)
        if !outputs.allSatisfy(\.isClipboard) {
            Menu("Export") {
                item("Markdown…", .markdown)
                item("R Script…", .script)
                item("CSV…", .csv)
            }
        }
    }

    @ViewBuilder
    private func item(_ title: String, _ output: TableExportOutput) -> some View {
        if outputs.contains(output) {
            Button(title) { export(output) }
        }
    }
}

// MARK: - Previews

#Preview {
    Text("Right-click for the menu")
        .padding(40)
        .contextMenu { TableExportMenu { _ in } }
}
