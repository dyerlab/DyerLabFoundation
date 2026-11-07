//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredFigure+DiversityPlot.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

public extension FigureGenerator {
    /// A diversity plot: ``DiversityPlotSpec`` JSON in the figure's `spec`.
    static let diversityPlot = FigureGenerator(rawValue: "diversity_plot")
}

public extension StoredFigure {

    /// Creates a figure from a diversity plot, with its current values.
    ///
    /// - Parameters:
    ///   - id: The figure's identity.
    ///   - title: The figure's title.
    ///   - legend: The figure's legend.
    ///   - source: The program making the figure.
    ///   - spec: The plot's parameters, stored so the figure can follow its data.
    ///   - data: The plot's current numbers.
    ///   - thumbnail: A PNG of the plot, if there is one. It does not follow data changes.
    ///   - createdAt: When the figure was made.
    /// - Throws: `EncodingError` if the parameters can't be encoded.
    init(id: UUID = UUID(),
         title: String,
         legend: String,
         source: String,
         spec: DiversityPlotSpec,
         data: DiversityPlotData?,
         thumbnail: Data?,
         createdAt: Date = Date()) throws {
        self.init(id: id, title: title, legend: legend, source: source, createdAt: createdAt)
        setImage(thumbnail, named: Self.thumbnailImageName)
        try setDiversitySpec(spec, data: data)
    }

    /// The figure's diversity plot parameters, or `nil` if it isn't a diversity plot this version can read.
    var diversitySpec: DiversityPlotSpec? {
        guard generator == .diversityPlot, let spec else { return nil }
        return try? JSONDecoder().decode(DiversityPlotSpec.self, from: Data(spec.utf8))
    }

    /// Makes the figure a diversity plot with these parameters.
    ///
    /// - Parameters:
    ///   - spec: The plot's parameters.
    ///   - data: The plot's current numbers, if known.
    /// - Throws: `EncodingError` if the parameters can't be encoded.
    mutating func setDiversitySpec(_ spec: DiversityPlotSpec, data: DiversityPlotData?) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        generator = .diversityPlot
        self.spec = String(decoding: try encoder.encode(spec), as: UTF8.self)
        if let data { storeValues(of: data, spec: spec) }
    }

    /// The figure with its values and R code recomputed, so what R reads matches the project's genotypes.
    ///
    /// A plot that can no longer be drawn, such as one naming a deleted locus, keeps its last values.
    ///
    /// - Parameter dataset: The current genotypes.
    /// - Returns: The refreshed figure, or the figure unchanged if it isn't a diversity plot.
    func refreshed(from dataset: ImportedDataset) -> StoredFigure {
        guard let spec = diversitySpec else { return self }
        var figure = self
        figure.storeValues(of: DiversityPlotData(spec: spec, dataset: dataset), spec: spec)
        return figure
    }

    private mutating func storeValues(of data: DiversityPlotData, spec: DiversityPlotSpec) {
        guard let table = data.dataTable(spec: spec), let form = data.plotForm(spec: spec) else { return }
        store(table, form: form, xLabel: data.xLabel, yLabel: data.yLabel, notes: data.exportNotes)
    }
}
