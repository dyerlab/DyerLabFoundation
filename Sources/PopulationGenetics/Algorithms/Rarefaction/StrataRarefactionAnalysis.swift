//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StrataRarefactionAnalysis.swift
//  PopulationGenetics
//
//  Rarefaction among strata, a port of gstudio's rarefaction.test() (1.15.4).
//  It is rarefaction, not a bootstrap: at each locus every stratum is brought
//  down to the same number of genotyped individuals, by default the smallest
//  genotyped stratum, by drawing that many of its individuals without
//  replacement, many times. The smallest stratum is used whole (its values
//  are its observed value), a stratum with fewer is left out (NA), and the
//  rest give a distribution of each statistic at the common size, summarised
//  by its mean and a percentile interval. With several loci each stratum gets
//  a multilocus row per statistic: the mean over loci, 1 − ΣHo/ΣHe for Fis
//  and 1 − Π(1 − Pex) for Pex, draw by draw, and NA if any locus is NA there
//  unless `dropsMissingLoci`.
//
//  Draws match R's: for each locus in order, then each stratum in order, R
//  calls sample.int(n, size) once per draw (`RMersenneTwister`). gstudio
//  orders strata by `levels(factor())`, R's locale sort, so pass `strata` in
//  that order to reproduce its values. Diversity is over the adults, as in
//  `StratumReport`. Fixture: `Fixtures/generate_strata_rarefaction_fixtures.R`.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Rarefaction of genetic diversity among strata to a common sample size (gstudio's `rarefaction.test()`).
///
/// ## Usage
///
/// ```swift
/// if let rarefaction = StrataRarefactionAnalysis(dataset: dataset, level: "Population", statistics: [.A, .Ae]),
///    let result = rarefaction.run(options: AnalysisOptions(iterations: 999, seed: 1)) {
///     for row in result.rows where row.locus == nil { print(row.stratum, row.statistic, row.estimate ?? .nan) }
/// }
/// ```
public struct StrataRarefactionAnalysis: Sendable {

    /// The statistics that can be rarefied: those computed from one locus's allele counts.
    public static let statistics = DiversityType.frequencyStatistics

    /// The strata level, or `nil` for the adults as one sample (which needs a ``size``).
    public let level: String?

    /// The strata, in the order draws are made.
    public let strata: [String]

    /// The locus ordinals.
    public let loci: [Int]

    /// The statistics rarefied, in row order.
    public let statistics: [DiversityType]

    /// The subsample size, or `nil` for the smallest genotyped stratum at each locus.
    public let size: Int?

    /// The coverage of each row's interval.
    public let confidenceLevel: Double

    /// Whether a multilocus row leaves out loci with no value in its stratum instead of being undefined.
    public let dropsMissingLoci: Bool

    /// The genotypes.
    let matrix: GenotypeMatrix

    /// Each stratum's adults, in matrix order.
    let members: [[Int]]

    /// Prepares the rarefaction.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes, with strata.
    ///   - level: The strata level, or `nil` for the adults as one sample, "All".
    ///   - strata: The strata to rarefy, in draw order, or `nil` (the default) for every stratum of the level in
    ///     the order first met in the data.
    ///   - loci: The locus ordinals, or `nil` (the default) for every locus.
    ///   - statistics: The statistics, from ``statistics`` (default Ae, as gstudio).
    ///   - size: The subsample size, or `nil` (the default) for the smallest genotyped stratum at each locus.
    ///   - confidenceLevel: The intervals' coverage (default 0.95).
    ///   - dropsMissingLoci: Whether multilocus rows leave out loci with no value (default `false`).
    /// - Returns: `nil` if a statistic can't be rarefied, there are no strata or loci, `size` is below 1, there is
    ///   no level and no `size`, or the coverage isn't in (0, 1).
    public init?(dataset: ImportedDataset, level: String?, strata: [String]? = nil, loci: [Int]? = nil,
                 statistics: [DiversityType] = [.Ae], size: Int? = nil, confidenceLevel: Double = 0.95,
                 dropsMissingLoci: Bool = false) {
        let used = loci ?? Array(dataset.matrix.loci.indices)
        guard !statistics.isEmpty, statistics.allSatisfy(Self.statistics.contains),
              !used.isEmpty, used.allSatisfy(dataset.matrix.loci.indices.contains),
              size.map({ $0 >= 1 }) ?? (level != nil),
              confidenceLevel > 0, confidenceLevel < 1 else { return nil }
        let names: [String]
        let members: [[Int]]
        if let level {
            names = strata ?? StratumReport.strata(of: level, in: dataset)
            members = names.map { StratumReport(dataset: dataset, level: level, name: $0).adults }
        } else {
            names = ["All"]
            members = [dataset.adultOrdinals]
        }
        guard !names.isEmpty else { return nil }
        var seen: Set<DiversityType> = []
        self.statistics = statistics.filter { seen.insert($0).inserted }
        self.level = level
        self.strata = names
        self.loci = used
        self.size = size
        self.confidenceLevel = confidenceLevel
        self.dropsMissingLoci = dropsMissingLoci
        self.matrix = dataset.matrix
        self.members = members
    }

    /// Rarefies every statistic at every locus in every stratum.
    ///
    /// - Parameters:
    ///   - options: Subsamples per stratum and locus (`iterations`, at least 1) and the seed (R's `set.seed()`).
    ///   - progress: Called after each locus with the number done; return `false` to stop, which returns `nil`.
    /// - Returns: The rows, by stratum, then locus (multilocus last), then statistic; or `nil` with no
    ///   iterations or when stopped.
    public func run(options: AnalysisOptions, progress: (Int) -> Bool = { _ in true }) -> StrataRarefactionResult? {
        let draws = options.iterations
        guard draws >= 1 else { return nil }
        var rng = RMersenneTwister(seed: Int(truncatingIfNeeded: options.seed))
        // [locus][stratum] → (genotyped, size, observed per statistic, draws per statistic)
        var cells: [[Cell]] = []
        var short: [String] = []
        let tracked = trackedStatistics
        for (done, j) in loci.enumerated() {
            let column = matrix.columns[j]
            let typed = members.map { rows in rows.filter { row in
                guard let (a, b) = column.alleles(at: row) else { return false }
                return a != 0 || b != 0
            } }
            let common = size ?? typed.map(\.count).filter { $0 > 0 }.min() ?? 0
            var row: [Cell] = []
            for (s, individuals) in typed.enumerated() {
                let n = individuals.count
                let observed = n > 0 ? Self.values(of: column.frequencies(over: individuals), tracked)
                    : tracked.map { _ in Double.nan }
                var values: [[Double]]
                if n < common || common < 1 {
                    values = Array(repeating: tracked.map { _ in .nan }, count: draws)
                    short.append("\(strata[s]) \(matrix.loci[j].name)")
                } else if n == common {
                    values = Array(repeating: observed, count: draws)
                } else {
                    values = (0..<draws).map { _ in
                        let pick = rng.sampleIndicesNoReplacement(n: n, size: common)    // R: sample.int(n, size)
                        return Self.values(of: column.frequencies(over: pick.map { individuals[$0] }), tracked)
                    }
                }
                row.append(Cell(individuals: n, size: common, observed: observed, values: values))
            }
            cells.append(row)
            guard progress(done + 1) else { return nil }
        }
        return result(cells: cells, short: short, tracked: tracked, options: options)
    }

    // MARK: - Assembly

    /// One locus in one stratum: per tracked statistic, the observed value and each draw's.
    struct Cell {
        let individuals: Int
        let size: Int
        let observed: [Double]
        let values: [[Double]]     // [draw][statistic]
    }

    /// The statistics computed per draw: those asked for, plus Ho and He for a multilocus Fis.
    var trackedStatistics: [DiversityType] {
        var tracked = statistics
        for extra in [DiversityType.Ho, .He] where !tracked.contains(extra) { tracked.append(extra) }
        return tracked
    }

    /// The rows, in gstudio's order, with the report.
    private func result(cells: [[Cell]], short: [String], tracked: [DiversityType],
                        options: AnalysisOptions) -> StrataRarefactionResult {
        let index = Dictionary(uniqueKeysWithValues: tracked.enumerated().map { ($1, $0) })
        var rows: [StrataRarefactionRow] = []
        for s in strata.indices {
            for (l, j) in loci.enumerated() {
                let cell = cells[l][s]
                for statistic in statistics {
                    let k = index[statistic] ?? 0
                    rows.append(StrataRarefactionRow(
                        stratum: strata[s], locus: matrix.loci[j].name, statistic: statistic,
                        individuals: cell.individuals, size: cell.size, observed: Self.finite(cell.observed[k]),
                        values: cell.values.map { $0[k] }, confidenceLevel: confidenceLevel))
                }
            }
            guard loci.count > 1 else { continue }
            for statistic in statistics {
                rows.append(multilocus(statistic, stratum: s, cells: cells, index: index))
            }
        }
        return StrataRarefactionResult(analysis: self, rows: rows, shortCells: short, options: options)
    }

    /// A stratum's multilocus row for one statistic.
    private func multilocus(_ statistic: DiversityType, stratum s: Int, cells: [[Cell]],
                            index: [DiversityType: Int]) -> StrataRarefactionRow {
        let k = index[statistic] ?? 0, ho = index[.Ho] ?? 0, he = index[.He] ?? 0
        var used = cells.map { $0[s] }
        if dropsMissingLoci {
            used = used.filter { $0.observed[k].isFinite && $0.values.allSatisfy { $0[k].isFinite } }
        }
        /// Combines one set of per-locus values (observed, or one draw) across the loci.
        func combine(_ value: (Cell, Int) -> Double) -> Double {
            guard !used.isEmpty else { return .nan }
            switch statistic {
            case .Fis:
                return 1 - used.reduce(0) { $0 + value($1, ho) } / used.reduce(0) { $0 + value($1, he) }
            case .Pex:
                return 1 - used.reduce(1) { $0 * (1 - value($1, k)) }
            default:
                return used.reduce(0) { $0 + value($1, k) } / Double(used.count)
            }
        }
        let draws = cells.first?[s].values.count ?? 0
        return StrataRarefactionRow(
            stratum: strata[s], locus: nil, statistic: statistic, individuals: nil, size: nil,
            observed: Self.finite(combine { cell, i in cell.observed[i] }),
            values: (0..<draws).map { b in combine { cell, i in cell.values[b][i] } },
            confidenceLevel: confidenceLevel)
    }

    /// The statistics from one set of allele counts, `NaN` where undefined.
    private static func values(of frequencies: AlleleFrequencies, _ statistics: [DiversityType]) -> [Double] {
        statistics.map { statistic in
            switch statistic {
            case .A: frequencies.A
            case .A95: frequencies.A95
            case .Ae: frequencies.Ae
            case .Ho: frequencies.Ho
            case .He: frequencies.He
            case .Fis: frequencies.Fis
            case .Pe: frequencies.Pe
            case .Sh: frequencies.Sh
            case .Pex: frequencies.Pex
            default: .nan
            }
        }
    }

    /// `value`, or `nil` if it isn't finite.
    private static func finite(_ value: Double) -> Double? { value.isFinite ? value : nil }
}
