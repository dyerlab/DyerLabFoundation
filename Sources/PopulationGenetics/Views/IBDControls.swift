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
//  The options under the Isolation builder, as a formula and its buttons: the first row is `Genetic ~ Against`
//  (the units, the genetic distance, what it is tested against — great-circle distance for isolation by distance,
//  or another genetic distance for a Mantel test between two matrices — and their transforms and correlation); the
//  second runs it (Estimate, the permutation test, Stop, Save). A line underneath says how the test is made.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import SwiftUI

/// The isolation options: what is tested against what, and the buttons that estimate, test and save it.
public struct IBDControls: View {
    /// The height of the control area: two rows of controls, the description and their spacing.
    private static let height = 104.0

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
    /// Stops the permutation test, which finishes it with the permutations drawn so far.
    public let cancel: () -> Void
    /// Whether the page shows an analysis that can be saved.
    public let canSave: Bool
    /// Files the analysis as a result, or `nil` for no Save button.
    public let save: (() -> Void)?

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
    ///   - cancel: Stops the test, which finishes it with the permutations drawn so far.
    ///   - canSave: Whether the page shows an analysis that can be saved (default `false`).
    ///   - save: Files the analysis as a result, shown as a Save button; `nil` (the default) for none.
    public init(spec: Binding<IBDSpec>, options: DistanceOptions, permutations: Binding<Int>, isEstimating: Bool,
                isTesting: Bool, canTest: Bool, estimate: @escaping () -> Void, test: @escaping () -> Void,
                cancel: @escaping () -> Void, canSave: Bool = false, save: (() -> Void)? = nil) {
        _spec = spec
        self.options = options
        _permutations = permutations
        self.isEstimating = isEstimating
        self.isTesting = isTesting
        self.canTest = canTest
        self.estimate = estimate
        self.test = test
        self.cancel = cancel
        self.canSave = canSave
        self.save = save
    }

    // MARK: - Body

    /// The controls.
    public var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) { choices }
                HStack(spacing: 16) { running }
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

    // MARK: - Choices

    @ViewBuilder
    private var choices: some View {
        Picker("Among", selection: level) {
            ForEach(Self.levels(in: options), id: \.self) { level in
                Text(options.label(for: level)).tag(level)
            }
        }
        .fixedSize()
        Picker("Genetic", selection: genetic) {
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
        Text("~")
            .font(.title3)
            .foregroundStyle(.secondary)
        Picker("Against", selection: $spec.against) {
            let against = Self.againstMeasures(for: spec.genetic, in: options)
            if against.contains(.greatCircle) {
                Section("Geographic") {
                    Text(DistanceSpec.Measure.greatCircle.title).tag(DistanceSpec.Measure.greatCircle)
                }
            }
            Section("Genetic") {
                ForEach(against.filter(\.isGenetic)) { Text($0.title).tag($0) }
            }
        }
        .fixedSize()
        Toggle("ln", isOn: $spec.logSeparation)
            .help("Use the natural log of the distances tested against, as Rousset expects for a two-dimensional "
                  + "habitat")
            .fixedSize()
        Picker("Correlation", selection: $spec.method) {
            Text("Pearson").tag(CorrelationMethod.pearson)
            Text("Spearman").tag(CorrelationMethod.spearman)
        }
        .fixedSize()
    }

    /// The level, moving both measures to ones the new level offers.
    private var level: Binding<String> {
        Binding {
            spec.genetic.level
        } set: { level in
            let measures = Self.measures(at: level, in: options)
            let measure = measures.contains(spec.genetic.measure) ? spec.genetic.measure : measures.first
            spec.genetic = DistanceSpec(measure: measure ?? spec.genetic.measure, level: level)
            keepAgainstValid()
        }
    }

    /// The genetic distance, moving what it is tested against if that would be itself.
    private var genetic: Binding<DistanceSpec.Measure> {
        Binding {
            spec.genetic.measure
        } set: { measure in
            spec.genetic.measure = measure
            keepAgainstValid()
        }
    }

    /// Moves `against` to great-circle distance, or else the first other measure, when the level no longer offers it.
    private func keepAgainstValid() {
        let offered = Self.againstMeasures(for: spec.genetic, in: options)
        guard !offered.contains(spec.against) else { return }
        spec.against = offered.contains(.greatCircle) ? .greatCircle : offered.first ?? .greatCircle
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
            Button("Stop Test", systemImage: "stop.circle", role: .cancel, action: cancel)
                .help("Stop permuting and finish the test with the permutations drawn so far")
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
        if let save {
            Button("Save", systemImage: "square.and.arrow.down", action: save)
                .keyboardShortcut("s", modifiers: [.command, .option])
                .help("File this analysis as a result under Isolation (⌥⌘S)")
                .disabled(!canSave)
                .fixedSize()
        }
    }

    // MARK: - What the data offers

    /// The levels an analysis can be among: those with a genetic distance and something to test it against.
    ///
    /// - Parameter options: What the data offers.
    /// - Returns: The levels, in ``DistanceOptions/levels`` order.
    public static func levels(in options: DistanceOptions) -> [String] {
        options.levels.filter { level in
            measures(at: level, in: options).contains { measure in
                !againstMeasures(for: DistanceSpec(measure: measure, level: level), in: options).isEmpty
            }
        }
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

    /// What a genetic distance can be tested against at its level: great-circle distance, if the units have
    /// coordinates, and every other genetic distance there.
    ///
    /// - Parameters:
    ///   - genetic: The genetic distances.
    ///   - options: What the data offers.
    /// - Returns: The measures, great-circle distance first.
    public static func againstMeasures(for genetic: DistanceSpec, in options: DistanceOptions)
        -> [DistanceSpec.Measure] {
        options.measures(at: genetic.level).filter { $0 != genetic.measure && ($0 == .greatCircle || $0.isGenetic) }
            .sorted { a, _ in a == .greatCircle }
    }

    /// Whether the data can test a spec.
    ///
    /// - Parameters:
    ///   - spec: The analysis.
    ///   - options: What the data offers.
    /// - Returns: `true` when its level offers its genetic distance and what it is tested against.
    public static func offers(_ spec: IBDSpec, in options: DistanceOptions) -> Bool {
        spec.genetic.measure.isGenetic && options.offers(spec.genetic)
            && againstMeasures(for: spec.genetic, in: options).contains(spec.against)
    }

    /// The spec the page starts with: Rousset's Φ_ST against ln great-circle distance among the innermost stratum
    /// level, or else the first genetic distance among the first level that has one.
    ///
    /// - Parameter options: What the data offers.
    /// - Returns: The spec, or `nil` when nothing can be tested.
    public static func defaultSpec(in options: DistanceOptions) -> IBDSpec? {
        let levels = levels(in: options)
        if let level = levels.last(where: { options.offers(.phiST, at: $0) && options.offers(.greatCircle, at: $0) }) {
            return IBDSpec(genetic: DistanceSpec(measure: .phiST, level: level), logSeparation: true)
        }
        guard let level = levels.first, let measure = measures(at: level, in: options).first,
              let against = againstMeasures(for: DistanceSpec(measure: measure, level: level), in: options).first
        else { return nil }
        return IBDSpec(genetic: DistanceSpec(measure: measure, level: level), against: against)
    }

    // MARK: - Description

    /// How the test is made.
    private var summary: String {
        let genetic = spec.validTransform == .rousset
            ? "Pairwise Φ_ST linearized as Φ_ST / (1 − Φ_ST) (Rousset 1997)" : spec.genetic.measure.title
        let against = (spec.logSeparation ? "the natural log of " : "") + spec.separationPhrase
        let units = spec.genetic.unitName(isParentOffspring: options.isParentOffspring)
        return "\(spec.formula): \(genetic) against \(against) among \(units), "
            + "by a Mantel test (Mantel 1967) with the \(spec.method.displayName) correlation, permuting units."
    }
}

// MARK: - Previews

#Preview("Populations") {
    @Previewable @State var spec = IBDSpec(logSeparation: true)
    @Previewable @State var permutations = IBDSpec.defaultPermutations
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        IBDControls(spec: $spec, options: DistanceOptions(dataset: dataset), permutations: $permutations,
                    isEstimating: false, isTesting: false, canTest: true, estimate: {}, test: {}, cancel: {},
                    canSave: true, save: {})
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
