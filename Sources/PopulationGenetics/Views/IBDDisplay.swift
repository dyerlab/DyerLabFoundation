//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IBDDisplay.swift
//  PopulationGenetics
//
//  An isolation-by-distance analysis as the Isolation page shows it: the
//  scatter of pairs with its regression line, and below it the Mantel
//  table, its caption and whatever the page adds below (the permutation
//  test's null distribution). The same view draws a fresh result and a saved
//  one, so what is saved is what was seen.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import PresentationZen
import SwiftUI

/// The scatter, results table and anything below them (such as the null distribution) of an isolation-by-distance
/// analysis, stacked in one scrolling column.
public struct IBDDisplay<Accessory: View>: View {

    /// The height of the scatter, tall enough to read its pairs without crowding out the table below.
    private static var scatterHeight: Double { 380 }

    /// The pairs and regression line.
    public let scatter: PairwiseScatter
    /// The Mantel and regression statistics, if the test has run.
    public let table: DataTable?
    /// The analysis's title.
    public let title: String
    /// A caption under the table, such as the legend.
    public let caption: String?
    /// What goes under the table, such as the null distribution.
    public let accessory: Accessory

    // MARK: - Initialization

    /// Creates the display.
    ///
    /// - Parameters:
    ///   - scatter: The pairs and regression line.
    ///   - table: The statistics.
    ///   - title: The analysis's title.
    ///   - caption: A caption under the table.
    ///   - accessory: What goes under the table.
    public init(scatter: PairwiseScatter, table: DataTable?, title: String, caption: String? = nil,
                @ViewBuilder accessory: () -> Accessory) {
        self.scatter = scatter
        self.table = table
        self.title = title
        self.caption = caption
        self.accessory = accessory()
    }

    // MARK: - Body

    /// The display.
    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                Text(title).font(.headline)
                PairwiseScatterPlot(scatter)
                    .frame(height: Self.scatterHeight)
                if let table {
                    TabularOutputView(table, caption: caption, decimals: 4)
                }
                accessory
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

public extension IBDDisplay where Accessory == EmptyView {

    /// Creates the display with nothing under the table.
    ///
    /// - Parameters:
    ///   - scatter: The pairs and regression line.
    ///   - table: The statistics.
    ///   - title: The analysis's title.
    ///   - caption: A caption under the table.
    init(scatter: PairwiseScatter, table: DataTable?, title: String, caption: String? = nil) {
        self.init(scatter: scatter, table: table, title: title, caption: caption) { EmptyView() }
    }
}

// MARK: - Previews

#Preview("Rousset") {
    if let dataset = try? ExampleDataset.arapatPopulations.load(),
       let result = try? IBDAnalysis(spec: IBDSpec(logSeparation: true, permutations: 99, seed: 1),
                                     dataset: dataset).run() {
        IBDDisplay(scatter: result.scatter, table: result.dataTable, title: result.title, caption: result.legend) {
            if let distribution = result.outcome.distribution {
                NullDistributionView(distribution, statisticLabel: "r")
            }
        }
        .padding()
        .frame(width: 800, height: 900)
    }
}
