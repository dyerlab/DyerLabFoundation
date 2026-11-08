//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IBDControls.swift
//  PopulationGenetics
//
//  The options under the Distance page's isolation-by-distance display, laid
//  out like the structure controls: Estimate, the permutation test and its
//  count, then what is tested (the units, the genetic distance, Rousset's
//  linearization for Φ_ST, ln distance and the correlation). A line
//  underneath says how the test is made. Only units that have both genotypes
//  and coordinates are offered.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import SwiftUI

/// The isolation-by-distance options: what is tested, and the buttons that estimate and test it.
public struct IBDControls: View {
    /// The height of the control area: a row of controls, the description and their spacing.
    private static let height = 72.0

    /// The analysis being defined.
    @Binding public var spec: IBDSpec
    /// The choices the project's data offers.
    public let options: DistanceOptions
    /// The number of permutations a test draws.
    @Binding public var permutations: Int
    /// Whether the analysis is being estimated.
    public let isEstimating: Bool
    /// Whether a permutation test is running.
    public let isTesting: Bool
    /// Whether the estimate on the page can be tested.
    public let canTest: Bool
    /// Estimates the analysis, untested.
    public let estimate: () -> Void
    /// Starts the permutation test.
    public let test: () -> Void
    /// Stops the permutation test.
    public let cancel: () -> Void

    // MARK: - Initialization

    /// Creates the controls.
    ///
    /// - Parameters:
    ///   - spec: The analysis being defined.
    ///   - options: The choices the project's data offers.
    ///   - permutations: The number of permutations a test draws.
    ///   - isEstimating: Whether the analysis is being estimated.
    ///   - isTesting: Whether a permutation test is running.
    ///   - canTest: Whether the estimate on the page can be tested.
    ///   - estimate: Estimates the analysis.
    ///   - test: Starts the test.
    ///   - cancel: Stops the test.
    public init(spec: Binding<IBDSpec>, options: DistanceOptions, permutations: Binding<Int>, isEstimating: Bool,
                isTesting: Bool, canTest: Bool, estimate: @escaping () -> Void, test: @escaping () -> Void,
                cancel: @escaping () -> Void) {
        _spec = spec
        self.options = options
        _permutations = permutations
        self.isEstimating = isEstimating
        self.isTesting = isTesting
        self.canTest = canTest
        self.estimate = estimate
        self.test = test
        self.cancel = cancel
    }

    // MARK: - Body

    /// The controls.
    public var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    running
                    Divider().frame(height: 20)
                    choices
                }
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

    // MARK: - Running

    private var permutationCount: Binding<Int> {
        Binding { permutations } set: { permutations = max(1, $0) }
    }

    @ViewBuilder
    private var running: some View {
        Button("Estimate", systemImage: "play.fill", action: estimate)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Estimate the Mantel correlation with these options (⌘↩)")
            .disabled(isEstimating || isTesting || !Self.offers(spec, in: options))
            .fixedSize()
        if isEstimating {
            ProgressView().controlSize(.small)
        }
        if isTesting {
            Button("Cancel Test", systemImage: "stop.circle", role: .cancel, action: cancel)
                .fixedSize()
        } else {
            Button(spec.isTested ? "Test Again" : "Test Significance", systemImage: "dice", action: test)
                .disabled(!canTest)
                .fixedSize()
        }
        LabeledContent("Permutations") {
            TextField("Permutations", value: permutationCount, format: .number)
                .labelsHidden()
                .frame(width: 80)
        }
        .fixedSize()
        .disabled(isTesting)
    }

    // MARK: - Choices

    @ViewBuilder
    private var choices: some View {
        Picker("Among", selection: level) {
            ForEach(Self.levels(in: options), id: \.self) { level in
                Text(options.label(for: level)).tag(level)
            }
        }
        .fixedSize()
        Picker("Genetic", selection: $spec.genetic.measure) {
            ForEach(Self.measures(at: spec.genetic.level, in: options)) { Text($0.title).tag($0) }
        }
        .fixedSize()
        if spec.genetic.measure == .phiST {
            Toggle("Φ/(1−Φ)", isOn: Binding { spec.transform == .rousset } set: {
                spec.transform = $0 ? .rousset : .none
            })
            .help("Linearize Φ_ST as Φ_ST / (1 − Φ_ST), following Rousset (1997)")
            .fixedSize()
        }
        Toggle("ln distance", isOn: $spec.logSeparation)
            .help("Use the natural log of distance, as Rousset expects for a two-dimensional habitat")
            .fixedSize()
        Picker("Correlation", selection: $spec.method) {
            Text("Pearson").tag(CorrelationMethod.pearson)
            Text("Spearman").tag(CorrelationMethod.spearman)
        }
        .fixedSize()
    }

    /// The level, moving the measure to a genetic one the new level offers.
    private var level: Binding<String> {
        Binding {
            spec.genetic.level
        } set: { level in
            let measures = Self.measures(at: level, in: options)
            let measure = measures.contains(spec.genetic.measure) ? spec.genetic.measure : measures.first
            spec.genetic = DistanceSpec(measure: measure ?? spec.genetic.measure, level: level)
        }
    }

    // MARK: - What the data offers

    /// The levels an analysis can be among: those with coordinates and a genetic distance.
    ///
    /// - Parameter options: What the data offers.
    /// - Returns: The levels, in ``DistanceOptions/levels`` order.
    public static func levels(in options: DistanceOptions) -> [String] {
        options.levels.filter { options.offers(.greatCircle, at: $0) && !measures(at: $0, in: options).isEmpty }
    }

    /// The genetic distances a level offers.
    ///
    /// - Parameters:
    ///   - level: A level.
    ///   - options: What the data offers.
    /// - Returns: The measures.
    public static func measures(at level: String, in options: DistanceOptions) -> [DistanceSpec.Measure] {
        options.measures(at: level).filter(\.isGenetic)
    }

    /// Whether the data can test a spec.
    ///
    /// - Parameters:
    ///   - spec: The analysis.
    ///   - options: What the data offers.
    /// - Returns: `true` when its level has coordinates and offers its genetic distance.
    public static func offers(_ spec: IBDSpec, in options: DistanceOptions) -> Bool {
        options.offers(.greatCircle, at: spec.genetic.level) && options.offers(spec.genetic)
            && spec.genetic.measure.isGenetic
    }

    /// The spec the page starts with: Rousset's Φ_ST among the innermost stratum level, or else the first
    /// genetic distance among the first level that has one.
    ///
    /// - Parameter options: What the data offers.
    /// - Returns: The spec, or `nil` when nothing can be tested.
    public static func defaultSpec(in options: DistanceOptions) -> IBDSpec? {
        let levels = levels(in: options)
        if let level = levels.last(where: { options.offers(.phiST, at: $0) }) {
            return IBDSpec(genetic: DistanceSpec(measure: .phiST, level: level), logSeparation: true)
        }
        guard let level = levels.first, let measure = measures(at: level, in: options).first else { return nil }
        return IBDSpec(genetic: DistanceSpec(measure: measure, level: level))
    }

    // MARK: - Description

    /// How the test is made.
    private var summary: String {
        let genetic = spec.validTransform == .rousset ? "Pairwise Φ_ST linearized as Φ_ST / (1 − Φ_ST) (Rousset 1997)"
            : spec.genetic.measure.title
        let separation = spec.logSeparation ? "the natural log of great-circle distance" : "great-circle distance"
        return "\(genetic) against \(separation) among \(spec.genetic.unitName(isParentOffspring: options.isParentOffspring)), "
            + "by a Mantel test (Mantel 1967) with the \(spec.method.displayName) correlation, permuting units."
    }
}

// MARK: - Previews

#Preview("Populations") {
    @Previewable @State var spec = IBDSpec(logSeparation: true)
    @Previewable @State var permutations = IBDSpec.defaultPermutations
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        IBDControls(spec: $spec, options: DistanceOptions(dataset: dataset), permutations: $permutations,
                    isEstimating: false, isTesting: false, canTest: true, estimate: {}, test: {}, cancel: {})
            .frame(width: 1100)
    }
}

#Preview("Mothers") {
    @Previewable @State var spec = IBDSpec(genetic: DistanceSpec(measure: .bray))
    @Previewable @State var permutations = IBDSpec.defaultPermutations
    if let dataset = try? ExampleDataset.cornusFamilies.load() {
        IBDControls(spec: $spec, options: DistanceOptions(dataset: dataset), permutations: $permutations,
                    isEstimating: false, isTesting: true, canTest: false, estimate: {}, test: {}, cancel: {})
            .frame(width: 1100)
    }
}
