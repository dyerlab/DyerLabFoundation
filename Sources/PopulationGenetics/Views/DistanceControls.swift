//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceControls.swift
//  PopulationGenetics
//
//  The options under the Distance page's display, laid out like the
//  diversity plot's controls: what the matrix is among, how distance is
//  measured, and a Compute button. A line underneath says how the chosen
//  matrix is computed, in the words its log entry uses. The measure menu lists
//  only what the chosen level offers, physical then genetic, and moving to a
//  level that lacks the measure picks the level's first.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The level, measure and Compute button of a distance matrix.
public struct DistanceControls: View {
    /// The height of the control area: a row of controls, the description and their spacing.
    private static let height = 72.0

    /// The matrix being defined.
    @Binding public var spec: DistanceSpec
    /// The choices the project's data offers.
    public let options: DistanceOptions
    /// Whether the matrix is being computed.
    public let isComputing: Bool
    /// Computes the matrix.
    public let compute: () -> Void

    // MARK: - Initialization

    /// Creates the controls.
    ///
    /// - Parameters:
    ///   - spec: The matrix being defined.
    ///   - options: The choices the project's data offers.
    ///   - isComputing: Whether the matrix is being computed.
    ///   - compute: Computes the matrix.
    public init(spec: Binding<DistanceSpec>, options: DistanceOptions, isComputing: Bool,
                compute: @escaping () -> Void) {
        _spec = spec
        self.options = options
        self.isComputing = isComputing
        self.compute = compute
    }

    // MARK: - Body

    /// The controls.
    public var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) { controls }
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(height: Self.height, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        .background(.bar)
    }

    @ViewBuilder
    private var controls: some View {
        Button("Compute", systemImage: "play.fill", action: compute)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Compute the matrix with these options (⌘↩)")
            .disabled(isComputing || !options.offers(spec))
            .fixedSize()
        if isComputing {
            ProgressView().controlSize(.small)
        }
        Picker("Among", selection: level) {
            ForEach(options.levels, id: \.self) { level in
                let count = options.unitCount(at: level, for: options.spec(spec, movedTo: level).measure)
                Text("\(options.label(for: level)) (\(count.formatted()))").tag(level)
            }
        }
        .fixedSize()
        Picker("Measure", selection: $spec.measure) {
            let measures = options.measures(at: spec.level)
            let physical = measures.filter { !$0.isGenetic }
            if !physical.isEmpty {
                Section("Physical") {
                    ForEach(physical) { Text($0.title).tag($0) }
                }
            }
            Section("Genetic") {
                ForEach(measures.filter(\.isGenetic)) { Text($0.title).tag($0) }
            }
        }
        .fixedSize()
    }

    /// The level, moving the measure to one the new level offers.
    private var level: Binding<String> {
        Binding(get: { spec.level }, set: { spec = options.spec(spec, movedTo: $0) })
    }

    /// How the chosen matrix is computed.
    private var summary: String {
        let count = options.unitCount(at: spec.level, for: spec.measure).formatted()
        let among: String
        if spec.isAmongIndividuals {
            let mothers = options.isParentOffspring
                ? (spec.measure.isGenetic ? " (offspring are left out)" : " (offspring share their mother's location)")
                : ""
            among = "\(count) \(spec.unitName(isParentOffspring: options.isParentOffspring))" + mothers
        } else if spec.measure.isGenetic {
            among = "\(count) \(spec.level) strata"
        } else {
            among = "\(count) \(spec.level) centroids, each the mean of its distinct coordinates"
        }
        return spec.measure.methods + ", among " + among + "."
    }
}

// MARK: - Previews

#Preview("Adults") {
    @Previewable @State var spec = DistanceSpec(level: "Population")
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        DistanceControls(spec: $spec, options: DistanceOptions(dataset: dataset), isComputing: false, compute: {})
            .frame(width: 900)
    }
}

#Preview("Mothers") {
    @Previewable @State var spec = DistanceSpec()
    if let dataset = try? ExampleDataset.cornusFamilies.load() {
        DistanceControls(spec: $spec, options: DistanceOptions(dataset: dataset), isComputing: true, compute: {})
            .frame(width: 900)
    }
}
