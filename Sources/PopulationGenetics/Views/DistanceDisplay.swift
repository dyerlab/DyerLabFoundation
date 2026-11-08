//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceDisplay.swift
//  PopulationGenetics
//
//  The top of the Distance page: the matrix as a heatmap and, beside it, the
//  distribution of its pairwise values with a few summary numbers. It draws
//  any matrix, so a stored one written from R shows the same way, without
//  units.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import PresentationZen
import SwiftUI

/// A matrix's heatmap beside the histogram of its pairwise values.
public struct DistanceDisplay: View {
    /// The matrix.
    public let data: MatrixHeatmapData
    /// The matrix's title.
    public let title: String

    /// Creates the display.
    ///
    /// - Parameters:
    ///   - data: The matrix.
    ///   - title: The matrix's title.
    public init(_ data: MatrixHeatmapData, title: String) {
        self.data = data
        self.title = title
    }

    /// The display.
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            HStack(alignment: .top, spacing: 24) {
                MatrixHeatmap(data)
                    .layoutPriority(1)
                distribution
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 380)
            }
        }
    }

    private var distribution: some View {
        let values = data.pairValues
        let label = "Distance" + (data.units.map { " (\($0))" } ?? "")
        return VStack(alignment: .leading, spacing: 12) {
            Histogram(DataTable(numbers: [label: values], roles: [.y: label]), bins: 30, xLabel: label,
                      style: .binned)
                .frame(height: 220)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                summaryRow("Pairs", values.count.formatted())
                summaryRow("Minimum", format(values.min()))
                summaryRow("Mean", format(values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)))
                summaryRow("Maximum", format(values.max()))
            }
            .font(.caption)
            .monospacedDigit()
        }
    }

    private func summaryRow(_ name: String, _ value: String) -> some View {
        GridRow {
            Text(name).foregroundStyle(.secondary)
            Text(value + (data.units.map { name == "Pairs" ? "" : " \($0)" } ?? ""))
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "–" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}

// MARK: - Previews

#Preview("Among populations") {
    if let dataset = try? ExampleDataset.arapatPopulations.load(),
       let result = DistanceAnalysis(spec: DistanceSpec(level: "Population"), dataset: dataset)?.run() {
        DistanceDisplay(result.heatmapData, title: result.name)
            .padding()
            .frame(width: 1000, height: 560)
    }
}

#Preview("Among individuals") {
    if let dataset = try? ExampleDataset.arapatPopulations.load(),
       let result = DistanceAnalysis(spec: DistanceSpec(), dataset: dataset)?.run() {
        DistanceDisplay(result.heatmapData, title: result.name)
            .padding()
            .frame(width: 1000, height: 560)
    }
}
