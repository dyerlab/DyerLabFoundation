//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotData.swift
//  PopulationGenetics
//
//  Turns a spec and the current genotypes into the numbers to draw. Anything a
//  spec names can vanish after it is saved, since populations can be renamed in
//  the spreadsheet, so a stale reference is reported rather than treated as a bug.
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The numbers behind a diversity plot.
public struct DiversityPlotData: Equatable, Sendable {

    /// One bar.
    public struct Category: Equatable, Sendable {
        /// The locus, population or family name.
        public let name: String
        /// The statistic.
        public let value: Double

        /// Creates a bar.
        ///
        /// - Parameters:
        ///   - name: The locus, population or family name.
        ///   - value: The statistic.
        public init(name: String, value: Double) {
            self.name = name
            self.value = value
        }
    }

    /// One point in a scatter plot.
    public struct Point: Equatable, Sendable {
        /// The population or family name.
        public let name: String
        /// The predictor's value.
        public let x: Double
        /// The statistic.
        public let y: Double

        /// Creates a point.
        ///
        /// - Parameters:
        ///   - name: The population or family name.
        ///   - x: The predictor's value.
        ///   - y: The statistic.
        public init(name: String, x: Double, y: Double) {
            self.name = name
            self.x = x
            self.y = y
        }
    }

    /// What the plot draws.
    public enum Content: Equatable, Sendable {
        /// The values whose distribution is drawn.
        case distribution([Double])
        /// A bar per category.
        case categories([Category])
        /// A point per group.
        case points([Point])
        /// Nothing can be drawn, for the given reason.
        case unavailable(String)

        /// Whether the content has no values to draw.
        fileprivate var isEmptyPlot: Bool {
            switch self {
            case .distribution(let values): values.isEmpty
            case .categories(let categories): categories.isEmpty
            case .points(let points): points.isEmpty
            case .unavailable: false
            }
        }
    }

    /// What the plot draws.
    public let content: Content
    /// The x-axis title.
    public let xLabel: String
    /// The y-axis title.
    public let yLabel: String
    /// Items left out because they have no data for this plot.
    public let omitted: [String]

    /// Creates a plot's numbers directly, for tests and previews.
    ///
    /// - Parameters:
    ///   - content: What the plot draws.
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - omitted: Items left out for having no data.
    public init(content: Content, xLabel: String = "", yLabel: String = "", omitted: [String] = []) {
        self.content = content
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.omitted = omitted
    }

    /// Computes a plot's numbers.
    ///
    /// - Parameters:
    ///   - spec: What to plot.
    ///   - dataset: The genotypes.
    public init(spec: DiversityPlotSpec, dataset: ImportedDataset) {
        let options = DiversityPlotOptions(dataset: dataset)
        let response = spec.response
        let unit = spec.effectiveUnit(primaryGroupUnit: options.primaryGroupUnit)
        let groups = options.groups(for: unit)
        var content: Content
        var omitted: [String] = []

        if !options.isAvailable(spec.predictor) {
            content = .unavailable("This project has no \(spec.predictor.title.lowercased()) data to plot against.")
        } else if !options.units.contains(unit) {
            content = .unavailable("This project has no \(unit.title.lowercased()).")
        } else if let locus = spec.locus, spec.usesLocus, !options.loci.contains(locus) {
            content = .unavailable("The locus \(locus) is no longer in this project.")
        } else if case .group(let name) = spec.sample, spec.usesSample,
                  !options.primaryGroups.contains(where: { $0.name == name }) {
            content = .unavailable("\(name) is no longer in this project.")
        } else {
            let calculator = DiversityPlotCalculator(dataset: dataset, options: options, response: response)
            switch unit {
            case .locus:
                let values = calculator.locusValues(sample: spec.sample)
                omitted = values.filter { $0.value == nil }.map(\.name)
                let present = values.compactMap { row in row.value.map { Category(name: row.name, value: $0) } }
                content = spec.form == .bars ? .categories(present) : .distribution(present.map(\.value))
            case .population, .family:
                let values = groups.map { group in
                    (group: group, value: calculator.groupValue(group, locus: spec.locus))
                }
                omitted = values.filter { $0.value == nil }.map(\.group.name)
                let present = values.compactMap { row in row.value.map { (group: row.group, value: $0) } }
                switch spec.form {
                case .distribution:
                    content = .distribution(present.map(\.value))
                case .bars:
                    content = .categories(present.map { Category(name: $0.group.name, value: $0.value) })
                case .scatter:
                    let located = present.map { row in
                        (row: row, x: calculator.predictorValue(spec.predictor, for: row.group))
                    }
                    omitted += located.filter { $0.x == nil }.map(\.row.group.name)
                    content = .points(located.compactMap { item in
                        item.x.map { Point(name: item.row.group.name, x: $0, y: item.row.value) }
                    })
                }
            case .locusWithinPopulation, .locusWithinFamily:
                content = .distribution(groups.flatMap { calculator.values(within: $0) })
            }
        }

        if content.isEmptyPlot {
            content = .unavailable("No genotypes are available for this plot.")
        }
        self.content = content
        self.omitted = omitted
        switch spec.form {
        case .distribution:
            xLabel = response.label
            yLabel = spec.style == .density ? "Density" : "Count"
        case .bars, .scatter:
            xLabel = spec.predictor == .latitude || spec.predictor == .longitude
                ? "\(spec.predictor.title) (decimal degrees)"
                : spec.predictor.title
            yLabel = response.label
        }
    }
}
