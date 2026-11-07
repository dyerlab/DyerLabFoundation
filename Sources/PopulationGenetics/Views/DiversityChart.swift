//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityChart.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import PresentationZen
import SwiftUI

/// Draws a diversity plot in the form its data calls for, or says why it can't.
public struct DiversityChart: View {
    /// The numbers to draw.
    public let data: DiversityPlotData
    /// The plot's parameters, which name its columns and say how a distribution is drawn.
    public let spec: DiversityPlotSpec

    /// Creates a chart.
    ///
    /// - Parameters:
    ///   - data: The numbers to draw.
    ///   - spec: The plot's parameters.
    public init(data: DiversityPlotData, spec: DiversityPlotSpec) {
        self.data = data
        self.spec = spec
    }

    /// The plot, or a note saying why there isn't one.
    public var body: some View {
        if let plot = data.plot(spec: spec) {
            plot
        } else if case .unavailable(let reason) = data.content {
            ContentUnavailableView("Plot Unavailable", systemImage: "chart.bar.xaxis", description: Text(reason))
        }
    }
}

// MARK: - Previews

#Preview("Histogram") {
    let spec = DiversityPlotSpec()
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        DiversityChart(data: DiversityPlotData(spec: spec, dataset: dataset), spec: spec)
            .padding()
            .frame(width: 600, height: 400)
    }
}

#Preview("Bars by population") {
    let spec = DiversityPlotSpec(response: .Ae, predictor: .population)
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        DiversityChart(data: DiversityPlotData(spec: spec, dataset: dataset), spec: spec)
            .padding()
            .frame(width: 600, height: 400)
    }
}

#Preview("Scatter by latitude") {
    let spec = DiversityPlotSpec(predictor: .latitude)
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        DiversityChart(data: DiversityPlotData(spec: spec, dataset: dataset), spec: spec)
            .padding()
            .frame(width: 600, height: 400)
    }
}
