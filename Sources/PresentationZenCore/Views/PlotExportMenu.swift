//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlotExportMenu.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The copy and export items for a plot's context menu.
///
/// Copying sits at the top level because it is the usual way to a manuscript.
public struct PlotExportMenu: View {
    /// Called with the output the user chose.
    public let export: (PlotExportOutput) -> Void
    /// The outputs to offer.
    public let outputs: [PlotExportOutput]

    /// Creates the menu items.
    ///
    /// - Parameters:
    ///   - outputs: The outputs to offer; every one by default.
    ///   - export: Called with the output the user chose.
    public init(outputs: [PlotExportOutput] = PlotExportOutput.allCases,
                export: @escaping (PlotExportOutput) -> Void) {
        self.outputs = outputs
        self.export = export
    }

    /// The menu items.
    public var body: some View {
        item("Copy R Chunk", .chunkToClipboard)
        item("Copy R Code", .codeToClipboard)
        item("Copy Data", .dataToClipboard)
        if !outputs.allSatisfy(\.isClipboard) {
            Menu("Export") {
                item("PNG…", .png)
                item("R Script…", .script)
                item("CSV…", .csv)
            }
        }
    }

    @ViewBuilder
    private func item(_ title: String, _ output: PlotExportOutput) -> some View {
        if outputs.contains(output) {
            Button(title) { export(output) }
        }
    }
}

// MARK: - Previews

#Preview {
    Text("Right-click for the menu")
        .padding(40)
        .contextMenu { PlotExportMenu { _ in } }
}
