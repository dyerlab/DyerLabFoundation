//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureControls.swift
//  PopulationGenetics
//
//  The options under a structure table, laid out like the diversity plot's
//  controls. Nothing is computed until Estimate is pressed, since a dataset
//  with many loci takes a while, and the permutation test runs only from its
//  own button. A line under the options says what the chosen statistic is,
//  or which Hs and Ht estimator a by-locus table uses, in the words its legend
//  and Methods use, and warns before estimating when a locus has too many
//  alleles for Gst or too few for Dest.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The table, statistic, Hs and Ht estimator, loci, stratum and significance-test options of a structure analysis.
public struct StructureControls: View {
    /// The height of the control area: two rows of controls, the description and their spacing.
    private static let height = 104.0

    /// The analysis being defined.
    @Binding public var spec: StructureSpec
    /// The choices the project's data offers.
    public let options: StructureOptions
    /// The number of permutations the next test draws.
    @Binding public var permutations: Int
    /// Whether the table is being estimated.
    public let isEstimating: Bool
    /// Whether a test is running.
    public let isTesting: Bool
    /// Whether the page shows an estimate the test can start from.
    public let canTest: Bool
    /// Estimates the table.
    public let estimate: () -> Void
    /// Starts a test.
    public let test: () -> Void
    /// Stops the running test, which finishes it with the permutations drawn so far.
    public let cancel: () -> Void
    /// Whether the page shows a table that can be saved.
    public let canSave: Bool
    /// Files the table as a result, or `nil` for no Save button.
    public let save: (() -> Void)?

    // MARK: - Initialization

    /// Creates the controls.
    ///
    /// - Parameters:
    ///   - spec: The analysis being defined.
    ///   - options: The choices the project's data offers.
    ///   - permutations: The number of permutations the next test draws.
    ///   - isEstimating: Whether the table is being estimated.
    ///   - isTesting: Whether a test is running.
    ///   - canTest: Whether the page shows an estimate the test can start from.
    ///   - estimate: Estimates the table.
    ///   - test: Starts a test.
    ///   - cancel: Stops the running test, which finishes it with the permutations drawn so far.
    ///   - canSave: Whether the page shows a table that can be saved (default `false`).
    ///   - save: Files the table as a result, shown as a Save button; `nil` (the default) for none.
    public init(spec: Binding<StructureSpec>,
                options: StructureOptions,
                permutations: Binding<Int>,
                isEstimating: Bool,
                isTesting: Bool,
                canTest: Bool,
                estimate: @escaping () -> Void,
                test: @escaping () -> Void,
                cancel: @escaping () -> Void,
                canSave: Bool = false,
                save: (() -> Void)? = nil) {
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
                HStack(spacing: 16) { analysis }
                HStack(spacing: 16) { running }
                description
            }
            .padding(10)
            .frame(height: Self.height, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        .background(.bar)
    }

    // MARK: - Analysis

    @ViewBuilder
    private var analysis: some View {
        Picker("Table", selection: $spec.table) {
            ForEach(StructureSpec.Table.allCases) { Text($0.title).tag($0) }
        }
        .fixedSize()
        switch spec.table {
        case .amova:
            let choices = StructureSpec.Statistic.choices(for: options.sample)
            if choices.count > 1 {
                Picker("Statistic", selection: $spec.statistic) {
                    ForEach(choices) { Text($0.title).tag($0) }
                }
                .fixedSize()
            } else {
                Text(spec.statistic.title).foregroundStyle(.secondary)
            }
        case .perLocus:
            let choices = StructureSpec.Column.choices(for: options.sample)
            if choices.count > 1 {
                Menu("Statistics: \(spec.columns.map(\.header).joined(separator: ", "))") {
                    ForEach(choices) { column in
                        Toggle(column.title, isOn: shows(column, among: choices))
                    }
                }
                .fixedSize()
            }
            if options.sample == .adults {
                Picker("Hs and Ht", selection: $spec.heterozygosity) {
                    ForEach(StructureSpec.Heterozygosity.allCases) { Text($0.title).tag($0) }
                }
                .fixedSize()
                .help(spec.heterozygosity.summary)
            }
        }
        Picker("Loci", selection: $spec.locus) {
            Text("All loci").tag(String?.none)
            Divider()
            ForEach(options.loci, id: \.self) { Text($0).tag(String?.some($0)) }
        }
        .fixedSize()
        if options.hasLevelChoice {
            Picker("Stratum", selection: $spec.level) {
                ForEach(options.levels, id: \.self) { Text($0).tag($0) }
            }
            .fixedSize()
        }
    }

    /// Whether a by-locus table shows a column; the last column can't be turned off.
    private func shows(_ column: StructureSpec.Column, among choices: [StructureSpec.Column]) -> Binding<Bool> {
        Binding {
            spec.columns.contains(column)
        } set: { isOn in
            var columns = Set(spec.columns)
            if isOn { columns.insert(column) } else if columns.count > 1 { columns.remove(column) }
            spec.columns = choices.filter(columns.contains)
        }
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
            .help("Estimate the table with these options (⌘↩)")
            .disabled(isEstimating || isTesting)
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
                .help("File this table as a result under Structure (⌥⌘S)")
                .disabled(!canSave)
                .fixedSize()
        }
    }

    // MARK: - Description

    @ViewBuilder
    private var description: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary)
                .foregroundStyle(.secondary)
            if let concerns = options.concerns(for: spec) {
                Label(concerns, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    /// What the chosen table shows: the statistic, or for a by-locus table of adults how Hs and Ht are estimated,
    /// since that choice moves Gst, G′st and Dest.
    private var summary: String {
        switch spec.table {
        case .amova:
            spec.statistic.summary
        case .perLocus where options.sample == .adults:
            spec.heterozygosity.summary
        case .perLocus:
            "One row per locus, then a multilocus row that divides each statistic's numerator and denominator "
                + "summed over loci rather than averaging the loci."
        }
    }
}

// MARK: - Previews

#Preview("Adults") {
    @Previewable @State var spec = StructureSpec(level: "Population")
    @Previewable @State var permutations = StructureSpec.defaultPermutations
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        StructureControls(spec: $spec, options: StructureOptions(dataset: dataset, sample: .adults),
                          permutations: $permutations, isEstimating: false, isTesting: false, canTest: true,
                          estimate: {}, test: {}, cancel: {})
            .frame(width: 900)
    }
}

#Preview("By locus") {
    @Previewable @State var spec = StructureSpec(table: .perLocus, level: "Population")
    @Previewable @State var permutations = StructureSpec.defaultPermutations
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        StructureControls(spec: $spec, options: StructureOptions(dataset: dataset, sample: .adults),
                          permutations: $permutations, isEstimating: false, isTesting: false, canTest: false,
                          estimate: {}, test: {}, cancel: {})
            .frame(width: 900)
    }
}

#Preview("Paternal gametes") {
    @Previewable @State var spec = StructureSpec(sample: .paternalGametes, level: StructureSpec.familyLevel,
                                                 permutations: 999, seed: 1)
    @Previewable @State var permutations = 999
    if let dataset = try? ExampleDataset.cornusFamilies.load() {
        StructureControls(spec: $spec, options: StructureOptions(dataset: dataset, sample: .paternalGametes),
                          permutations: $permutations, isEstimating: false, isTesting: true, canTest: true,
                          estimate: {}, test: {}, cancel: {})
            .frame(width: 900)
    }
}
