//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureAnalysis.swift
//  PopulationGenetics
//
//  Prepares and runs the analysis a `StructureSpec` describes, from allele
//  counts within strata (`StructureLoci`), with no distance matrix. Adults are
//  pooled into the strata of the chosen level; offspring lose their mother's
//  contribution first (2Gener) and their paternal gametes are pooled instead,
//  by family or by any level an offspring or its mother has. Each locus uses
//  the units genotyped there, and every multilocus value is a ratio of sums
//  over loci. Permutations move whole individuals (or gametes) among strata.
//  The AMOVA statistic is always labelled Φ_ST, never Φ_FT or Φ_PT.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// A prepared genetic structure analysis: the variance components of Φ_ST or θ, or the statistics locus by
/// locus, as a ``StructureSpec`` asks.
///
/// ## Usage
///
/// ```swift
/// let options = StructureOptions(dataset: dataset, sample: .adults)
/// if let spec = options.defaultSpec,
///    let analysis = StructureAnalysis(spec: spec, dataset: dataset),
///    let result = analysis.run() {
///     print(result.statistic ?? .nan)
/// }
/// ```
public struct StructureAnalysis: Sendable {

    /// The parameters.
    public let spec: StructureSpec

    /// The decisions made about the data before the analysis itself.
    public let notes: [AnalysisNote]

    /// The genotypes, locus by locus.
    let data: StructureLoci

    // MARK: - Initialization

    /// Gathers the sample, groups it by the spec's level and reads its genotypes locus by locus.
    ///
    /// - Parameters:
    ///   - spec: The parameters.
    ///   - dataset: The genotypes.
    /// - Returns: `nil` if the locus is unknown, or no locus has two strata with more units than strata once
    ///   units without a stratum or a genotype are left out.
    public init?(spec: StructureSpec, dataset: ImportedDataset) {
        let lociIndices: [Int]
        if let locus = spec.locus {
            guard let j = dataset.matrix.loci.firstIndex(where: { $0.name == locus }) else { return nil }
            lociIndices = [j]
        } else {
            lociIndices = Array(0..<dataset.matrix.locusCount)
        }
        guard !lociIndices.isEmpty else { return nil }

        let mothers = StructureOptions.mothers(in: dataset)
        func stratum(of ordinal: Int) -> String? {
            let name = StructureOptions.references(of: ordinal, in: dataset, mothers: mothers)
                .first { $0.level == spec.level }?.name
            return name?.isEmpty == false ? name : nil
        }
        var notes: [AnalysisNote] = []
        let data: StructureLoci

        switch spec.sample {
        case .adults:
            let adults = dataset.adultOrdinals
            let ordinals = adults.filter { stratum(of: $0) != nil }
            if ordinals.count < adults.count {
                notes.append(AnalysisNote(.assumption, "\(adults.count - ordinals.count) individuals with no "
                                          + "\(spec.level.lowercased()) were left out."))
            }
            let (adultLoci, incomplete) = StructureLoci.adults(matrix: dataset.matrix, ordinals: ordinals,
                                                               strata: ordinals.map { stratum(of: $0) ?? "" },
                                                               loci: lociIndices,
                                                               heterozygosity: spec.heterozygosity)
            if incomplete > 0, lociIndices.count > 1 {
                notes.append(AnalysisNote(.assumption, "\(incomplete) individuals lacked a diploid genotype "
                                          + "at one or more loci; each locus used the individuals genotyped there."))
            } else if incomplete > 0 {
                notes.append(AnalysisNote(.assumption, "\(incomplete) individuals without a diploid genotype "
                                          + "at \(spec.locus ?? "the locus") were left out."))
            }
            data = adultLoci

        case .paternalGametes:
            let gametes = TwoGenerGametes(matrix: dataset.matrix, design: dataset.parentage,
                                          method: .expectationMaximization, loci: lociIndices, distances: false)
            notes += gametes.notes
            let families = dataset.parentage.families
            let labels: [String?] = zip(gametes.offspring, gametes.partition).map { child, family in
                spec.level == StructureSpec.familyLevel ? families[family].id : stratum(of: child)
            }
            let kept = labels.indices.filter { labels[$0] != nil }
            if kept.count < labels.count {
                notes.append(AnalysisNote(.assumption, "\(labels.count - kept.count) paternal gametes whose "
                                          + "offspring and mother have no \(spec.level.lowercased()) were left out."))
            }
            let (partition, strata) = StructureLoci.partition(kept.map { labels[$0] ?? "" })
            let count = gametes.offspring.count
            let loci = gametes.locusScores.map { locus, scores -> StructureLoci.Locus in
                let slots = count > 0 ? scores.count / count : 1
                var keptScores = [Double]()
                keptScores.reserveCapacity(kept.count * slots)
                for g in kept { keptScores.append(contentsOf: scores[(g * slots)..<((g + 1) * slots)]) }
                return StructureLoci.Locus(name: dataset.matrix.loci[locus].name, alleleSlots: slots,
                                           units: Array(kept.indices), genotypes: .scored(keptScores))
            }
            data = StructureLoci(loci: loci, partition: partition, strata: strata)
        }

        var workspace = data.makeWorkspace()
        guard data.strata.count >= 2,
              data.components(partition: data.partition, workspace: &workspace).contains(where: { $0 != nil })
        else { return nil }
        self.spec = spec
        self.notes = notes
        self.data = data
    }

    // MARK: - Running

    /// The options the spec runs with.
    public var options: AnalysisOptions {
        AnalysisOptions(iterations: spec.permutations, seed: spec.seed ?? 0)
    }

    /// The number of individuals or gametes analysed.
    public var unitCount: Int { data.unitCount }

    /// The number of strata analysed.
    public var strataCount: Int { data.strata.count }

    /// The number of loci read.
    public var locusCount: Int { data.loci.count }

    /// Runs the analysis and its test, if the spec asks for one.
    ///
    /// - Parameter progress: Called after each permutation with the number done; return `false` to stop.
    /// - Returns: The table and report, or `nil` if `progress` stopped the test.
    public func run(progress: (Int) -> Bool = { _ in true }) -> StructureResult? {
        run(observing: { done, _ in progress(done) })
    }

    /// Runs the analysis and its test, if the spec asks for one, handing over each permuted value of the followed
    /// statistic as it is drawn so the null distribution and P can be shown forming.
    ///
    /// - Parameter observing: Called after each permutation with the number done and its statistic; return
    ///   `false` to stop.
    /// - Returns: The table and report, or `nil` if `observing` stopped the test.
    public func run(observing: (_ done: Int, _ value: Double) -> Bool) -> StructureResult? {
        switch spec.table {
        case .amova: varianceComponents(observing: observing)
        case .perLocus: byLocus(observing: observing)
        }
    }

    /// Every locus's components and their sum under a labelling.
    func evaluate(_ partition: [Int], workspace: inout StructureLoci.Workspace)
        -> (loci: [LocusComponents?], total: LocusComponents?) {
        let loci = data.components(partition: partition, workspace: &workspace)
        let total = loci.compactMap { $0 }.reduce(nil as LocusComponents?) { sum, next in sum.map { $0 + next } ?? next }
        return (loci, total)
    }

    // MARK: - Variance components

    private func varianceComponents(observing: (Int, Double) -> Bool) -> StructureResult? {
        let statistic = spec.statistic
        var workspace = data.makeWorkspace()
        guard let parts = evaluate(data.partition, workspace: &workspace).total?.parts(statistic) else { return nil }
        var null: NullDistributionResult?
        if spec.isTested {
            null = Resampling.permutationTest(labels: data.partition, iterations: spec.permutations,
                                              seed: options.seed, tag: tag, observing: observing) { labels in
                evaluate(labels, workspace: &workspace).total?.parts(statistic)?.amongShare ?? .nan
            }
            guard null != nil else { return nil }
        }
        let p = null?.pValue(direction: .greaterOrEqual)
        let rows = tableRows(parts, p: p)
        return StructureResult(spec: spec, rows: rows, statistic: parts.amongShare, pValue: p,
                               report: report(rows: rows, parts: parts, p: p), distribution: null)
    }

    /// A variance-components table's rows.
    private func tableRows(_ parts: VarianceParts, p: Double?) -> [StructureTableRow] {
        func ms(_ i: Int) -> Double? { parts.df[i].map { parts.ss[i] / Double($0) } }
        let dfTotal = parts.df.allSatisfy { $0 != nil } ? parts.df.compactMap { $0 }.reduce(0, +) : nil
        let ssTotal = parts.ss.reduce(0, +)
        let sigma = parts.sigma
        if spec.statistic == .theta {
            let all = sigma.reduce(0, +)
            return [
                StructureTableRow(source: spec.level, df: parts.df[0], ss: parts.ss[0], ms: ms(0), sigma: sigma[0],
                                  statistic: sigma[0] / all, p: p),
                StructureTableRow(source: StructureTableRow.individualSource, df: parts.df[1], ss: parts.ss[1],
                                  ms: ms(1), sigma: sigma[1], statistic: sigma[1] / (sigma[1] + sigma[2])),
                StructureTableRow(source: StructureTableRow.errorSource, df: parts.df[2], ss: parts.ss[2],
                                  ms: ms(2), sigma: sigma[2]),
                StructureTableRow(source: StructureTableRow.totalSource, df: dfTotal, ss: ssTotal, sigma: all,
                                  statistic: (sigma[0] + sigma[1]) / all),
            ]
        }
        return [
            StructureTableRow(source: spec.level, df: parts.df[0], ss: parts.ss[0], ms: ms(0), sigma: sigma[0],
                              statistic: parts.amongShare, p: p),
            StructureTableRow(source: StructureTableRow.errorSource, df: parts.df[1], ss: parts.ss[1], ms: ms(1),
                              sigma: sigma[1]),
            StructureTableRow(source: StructureTableRow.totalSource, df: dfTotal, ss: ssTotal,
                              sigma: sigma[0] + sigma[1]),
        ]
    }

    // MARK: - By locus

    private func byLocus(observing: (Int, Double) -> Bool) -> StructureResult? {
        var workspace = data.makeWorkspace()
        let observed = evaluate(data.partition, workspace: &workspace)
        guard let total = observed.total else { return nil }
        let columns = spec.columns
        let tested = spec.isTested ? spec.testedColumns : []
        let multilocus = data.loci.count > 1

        // The tested cells, loci first and the multilocus row last.
        func cells(_ evaluation: (loci: [LocusComponents?], total: LocusComponents?)) -> [Double] {
            var values: [Double] = []
            for locus in evaluation.loci { for column in tested { values.append(locus?.value(column) ?? .nan) } }
            if multilocus { for column in tested { values.append(evaluation.total?.value(column) ?? .nan) } }
            return values
        }
        var p: [Double?] = []
        var null: NullDistributionResult?
        if let followed = tested.first {
            let target = cells(observed)
            var extreme = [Int](repeating: 0, count: target.count)
            var values: [Double] = []
            values.reserveCapacity(spec.permutations)
            var rng = SplitMix64(seed: options.seed)
            var shuffled = data.partition
            for iteration in 0..<spec.permutations {
                shuffled.shuffle(using: &rng)
                let evaluation = evaluate(shuffled, workspace: &workspace)
                for (i, value) in cells(evaluation).enumerated() where value >= target[i] { extreme[i] += 1 }
                let value = evaluation.total?.value(followed) ?? .nan
                values.append(value)
                guard observing(iteration + 1, value) else { return nil }
            }
            p = zip(target, extreme).map { observed, count in
                observed.isFinite ? Double(count + 1) / Double(spec.permutations + 1) : nil
            }
            null = NullDistributionResult(analysisType: tag, observed: total.value(followed), values: values,
                                          seed: options.seed)
        }

        // Rows, and the statistics flagged at each locus.
        let thresholds = spec.thresholds
        var gstLoci: [String] = [], destLoci: [String] = []
        var rows: [StructureLocusRow] = []
        for (l, locus) in data.loci.enumerated() {
            let components = observed.loci[l]
            let alleles = components?.alleles ?? 0
            var concerns: [String] = []
            if spec.sample == .adults, let components {
                if columns.contains(.gst), let reason = thresholds.gstConcern(alleles: alleles, hs: components.hs) {
                    concerns.append("Gst: " + reason)
                    gstLoci.append(locus.name)
                }
                if columns.contains(.dest), let reason = thresholds.destConcern(alleles: alleles, hs: components.hs) {
                    concerns.append("Dest: " + reason)
                    destLoci.append(locus.name)
                }
            }
            rows.append(StructureLocusRow(
                locus: locus.name, units: components?.units ?? 0, alleles: alleles,
                hs: spec.sample == .adults ? components?.hs : nil, ht: spec.sample == .adults ? components?.ht : nil,
                values: columns.map { column in components.map { Self.finite($0.value(column)) } ?? nil },
                p: tested.isEmpty ? [] : Array(p[(l * tested.count)..<((l + 1) * tested.count)]),
                concerns: concerns))
        }
        if multilocus {
            let offset = data.loci.count * tested.count
            rows.append(StructureLocusRow(
                locus: StructureLocusRow.multilocusName, units: data.unitCount, alleles: nil,
                hs: spec.sample == .adults ? total.hs : nil, ht: spec.sample == .adults ? total.ht : nil,
                values: columns.map { Self.finite(total.value($0)) },
                p: tested.isEmpty ? [] : Array(p[offset..<(offset + tested.count)])))
        }

        var warnings: [String] = []
        if !gstLoci.isEmpty {
            warnings.append("Gst is flagged at \(gstLoci.joined(separator: ", ")): \(thresholds.gstReason).")
        }
        if !destLoci.isEmpty {
            warnings.append("Dest is flagged at \(destLoci.joined(separator: ", ")): \(thresholds.destReason).")
        }
        let followed = tested.first ?? columns.first
        let statistic = followed.map { Self.finite(total.value($0)) } ?? nil
        let followedP = multilocus ? rows.last?.p.first ?? nil : rows.first?.p.first ?? nil
        return StructureResult(spec: spec, locusRows: rows, statistic: statistic, pValue: followedP,
                               warnings: warnings,
                               report: report(rows: rows, warnings: warnings), distribution: null)
    }

    /// A value, or `nil` if it isn't finite.
    private static func finite(_ value: Double) -> Double? { value.isFinite ? value : nil }

    /// The label for outcomes.
    var tag: AnalysisTag {
        switch (spec.table, spec.statistic) {
        case (.perLocus, _): .differentiationByLocus
        case (.amova, .theta): .weirCockerhamTheta
        case (.amova, _): .amovaPhiST
        }
    }
}
