//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FigureList.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A list of a project's figures, with what can be done to each and a button to keep another.
public struct FigureList: View {

    /// Something the user asked to do with a figure.
    public enum Action {
        /// Change the title and legend.
        case edit
        /// Replace the figure with the plot now on the page.
        case replaceWithCurrent
        /// Copy it to the clipboard or save it to a file.
        case export(PlotExportOutput)
        /// Copy a results table to the clipboard or save it to a file.
        case exportTable(TableExportOutput)
        /// Remove it from the project.
        case delete
    }

    /// The figures.
    public let figures: [StoredFigure]
    /// The figure on the page, if any.
    @Binding public var selection: StoredFigure.ID?
    /// The program whose figures need no note of where they came from.
    public let localSource: String?
    /// What to say when there are no figures.
    public let emptyMessage: String
    /// What one figure is called in the list's buttons and messages, such as `Plot` or `Table`.
    public let itemName: String
    /// Whether the page's current plot can be saved.
    public let canSave: Bool
    /// Saves the page's current plot.
    public let save: () -> Void
    /// Whether the page's current plot can replace a figure.
    public let canReplace: (StoredFigure) -> Bool
    /// The exports a figure can provide.
    public let outputs: (StoredFigure) -> [PlotExportOutput]
    /// The results-table exports a plot can also provide.
    public let tableOutputs: (StoredFigure) -> [TableExportOutput]
    /// Performs an action on a figure.
    public let perform: (Action, StoredFigure) -> Void

    // MARK: - Initialization

    /// Creates the list.
    ///
    /// - Parameters:
    ///   - figures: The figures.
    ///   - selection: The figure on the page, if any.
    ///   - localSource: The program whose figures need no note of where they came from.
    ///   - emptyMessage: What to say when there are no figures.
    ///   - itemName: What one figure is called, such as `Plot` or `Table`.
    ///   - canSave: Whether the page's current plot can be saved.
    ///   - save: Saves the page's current plot.
    ///   - canReplace: Whether the page's current plot can replace a figure.
    ///   - outputs: The exports a figure can provide.
    ///   - tableOutputs: The results-table exports a plot can also provide, such as an analysis's statistics beside
    ///     its scatter; none by default.
    ///   - perform: Performs an action on a figure.
    public init(figures: [StoredFigure],
                selection: Binding<StoredFigure.ID?>,
                localSource: String? = nil,
                emptyMessage: String = "Save a plot to keep it with the project.",
                itemName: String = "Plot",
                canSave: Bool,
                save: @escaping () -> Void,
                canReplace: @escaping (StoredFigure) -> Bool = { _ in false },
                outputs: @escaping (StoredFigure) -> [PlotExportOutput] = { $0.availableOutputs },
                tableOutputs: @escaping (StoredFigure) -> [TableExportOutput] = { _ in [] },
                perform: @escaping (Action, StoredFigure) -> Void) {
        self.figures = figures
        _selection = selection
        self.localSource = localSource
        self.emptyMessage = emptyMessage
        self.itemName = itemName
        self.canSave = canSave
        self.save = save
        self.canReplace = canReplace
        self.outputs = outputs
        self.tableOutputs = tableOutputs
        self.perform = perform
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if figures.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView("No Saved \(itemName)s",
                                           systemImage: itemName == "Table" ? "tablecells" : "photo.on.rectangle",
                                           description: Text(emptyMessage))
                    Spacer()
                }

            } else {
                figureRows
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
    }

    private var figureRows: some View {
        let list = List(figures, selection: $selection) { figure in
            FigureRow(figure: figure, localSource: localSource)
                .contextMenu { menuItems(for: figure) }
        }
        #if os(macOS)
        return list.onDeleteCommand {
            if let figure = figures.first(where: { $0.id == selection }) { perform(.delete, figure) }
        }
        #else
        return list
        #endif
    }

    private var footer: some View {
        HStack {
            Button("Save \(itemName)…", systemImage: "plus", action: save)
                .disabled(!canSave)
            Spacer()
        }
        .padding(8)
        .background(.bar)
    }

    // MARK: - Menu

    @ViewBuilder
    private func menuItems(for figure: StoredFigure) -> some View {
        Button("Edit Title & Legend…") { perform(.edit, figure) }
        if canReplace(figure) {
            Button("Replace with Current \(itemName)") { perform(.replaceWithCurrent, figure) }
                .disabled(!canSave)
        }
        Divider()
        if figure.isTable {
            TableExportMenu(outputs: figure.availableTableOutputs) { perform(.exportTable($0), figure) }
        } else {
            PlotExportMenu(outputs: outputs(figure)) { perform(.export($0), figure) }
            let tables = tableOutputs(figure)
            if !tables.isEmpty {
                Menu("Results Table") {
                    TableExportMenu(outputs: tables) { perform(.exportTable($0), figure) }
                }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { perform(.delete, figure) }
    }
}

// MARK: - Previews

#Preview("With figures") {
    @Previewable @State var selection: StoredFigure.ID?
    let figure = StoredFigure(title: "He by population",
                              legend: "Expected heterozygosity for each population.",
                              source: "gstudio",
                              formName: "bars",
                              columns: [FigureColumn(name: "population", role: .x, values: .text(["A", "B"])),
                                        FigureColumn(name: "He", role: .y, values: .numbers([0.4, 0.5]))])
    FigureList(figures: [figure], selection: $selection, canSave: true, save: {}, perform: { _, _ in })
        .frame(width: 260, height: 500)
}

#Preview("Empty") {
    @Previewable @State var selection: StoredFigure.ID?
    FigureList(figures: [], selection: $selection, canSave: true, save: {}, perform: { _, _ in })
        .frame(width: 260, height: 500)
}
