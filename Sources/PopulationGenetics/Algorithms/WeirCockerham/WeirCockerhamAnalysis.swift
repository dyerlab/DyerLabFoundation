//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  WeirCockerhamAnalysis.swift
//  PopulationGenetics
//
//  The significance test permutes whole individuals among strata, keeping each
//  diploid genotype intact, which is the null of no differentiation among
//  strata that θ measures. It uses Matrix's shared permutation helper, so a
//  seed gives the same draws as an AMOVA run with that seed.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// Weir & Cockerham's (1984) θ at one locus (`AnalysisType.weirCockerham`), with F_IS and F_IT.
///
/// Only individuals with a diploid genotype at the locus are used; the rest are counted in ``notes``.
///
/// ## Usage
///
/// ```swift
/// if let theta = WeirCockerhamAnalysis(column: matrix.columns[0], locus: "LTRS",
///                                      ordinals: adults, strata: populations),
///    let run = theta.perform(options: AnalysisOptions(iterations: 999, seed: 1)) {
///     print(run.outcome.decomposition.theta, run.outcome.pValue ?? .nan)
/// }
/// ```
public struct WeirCockerhamAnalysis: Analysis {

    /// `AnalysisType.weirCockerham`.
    public static let analysisType: AnalysisType = .weirCockerham

    /// The label for the outcome.
    public let tag: AnalysisTag

    /// The locus's name.
    public let locus: String

    /// The rows of the individuals used, in analysis order.
    public let individuals: [Int]

    /// Each used individual's stratum, as an index into ``strata``.
    public let partition: [Int]

    /// The strata's names, in order of first appearance.
    public let strata: [String]

    /// What the strata are called, plural, for the report (default `"strata"`).
    public var groupLabel = "strata"

    /// The decisions made about the data.
    public let notes: [AnalysisNote]

    private let first: [UInt8]
    private let second: [UInt8]
    private let alleleSlots: Int

    // MARK: - Initialization

    /// Gathers the diploid genotypes at a locus and their strata.
    ///
    /// - Parameters:
    ///   - column: The locus.
    ///   - locus: The locus's name, for the report.
    ///   - ordinals: The rows of the individuals to include.
    ///   - strata: Each individual's stratum, in `ordinals` order.
    ///   - tag: The label for the outcome (default `.weirCockerhamTheta`).
    /// - Returns: `nil` if `strata` is the wrong length, or fewer than two strata or no more individuals than
    ///   strata have a diploid genotype at the locus.
    public init?(column: any GenotypeColumn,
                 locus: String,
                 ordinals: [Int],
                 strata: [String],
                 tag: AnalysisTag = .weirCockerhamTheta) {
        guard strata.count == ordinals.count else { return nil }
        var first: [UInt8] = [], second: [UInt8] = [], partition: [Int] = [], used: [Int] = []
        var names: [String] = [], index: [String: Int] = [:]
        var skipped = 0
        for (ordinal, stratum) in zip(ordinals, strata) {
            guard let (a, b) = column.alleles(at: ordinal), a != 0, b != 0 else {
                skipped += 1
                continue
            }
            let i = index[stratum] ?? {
                names.append(stratum)
                index[stratum] = names.count - 1
                return names.count - 1
            }()
            first.append(a)
            second.append(b)
            partition.append(i)
            used.append(ordinal)
        }
        guard names.count >= 2, used.count > names.count else { return nil }

        var notes: [AnalysisNote] = []
        if skipped > 0 {
            notes.append(AnalysisNote(.assumption, "\(skipped) individuals without a diploid genotype at \(locus) "
                                      + "were left out of θ."))
        }
        self.tag = tag
        self.locus = locus
        self.individuals = used
        self.partition = partition
        self.strata = names
        self.notes = notes
        self.first = first
        self.second = second
        self.alleleSlots = Int(max(first.max() ?? 0, second.max() ?? 0)) + 1
    }

    // MARK: - Running

    /// The decomposition for a labelling of the individuals.
    ///
    /// - Parameter partition: Each used individual's stratum index.
    /// - Returns: The variance components and their analysis of variance.
    public func decompose(partition: [Int]) -> WeirCockerhamDecomposition {
        WeirCockerhamDecomposition(first: first, second: second, partition: partition,
                                   strataCount: strata.count, alleleSlots: alleleSlots)
    }

    /// Estimates θ and, if `options.iterations > 0`, tests it by permuting individuals among strata.
    ///
    /// - Parameter options: Permutation count and seed.
    /// - Returns: The estimates and their null distribution; never `nil`.
    public func run(options: AnalysisOptions) -> WeirCockerhamOutcome? {
        run(options: options) { _ in true }
    }

    /// Estimates θ and, if `options.iterations > 0`, tests it, reporting each permutation as it finishes.
    ///
    /// - Parameters:
    ///   - options: Permutation count and seed.
    ///   - progress: Called after each permutation with the number done; return `false` to stop.
    /// - Returns: The estimates and their null distribution (of fewer values if `progress` stopped the test).
    public func run(options: AnalysisOptions, progress: (Int) -> Bool) -> WeirCockerhamOutcome? {
        run(options: options, observing: { done, _ in progress(done) })
    }

    /// Estimates θ and, if `options.iterations > 0`, tests it, handing over each permuted θ as it is drawn.
    ///
    /// - Parameters:
    ///   - options: Permutation count and seed.
    ///   - observing: Called after each permutation with the number done and its θ; return `false` to stop, which
    ///     finishes the test with the permutations drawn so far.
    /// - Returns: The estimates and their null distribution (of fewer values than asked if `observing` stopped the
    ///   test).
    public func run(options: AnalysisOptions,
                    observing: (_ done: Int, _ value: Double) -> Bool) -> WeirCockerhamOutcome? {
        var null: NullDistributionResult?
        if options.iterations > 0 {
            null = Resampling.permutationTest(labels: partition, iterations: options.iterations, seed: options.seed,
                                              tag: tag, observing: observing) { decompose(partition: $0).theta }
        }
        return WeirCockerhamOutcome(tag: tag, locus: locus, decomposition: decompose(partition: partition),
                                    distribution: null)
    }
}
