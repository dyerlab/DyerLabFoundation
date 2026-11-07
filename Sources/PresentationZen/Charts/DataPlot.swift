//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DataPlot.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Charts
import SwiftUI

/// A table drawn in one of the standard forms.
///
/// Other modules build the table and choose the form, and get the drawing and every export from here: an image
/// from `pngData(_:)`, R code from ``rChunk(title:legend:notes:)``, and text from the table itself. Each export
/// comes from the same table the chart draws, so they can't disagree.
public struct DataPlot: View {
    /// The values, with roles bound as `form` requires.
    public var table: DataTable
    /// How the table is drawn.
    public var form: PlotForm
    /// The x-axis title.
    public var xLabel: String
    /// The y-axis title.
    public var yLabel: String

    /// Creates a plot.
    ///
    /// - Parameters:
    ///   - table: The values, with roles bound as `form` requires.
    ///   - form: How the table is drawn.
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    public init(_ table: DataTable, form: PlotForm, xLabel: String = "", yLabel: String = "") {
        self.table = table
        self.form = form
        self.xLabel = xLabel
        self.yLabel = yLabel
    }

    /// The chart for the plot's form.
    public var body: some View {
        switch form {
        case .histogram(let bins):
            Histogram(table, bins: bins, xLabel: xLabel, yLabel: yLabel, style: .binned)
        case .density:
            Histogram(table, xLabel: xLabel, yLabel: yLabel, style: .density)
        case .bars:
            BarPlot(table, xLabel: xLabel, yLabel: yLabel,
                    rotateLabels: table.rowCount > PlotForm.horizontalLabelLimit)
        case .scatter:
            ScatterPlot(table, xLabel: xLabel, yLabel: yLabel)
                // Values far from zero, such as latitudes, would otherwise be squeezed against the axis.
                .chartXScale(domain: .automatic(includesZero: false))
        }
    }

    /// Builds R code that redraws this plot from its values.
    ///
    /// - Parameters:
    ///   - title: The figure's title.
    ///   - legend: The figure's legend.
    ///   - notes: Remarks to keep with the code as comments.
    /// - Returns: The chunk, or `nil` if the table doesn't bind the roles the form requires.
    public func rChunk(title: String, legend: String, notes: [String] = []) -> RFigureChunk? {
        RFigureChunk(title: title, legend: legend, table: table, form: form, xLabel: xLabel, yLabel: yLabel,
                     notes: notes)
    }
}

// MARK: - Previews

#Preview("Histogram") {
    DataPlot(.sampleValues, form: .histogram(bins: 8), xLabel: "Value", yLabel: "Count")
        .padding()
        .frame(width: 500, height: 320)
}

#Preview("Density") {
    DataPlot(.sampleValues, form: .density, xLabel: "Value", yLabel: "Density")
        .padding()
        .frame(width: 500, height: 320)
}
