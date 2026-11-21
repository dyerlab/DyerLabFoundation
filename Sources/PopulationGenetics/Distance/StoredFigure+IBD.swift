//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredFigure+IBD.swift
//  PopulationGenetics
//
//  A saved isolation-by-distance analysis: one figure of form `scatter` with
//  generator `ibd_analysis`. Its columns are the pairs (`From`, `To`, the
//  separation as x and the genetic distance as y), its spec is the
//  `IBDSpec` JSON with the results, and its R code draws the points with
//  the regression line. The page draws it from these and shows the results
//  table from the spec, so plot and table always travel together. A directional
//  analysis (dcGD) stores the ordered pairs with a `Direction` column, `forward`
//  or `reverse`, as the series, and draws a line for each.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import PresentationZen
import TabularData

public extension FigureGenerator {
    /// An isolation-by-distance analysis: ``IBDSpec`` JSON, results included, in the figure's `spec`.
    static let ibdAnalysis = FigureGenerator(rawValue: "ibd_analysis")
}

public extension StoredFigure {

    /// Creates a figure from an isolation-by-distance result.
    ///
    /// - Parameters:
    ///   - id: The figure's identity.
    ///   - title: The figure's title.
    ///   - legend: The figure's legend.
    ///   - source: The program making the figure.
    ///   - result: The test's result.
    ///   - image: A full-size PNG of the plot with its line, for exports.
    ///   - thumbnail: A small PNG of the plot, for the list.
    ///   - createdAt: When the figure was made.
    init(id: UUID = UUID(),
         title: String,
         legend: String,
         source: String,
         result: IBDResult,
         image: Data?,
         thumbnail: Data?,
         createdAt: Date = Date()) {
        self.init(id: id, title: title, legend: legend, source: source, createdAt: createdAt)
        setIBDResult(result, image: image, thumbnail: thumbnail)
    }

    /// The figure's isolation-by-distance spec and results, or `nil` if it isn't one this version can read.
    var ibdSpec: IBDSpec? {
        guard generator == .ibdAnalysis, let spec else { return nil }
        return try? JSONDecoder().decode(IBDSpec.self, from: Data(spec.utf8))
    }

    /// The stored pairs as a scatter with the stored regression line (for dcGD, the forward and reverse pairs with
    /// a line each), or `nil` if this isn't a readable analysis.
    var ibdScatter: PairwiseScatter? {
        guard let spec = ibdSpec, let table, let x = table.column(for: .x), let y = table.column(for: .y),
              table.columnNames.contains("From"), table.columnNames.contains("To") else { return nil }
        let from = table.displayTexts("From")
        let to = table.displayTexts("To")
        let xs = table.column(x)
        let ys = table.column(y)
        let points = xs.indices.compactMap { i -> PairwisePoint? in
            guard xs[i].isFinite, ys[i].isFinite else { return nil }
            return PairwisePoint(from: from[i], to: to[i], x: xs[i], y: ys[i])
        }
        let xLabel = xLabel ?? spec.separationLabel
        let yLabel = yLabel ?? spec.geneticLabel
        if let result = spec.result, result.isDirectional, table.columnNames.contains(Self.directionColumn) {
            let direction = table.displayTexts(Self.directionColumn)
            /// The pairs running one way, with that way's line.
            func series(_ name: String, _ value: String, _ slope: Double?) -> PairwiseSeries {
                let line = slope.flatMap { slope in
                    result.directedIntercept.map { RegressionLine(intercept: $0, slope: slope) }
                }
                let points = xs.indices.compactMap { i -> PairwisePoint? in
                    guard direction[i] == value, xs[i].isFinite, ys[i].isFinite else { return nil }
                    return PairwisePoint(from: from[i], to: to[i], x: xs[i], y: ys[i])
                }
                return PairwiseSeries(name: name, points: points, line: line)
            }
            return PairwiseScatter(xLabel: xLabel, yLabel: yLabel,
                                   series: [series("Forward", "forward", result.forwardSlope),
                                            series("Reverse", "reverse", result.reverseSlope)])
        }
        let line = spec.result.flatMap { result in
            result.slope.flatMap { slope in result.intercept.map { RegressionLine(intercept: $0, slope: slope) } }
        }
        return PairwiseScatter(xLabel: xLabel, yLabel: yLabel,
                               series: [PairwiseSeries(name: "Pairs", points: points, line: line)])
    }

    /// Makes the figure this isolation-by-distance analysis, replacing its values, spec, code and images.
    ///
    /// - Parameters:
    ///   - result: The test's result.
    ///   - image: A full-size PNG of the plot with its line.
    ///   - thumbnail: A small PNG of the plot.
    mutating func setIBDResult(_ result: IBDResult, image: Data?, thumbnail: Data?) {
        generator = .ibdAnalysis
        spec = result.spec.json
        let spec = result.spec
        let separation = spec.alongAxis ? spec.axis?.columnName ?? "axis_difference" : "distance_km"
        let xName = (spec.logSeparation ? "ln_" : "") + separation
        let yName = spec.validTransform == .rousset ? "phi_st_linearized" : spec.genetic.measure.rawValue
        let forward = result.directional?.forwardPoints ?? []
        let points = result.directional.map { $0.forwardPoints + $0.reversePoints } ?? result.outcome.points
        var frame = DataFrame()
        frame.append(column: TabularData.Column(name: "From", contents: points.map(\.from)))
        frame.append(column: TabularData.Column(name: "To", contents: points.map(\.to)))
        frame.append(column: TabularData.Column(name: xName, contents: points.map(\.x)))
        frame.append(column: TabularData.Column(name: yName, contents: points.map(\.y)))
        var roles: [DataColumnRole: String] = [.x: xName, .y: yName]
        if result.directional != nil {
            let direction = points.indices.map { $0 < forward.count ? "forward" : "reverse" }
            frame.append(column: TabularData.Column(name: Self.directionColumn, contents: direction))
            roles[.series] = Self.directionColumn
        }
        store(DataTable(frame: frame, roles: roles), form: .scatter,
              xLabel: result.spec.separationLabel, yLabel: result.spec.geneticLabel,
              notes: result.report.notes.map(\.message), extraLayers: Self.lineLayers(result.spec))
        setImage(image, named: Self.figureImageName)
        setImage(thumbnail, named: Self.thumbnailImageName)
    }

    /// Rewrites the R code for the figure's current title and legend, which the code's chunk options carry.
    mutating func refreshIBDCode() {
        guard let spec = ibdSpec, let table else { return }
        store(table, form: .scatter, xLabel: xLabel ?? spec.separationLabel, yLabel: yLabel ?? spec.geneticLabel,
              extraLayers: Self.lineLayers(spec))
    }

    /// The column of a directional analysis saying which way each ordered pair runs.
    static let directionColumn = "Direction"

    /// The ggplot2 layers drawing the regression line, if the analysis has one, or for dcGD the forward (solid) and
    /// reverse (dashed) lines.
    private static func lineLayers(_ spec: IBDSpec) -> [String] {
        if let result = spec.result, result.isDirectional {
            guard let intercept = result.directedIntercept, let forward = result.forwardSlope,
                  let reverse = result.reverseSlope else { return [] }
            return ["geom_abline( intercept = \(rNumber(intercept)), slope = \(rNumber(forward)) )",
                    "geom_abline( intercept = \(rNumber(intercept)), slope = \(rNumber(reverse)), linetype = \"dashed\" )"]
        }
        guard let slope = spec.result?.slope, let intercept = spec.result?.intercept else { return [] }
        return ["geom_abline( intercept = \(rNumber(intercept)), slope = \(rNumber(slope)) )"]
    }

    /// A number for R code, to more digits than a plot shows.
    private static func rNumber(_ value: Double) -> String {
        String(format: "%.8g", value)
    }
}
