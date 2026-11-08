//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredFigure+Table.swift
//  PresentationZen
//
//  A results table saved in the figure tables: form `table`, its values in the
//  figure's columns, and R code that prints it with knitr::kable(). Tables
//  have no plot form or axis labels.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension StoredFigure {

    /// The form name of a figure that is a results table.
    static let tableFormName = "table"

    /// Whether the figure is a results table rather than a plot.
    var isTable: Bool { formName == Self.tableFormName }

    /// Stores a results table, with the code that prints it, replacing any earlier values.
    ///
    /// - Parameters:
    ///   - table: The values.
    ///   - notes: Remarks to keep with the code as comments.
    mutating func storeTable(_ table: DataTable, notes: [String] = []) {
        columns = table.figureColumns
        formName = Self.tableFormName
        bins = nil
        xLabel = nil
        yLabel = nil
        rCode = RTableChunk(title: title, legend: legend, table: table, notes: notes).code
    }

    /// The exports a results table can provide, given what it holds.
    var availableTableOutputs: [TableExportOutput] {
        guard isTable, table != nil else { return [] }
        return TableExportOutput.allCases
    }

    /// Sends a results table to the clipboard, or prepares it as a file.
    ///
    /// - Parameters:
    ///   - output: Where the table goes.
    ///   - pasteboard: The clipboard to copy to.
    /// - Returns: The file to save, or `nil` if `output` went to the clipboard.
    /// - Throws: ``PlotExportError/plotUnavailable(_:)`` if the figure isn't a table or its columns can't form one.
    @discardableResult
    func exportTable(_ output: TableExportOutput, pasteboard: DLPasteboard = .system) throws -> PlotExportFile? {
        guard isTable, let table else {
            throw PlotExportError.plotUnavailable("This figure doesn't hold a table.")
        }
        return table.exportTable(output, title: title, legend: legend, rCode: rCode, pasteboard: pasteboard)
    }
}
