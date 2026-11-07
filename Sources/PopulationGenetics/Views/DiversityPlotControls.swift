//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotControls.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The controls that define a diversity plot.
///
/// Only those relevant to the current response and predictor are shown, in an area whose height
/// never changes so the plot above doesn't resize as they come and go. A window too narrow for a
/// row scrolls it sideways.
public struct DiversityPlotControls: View {
    /// The height of the control area: three rows of controls and their spacing.
    private static let height = 108.0

    /// The plot being defined.
    @Binding public var spec: DiversityPlotSpec
    /// The choices the project's data offers.
    public let options: DiversityPlotOptions

    // MARK: - Initialization

    /// Creates the controls.
    ///
    /// - Parameters:
    ///   - spec: The plot being defined.
    ///   - options: The choices the project's data offers.
    public init(spec: Binding<DiversityPlotSpec>, options: DiversityPlotOptions) {
        _spec = spec
        self.options = options
    }

    // MARK: - Body

    /// The controls that apply to the current plot.
    public var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) { variables }
                HStack(spacing: 16) { details }
                HStack(spacing: 16) { distributionStyle }
            }
            .padding(10)
            .frame(height: Self.height, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        .background(.bar)
    }

    // MARK: - Variables

    @ViewBuilder
    private var variables: some View {
        Picker("Response", selection: $spec.response) {
            ForEach(DiversityType.frequencyStatistics) { Text($0.label).tag($0) }
        }
        .fixedSize()
        Picker("Predictor", selection: $spec.predictor) {
            ForEach(options.predictors) { Text($0.title).tag($0) }
        }
        .fixedSize()
    }

    // MARK: - Details

    @ViewBuilder
    private var details: some View {
        if spec.predictor == .none {
            Picker("Across", selection: $spec.unit) {
                ForEach(options.units) { Text($0.title).tag($0) }
            }
            .fixedSize()
        }
        if spec.usesSample {
            samplePicker
        }
        if spec.usesLocus {
            Picker("Locus", selection: $spec.locus) {
                Text("Mean across loci").tag(String?.none)
                Divider()
                ForEach(options.loci, id: \.self) { Text($0).tag(String?.some($0)) }
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private var distributionStyle: some View {
        if spec.predictor == .none {
            Picker("Style", selection: $spec.style) {
                ForEach(DiversityPlotSpec.DistributionStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if spec.style == .histogram {
                Stepper("Bins: \(spec.bins)", value: $spec.bins, in: 2...50)
                    .fixedSize()
            }
        }
    }

    private var samplePicker: some View {
        Picker("Sample", selection: $spec.sample) {
            Text("All adults (pooled)").tag(DiversityPlotSpec.Sample.pooled)
            if !options.primaryGroups.isEmpty {
                Text("Mean within \(options.primaryGroupsTitle)").tag(DiversityPlotSpec.Sample.meanWithinGroups)
                Divider()
                ForEach(options.primaryGroups, id: \.name) { group in
                    Text(group.name).tag(DiversityPlotSpec.Sample.group(name: group.name))
                }
            }
        }
        .fixedSize()
    }
}

// MARK: - Previews

#Preview("Adult structure") {
    @Previewable @State var spec = DiversityPlotSpec()
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        DiversityPlotControls(spec: $spec, options: DiversityPlotOptions(dataset: dataset))
            .frame(width: 800)
    }
}

#Preview("Families, narrow") {
    @Previewable @State var spec = DiversityPlotSpec()
    if let dataset = try? ExampleDataset.cornusFamilies.load() {
        DiversityPlotControls(spec: $spec, options: DiversityPlotOptions(dataset: dataset))
            .frame(width: 480)
    }
}
